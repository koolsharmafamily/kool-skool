import Foundation
import Observation
import SwiftUI

/// Owns the running session.
///
/// The correctness rule this whole type is built around: **nothing counts down.**
/// The only durable facts are `startedAt` and `plannedDuration`, both persisted
/// the moment a session starts. Everything the user sees is recomputed from
/// those against the current wall clock. A tick that never fires, an app that is
/// killed, a device that reboots — none of it can make the timer wrong, because
/// there is no accumulated state to lose.
///
/// The tick loop exists only to refresh the display and notice the planned end.
/// It is never the source of truth, and `tick()` is callable directly so tests
/// can drive time by hand instead of sleeping.
@MainActor
@Observable
final class FocusEngine {

    enum Status: Equatable, Sendable {
        case idle
        case running
        /// A session just ended and the completion screen is showing.
        case finished
    }

    // MARK: Dependencies

    private let repositories: any RepositoryProvider
    private let clock: any DateProvider
    private let haptics: any HapticPerforming
    private let alerts: any SessionAlertScheduling
    private let idleGuard: any ScreenIdleGuarding
    private let rewards: RewardService
    /// Optional so the engine stays testable without an audio stack.
    private let bodyDoubling: BodyDoublingController?
    /// The Lock Screen and Dynamic Island timer.
    private let liveActivity: any SessionLiveActivityManaging

    // MARK: Observable state

    private(set) var status: Status = .idle
    private(set) var session: FocusSession?
    /// The instant the display is rendered against. Advanced by `tick()`.
    private(set) var now: Date
    /// The session that just ended, held for the completion screen.
    private(set) var finishedSession: FocusSession?
    /// The task the current or just-finished session is attached to, if any.
    /// Loaded once rather than looked up on every render.
    private(set) var linkedTask: FocusTask?
    /// What the session that just finished earned. Drives the celebration.
    private(set) var lastAward: AwardOutcome?
    /// Whether the one-tap "how did that go?" has been answered for the
    /// session on the completion screen, so the question disappears once asked.
    private(set) var postCheckInRecorded = false
    private(set) var lastError: String?

    /// Written through `apply(settings:)` rather than directly. Property
    /// observers on an `@Observable` stored property are not dependable, so the
    /// side effect is an explicit call instead of a `didSet`.
    private(set) var settings = AppSettings()

    func apply(settings: AppSettings) {
        self.settings = settings
        bodyDoubling?.settings = settings
        syncIdleGuard()
    }

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var lastHeartbeatAt: Date?
    /// How many time-check pulses this session has already fired. Counted
    /// rather than timed, so they cannot drift.
    @ObservationIgnored private var timeChecksFired = 0
    @ObservationIgnored private var postCheckInID: UUID?
    /// Tests drive `tick()` by hand against a fake clock. Leaving the real
    /// one-second loop running alongside would make them non-deterministic.
    @ObservationIgnored private let ticksAutomatically: Bool

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider = SystemDateProvider(),
        haptics: any HapticPerforming = KSHaptics.shared,
        alerts: any SessionAlertScheduling = NoOpSessionAlertScheduler(),
        idleGuard: any ScreenIdleGuarding = ScreenIdleGuard(),
        rewards: RewardService? = nil,
        bodyDoubling: BodyDoublingController? = nil,
        liveActivity: any SessionLiveActivityManaging = NoOpLiveActivityManager(),
        ticksAutomatically: Bool = true
    ) {
        self.bodyDoubling = bodyDoubling
        self.liveActivity = liveActivity
        self.repositories = repositories
        self.clock = clock
        self.haptics = haptics
        self.alerts = alerts
        self.idleGuard = idleGuard
        self.rewards = rewards ?? RewardService(repositories: repositories, clock: clock)
        self.ticksAutomatically = ticksAutomatically
        self.now = clock.now
    }

    // MARK: Derived

    var snapshot: SessionSnapshot? {
        guard let session else { return nil }
        return SessionSnapshot(session: session, now: now)
    }

    /// Whether the completion screen should offer to roll straight into a longer
    /// session. This is the whole pitch of Just Start — five minutes, and then
    /// one tap to keep going.
    var offersExtension: Bool {
        guard let finished = finishedSession, finished.wasCompleted else { return false }
        guard finished.mode.defaultProfile.offersExtension else { return false }
        guard let endedAt = finished.endedAt else { return false }
        return now.timeIntervalSince(endedAt) < FocusRules.extensionOfferWindow
    }

    // MARK: Lifecycle

    /// Called once at launch. Picks up a session that outlived the app.
    func restore() async {
        now = clock.now

        do {
            guard let active = try await repositories.sessions.activeSession() else {
                status = .idle
                return
            }

            session = active
            status = .running
            await loadLinkedTask(id: active.taskID)

            if let resolution = Self.resolveUnattended(active, now: now) {
                await finish(reason: resolution.reason, at: resolution.endedAt)
            } else {
                await beginRunning(active)
            }
        } catch {
            lastError = error.localizedDescription
            status = .idle
        }
    }

    func start(_ plan: SessionPlan) async {
        guard status != .running else { return }

        now = clock.now
        let session = plan.session(startedAt: now)

        do {
            // Persisted before anything else happens. If the app dies one
            // instant later, the session is already recoverable.
            let saved = try await repositories.sessions.upsert(session)
            self.session = saved
            status = .running
            finishedSession = nil
            postCheckInRecorded = false
            postCheckInID = nil
            lastError = nil
            await loadLinkedTask(id: saved.taskID)
            await savePreCheckIn(from: plan, sessionID: saved.id, at: now)

            haptics.fire(.start)
            await beginRunning(saved)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// The escape hatch. Honest, one tap, no penalty beyond the truth.
    func endEarly() async {
        guard status == .running else { return }
        now = clock.now
        await finish(reason: .endedByUser, at: now)
    }

    /// "Keep going?" — credits the session that just finished and immediately
    /// starts a fresh one, carrying the intent and task across.
    ///
    /// Two records rather than one stretched record, because both intervals
    /// genuinely happened and the history should say so.
    func continueSession(as mode: SessionMode) async {
        guard let finished = finishedSession else { return }

        // Carries the intent and task across but not the check-in: energy five
        // minutes ago is not energy now, and asking again would be a step too
        // many for a one-tap "keep going".
        let plan = SessionPlan(
            mode: mode,
            plannedDuration: settings.resolvedProfile(for: mode).workDuration,
            intent: finished.intent,
            resistance: finished.resistanceAtStart,
            taskID: finished.taskID,
            commitment: finished.commitment
        )

        finishedSession = nil
        lastAward = nil
        status = .idle
        await start(plan)
    }

    /// Leaves the completion screen without starting anything.
    func dismissCompletion() {
        finishedSession = nil
        linkedTask = nil
        lastAward = nil
        status = .idle
        Task { await bodyDoubling?.reset() }
    }

    /// "Did you finish it?" from the completion screen.
    ///
    /// The session's real duration is credited to the task, which is what the
    /// estimate calibration reads.
    func markLinkedTaskComplete() async {
        guard let task = linkedTask, let finished = finishedSession else { return }

        do {
            try await repositories.tasks.complete(
                taskID: task.id,
                at: finished.endedAt ?? clock.now,
                actualMinutes: finished.actualMinutes
            )
            linkedTask = try await repositories.tasks.task(id: task.id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// "How did that go?" — one tap on the completion screen.
    ///
    /// Changing the answer updates the same row rather than adding a second
    /// one, and clearing it removes it. Nobody should have to live with a
    /// mis-tap in their own history.
    func recordPostCheckIn(quality: Rating?) async {
        guard let finished = finishedSession else { return }

        do {
            guard let quality else {
                if let existing = postCheckInID {
                    try await repositories.checkIns.softDelete(checkInID: existing)
                }
                postCheckInID = nil
                postCheckInRecorded = false
                return
            }

            var checkIn = CheckIn()
            if let existing = postCheckInID { checkIn.id = existing }
            checkIn.timestamp = clock.now
            checkIn.phase = .post
            checkIn.focusQuality = quality
            checkIn.sessionID = finished.id

            let saved = try await repositories.checkIns.upsert(checkIn)
            postCheckInID = saved.id
            postCheckInRecorded = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Writes nothing at all when the check-in was skipped. An empty row would
    /// be indistinguishable from a real "I don't know" and would skew Insights.
    private func savePreCheckIn(from plan: SessionPlan, sessionID: UUID, at date: Date) async {
        guard plan.hasCheckIn else { return }

        var checkIn = CheckIn()
        checkIn.timestamp = date
        checkIn.phase = .pre
        checkIn.energy = plan.energy
        checkIn.mood = plan.mood
        checkIn.sessionID = sessionID

        // A failed check-in must never cost the session it belongs to.
        _ = try? await repositories.checkIns.upsert(checkIn)
    }

    private func loadLinkedTask(id: UUID?) async {
        guard let id else {
            linkedTask = nil
            return
        }
        linkedTask = try? await repositories.tasks.task(id: id)
    }

    // MARK: Ticking

    /// Recomputes against the wall clock and acts on any boundary crossed.
    ///
    /// Deliberately not private: tests drive it directly with a hand-moved
    /// clock, which is the only way the backgrounding cases are testable.
    func tick() async {
        guard status == .running, let current = session else { return }

        now = clock.now

        if current.hasReachedPlannedEnd(asOf: now) {
            await finish(reason: .reachedPlannedEnd, at: current.startedAt.addingTimeInterval(current.plannedDuration))
            return
        }

        fireTimeCheckIfDue(elapsed: current.elapsed(asOf: now))
        await bodyDoubling?.sessionDidProgress(to: current.progress(asOf: now))
        await writeHeartbeatIfDue()
    }

    /// The optional pulse every N minutes. Off by default, because a nudge some
    /// people find grounding others find is just an interruption.
    ///
    /// Derived from elapsed time rather than counted from the last pulse, so it
    /// cannot drift — and coming back from twenty minutes in the background
    /// fires once, not three times in a row.
    private func fireTimeCheckIfDue(elapsed: TimeInterval) {
        guard settings.timeChecksEnabled else { return }

        let interval = TimeInterval(max(1, settings.timeCheckIntervalMinutes) * 60)
        let due = Int(elapsed / interval)

        guard due > timeChecksFired else { return }
        timeChecksFired = due
        haptics.fire(.timeCheck)
    }

    /// Forwarded from the scene phase. Returning to the foreground has to
    /// recompute immediately rather than waiting up to a second for a tick,
    /// and leaving has to leave a heartbeat behind.
    func scenePhaseChanged(to phase: ScenePhase) async {
        switch phase {
        case .active:
            now = clock.now
            if status == .running, let current = session {
                if let resolution = Self.resolveUnattended(current, now: now) {
                    await finish(reason: resolution.reason, at: resolution.endedAt)
                    return
                }
                startTicking()
                syncIdleGuard()
            }
        case .inactive, .background:
            stopTicking()
            idleGuard.setKeepAwake(false)
            await writeHeartbeat()
        @unknown default:
            break
        }
    }

    // MARK: Internals

    private func beginRunning(_ session: FocusSession) async {
        await bodyDoubling?.sessionDidStart(session)
        lastHeartbeatAt = session.lastHeartbeatAt
        // Restoring mid-session must not replay every pulse that was missed.
        let interval = TimeInterval(max(1, settings.timeCheckIntervalMinutes) * 60)
        timeChecksFired = Int(session.elapsed(asOf: clock.now) / interval)
        startTicking()
        syncIdleGuard()

        if settings.sessionEndAlertsEnabled {
            await alerts.scheduleEnd(for: session)
        }
        // Also runs on relaunch mid-session; the manager updates the existing
        // activity rather than adding a second one.
        await liveActivity.start(FocusActivityContent.make(for: session, taskTitle: linkedTask?.startableLabel))
    }

    private func finish(reason: SessionEndReason, at endDate: Date) async {
        guard var current = session else { return }

        stopTicking()
        idleGuard.setKeepAwake(false)
        await alerts.cancelAll()
        await liveActivity.end(sessionID: current.id)

        let elapsed = max(0, endDate.timeIntervalSince(current.startedAt))

        current.endedAt = endDate
        current.endReason = reason
        current.wasCompleted = Self.countsAsCompleted(reason: reason, session: current, elapsed: elapsed)

        do {
            // A mis-tap should not leave litter in the history.
            if reason == .endedByUser, elapsed < FocusRules.minimumRecordableDuration {
                try await repositories.sessions.softDelete(sessionID: current.id)
                session = nil
                finishedSession = nil
                status = .idle
                return
            }

            let saved = try await repositories.sessions.upsert(current)
            session = nil
            finishedSession = saved
            status = .finished
            haptics.fire(saved.wasCompleted ? .complete : .tap)
            // Stops the bed and plays the completion chime.
            await bodyDoubling?.sessionDidEnd(saved, completed: saved.wasCompleted)

            // Rewards are deliberately after the session is safely stored. A
            // failure to pay out must never cost someone the record of the work.
            lastAward = nil
            if saved.wasCompleted {
                do {
                    let outcome = try await rewards.award(for: saved)
                    lastAward = outcome

                    var stamped = saved
                    stamped.xpAwarded = outcome.xp
                    stamped.coinsAwarded = outcome.coins
                    stamped.earnedBonus = outcome.bonus != nil
                    finishedSession = stamped
                } catch {
                    lastError = error.localizedDescription
                }
            }
        } catch {
            lastError = error.localizedDescription
            // The session stays running rather than vanishing. Better to show a
            // stale timer than to silently lose the record.
        }
    }

    private func startTicking() {
        guard ticksAutomatically, tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(FocusRules.tickInterval))
                } catch {
                    return
                }
                guard let self else { return }
                await self.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func syncIdleGuard() {
        idleGuard.setKeepAwake(status == .running && settings.keepScreenAwakeDuringSession)
    }

    private func writeHeartbeatIfDue() async {
        let last = lastHeartbeatAt ?? session?.startedAt ?? now
        guard now.timeIntervalSince(last) >= FocusRules.heartbeatInterval else { return }
        await writeHeartbeat()
    }

    private func writeHeartbeat() async {
        guard status == .running, var current = session else { return }
        let stamp = clock.now
        current.lastHeartbeatAt = stamp

        do {
            let saved = try await repositories.sessions.upsert(current)
            session = saved
            lastHeartbeatAt = stamp
        } catch {
            // A missed heartbeat is not worth surfacing. It only degrades the
            // accuracy of one recovery edge case.
            lastError = nil
        }
    }
}

// MARK: - Pure decision logic

extension FocusEngine {

    struct UnattendedResolution: Equatable, Sendable {
        var reason: SessionEndReason
        var endedAt: Date
    }

    /// Decides what to do with a session found still running after the app was
    /// not watching. Pure, so every branch is testable without an engine.
    ///
    /// Count-down: the interval ended when it was planned to end, whether or not
    /// anything was on screen. Credit it, dated honestly.
    ///
    /// Count-up: there is no planned end, so the wall clock is trusted up to a
    /// ceiling. Past the ceiling the session is closed at its last heartbeat,
    /// because "phone died overnight" must not read as four hours of deep work.
    nonisolated static func resolveUnattended(_ session: FocusSession, now: Date) -> UnattendedResolution? {
        guard session.isRunning else { return nil }

        let countsUp = session.mode.defaultProfile.countsUp || session.plannedDuration <= 0

        if !countsUp {
            guard session.hasReachedPlannedEnd(asOf: now) else { return nil }
            return UnattendedResolution(
                reason: .finishedWhileAway,
                endedAt: session.startedAt.addingTimeInterval(session.plannedDuration)
            )
        }

        guard session.elapsed(asOf: now) > FocusRules.maximumUnattendedCountUp else { return nil }

        let ceiling = session.startedAt.addingTimeInterval(FocusRules.maximumUnattendedCountUp)
        let heartbeat = session.lastHeartbeatAt ?? session.startedAt
        return UnattendedResolution(reason: .cappedAfterHeartbeat, endedAt: min(ceiling, max(heartbeat, session.startedAt)))
    }

    /// Whether a session that ended this way earns completion credit — the thing
    /// streaks and rewards read.
    nonisolated static func countsAsCompleted(reason: SessionEndReason, session: FocusSession, elapsed: TimeInterval) -> Bool {
        let countsUp = session.mode.defaultProfile.countsUp || session.plannedDuration <= 0

        switch reason {
        case .reachedPlannedEnd, .finishedWhileAway:
            return true

        case .cappedAfterHeartbeat:
            // Nobody confirmed this one. It is recorded but not credited.
            return false

        case .endedByUser:
            // Stopping a count-up session *is* how you finish one.
            if countsUp {
                return elapsed >= FocusRules.minimumRecordableDuration
            }
            // Otherwise the escape hatch still earns credit once most of the
            // interval is done. Twenty-four of twenty-five minutes is a finished
            // Pomodoro, and calling it a failure would be the shame mechanic
            // this app refuses to use.
            guard session.plannedDuration > 0 else { return false }
            return elapsed / session.plannedDuration >= FocusRules.completionThreshold
        }
    }
}
