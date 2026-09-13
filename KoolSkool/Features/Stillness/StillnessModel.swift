import Foundation
import Observation
import SwiftUI

/// A practice currently running.
///
/// `practice` is nil for a plain break timer — the "skip the practice, just give
/// me the time" option. That case deliberately records nothing: a break is not
/// a sit, and counting it as one would inflate the calm streak with minutes
/// nobody practised.
struct StillnessRun: Sendable, Equatable {
    var practice: Practice?
    var plannedDuration: TimeInterval
    var startedAt: Date
    var tradition: Tradition = .secular
    /// Set when this was offered as the break after a focus session.
    var focusSessionID: UUID?
    var isBreak: Bool = false
    /// Captured from settings when the sit starts, so changing the setting
    /// mid-sit cannot start or stop bells underneath someone.
    var intervalBellsEnabled: Bool = false

    func elapsed(asOf now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt))
    }

    func remaining(asOf now: Date) -> TimeInterval {
        max(0, plannedDuration - elapsed(asOf: now))
    }

    func progress(asOf now: Date) -> Double {
        guard plannedDuration > 0 else { return 0 }
        return min(max(elapsed(asOf: now) / plannedDuration, 0), 1)
    }

    func hasReachedEnd(asOf now: Date) -> Bool {
        plannedDuration > 0 && elapsed(asOf: now) >= plannedDuration
    }

    var breathPattern: BreathPattern? {
        guard let practice else { return nil }
        return BreathPattern.forPractice(practice.type)
    }

    var title: String {
        practice?.title ?? "Break"
    }
}

/// The break offered after a focus session: one practice, or just the time.
struct BreakOffer: Sendable, Equatable, Identifiable {
    var id = UUID()
    var duration: TimeInterval
    var suggested: Practice?
    var focusSessionID: UUID?

    var minutes: Int { max(1, Int((duration / 60).rounded())) }
}

/// Owns the stillness layer: the library, the running sit, and the calm streak.
///
/// Built on the same rule as `FocusEngine` — nothing counts down. `startedAt`
/// and the planned duration are the only facts; everything on screen is derived
/// from them against the wall clock, so a missed tick or a spell in the
/// background cannot make the pacer or the timer wrong.
///
/// Unlike a focus session, a sit is **not** persisted when it starts. It is
/// written when it ends. The schema has no notion of an open sit, and losing a
/// two-minute practice to a force quit costs far less than the machinery to
/// recover one would.
@MainActor
@Observable
final class StillnessModel {

    // MARK: Dependencies

    private let repositories: any RepositoryProvider
    private let clock: any DateProvider
    private let haptics: any HapticPerforming
    private let provider: any PracticeProvider
    /// Optional so the model is testable without an audio stack.
    private let bodyDoubling: BodyDoublingController?

    // MARK: Observable state

    private(set) var practices: [Practice] = []
    private(set) var completedSits = 0
    private(set) var calmStreak = 0
    private(set) var longestCalmStreak = 0
    /// Cached so the break suggestion can respect level gates without the
    /// caller having to hand progress in at the moment a session ends.
    private(set) var level = 1
    private(set) var recentSits: [StillnessSession] = []

    private(set) var run: StillnessRun?
    /// The instant the screen is rendered against. Advanced by `tick()`.
    private(set) var now: Date
    /// Where the breath pacer is. Nil whenever the running practice is not paced.
    private(set) var breathTick: BreathTick?
    /// The sit that just ended, held for the closing screen.
    private(set) var lastFinished: StillnessSession?
    /// The break offer waiting to be answered, if any.
    private(set) var breakOffer: BreakOffer?
    private(set) var lastError: String?

    private(set) var settings = AppSettings()

    func apply(settings: AppSettings) {
        self.settings = settings
    }

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var lastStepKey: Int?
    /// Counted rather than timed, so interval bells cannot drift and coming
    /// back from the background rings once rather than four times.
    @ObservationIgnored private var bellsRung = 0
    @ObservationIgnored private let ticksAutomatically: Bool

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider = SystemDateProvider(),
        haptics: any HapticPerforming = KSHaptics.shared,
        provider: any PracticeProvider = BundledPracticeProvider(),
        bodyDoubling: BodyDoublingController? = nil,
        ticksAutomatically: Bool = true
    ) {
        self.repositories = repositories
        self.clock = clock
        self.haptics = haptics
        self.provider = provider
        self.bodyDoubling = bodyDoubling
        self.ticksAutomatically = ticksAutomatically
        self.now = clock.now
    }

    // MARK: Derived

    var isRunning: Bool { run != nil }

    var tradition: Tradition { settings.tradition }

    /// What the library shows, in order, for a user at this level.
    ///
    /// Locked practices are still returned — the library shows them greyed with
    /// what they need, because a library that hides most of itself reads as a
    /// short library rather than a growing one.
    func libraryEntries(level: Int) -> [PracticeEntry] {
        practices
            .filter { $0.matches(tradition: tradition) }
            .map { practice in
                PracticeEntry(
                    practice: practice,
                    isAvailable: practice.isAvailable(level: level, completedSits: completedSits),
                    sitsRemaining: max(0, practice.requiredCompletedSits - completedSits)
                )
            }
    }

    /// The cue showing right now, for a practice that is guided by text.
    var currentCue: String? {
        guard let run, let practice = run.practice, practice.usesCues else { return nil }
        return practice.script.cue(elapsed: run.elapsed(asOf: now), duration: run.plannedDuration)
    }

    // MARK: Loading

    /// Seeds the bundled catalogue and reads back what the store holds.
    ///
    /// Reading back rather than using the provider's list directly is what
    /// keeps a future remote library and the local one on the same code path.
    func load() async {
        do {
            let bundled = try await provider.practices()
            try await repositories.stillness.seedPracticesIfNeeded(bundled)

            practices = try await repositories.stillness.practices()
            completedSits = try await repositories.stillness.completedSitCount()
            recentSits = try await repositories.stillness.recentSits(limit: 30)
            await refreshCalmStreak()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Recomputed from history, like the focus streak, so it is idempotent and
    /// cannot drift out of step with the sits it describes.
    @discardableResult
    func refreshCalmStreak() async -> StreakOutcome {
        do {
            let since = clock.now.addingTimeInterval(-Double(StillnessRules.maximumLookbackDays) * 86_400)
            let days = try await repositories.stillness.completedSitDays(since: since)
            let progress = try await repositories.progress.progress()

            let outcome = StreakCalculator.evaluate(
                completedDays: days,
                today: clock.now,
                previousLongest: progress.longestCalmStreak,
                clock: clock,
                freezeBudget: 0
            )

            let saved = try await repositories.progress.update(progress.applyingCalm(outcome))
            calmStreak = saved.calmStreak
            longestCalmStreak = saved.longestCalmStreak
            level = saved.level
            return outcome
        } catch {
            lastError = error.localizedDescription
            return .empty
        }
    }

    // MARK: Running a sit

    func start(
        practice: Practice,
        duration: TimeInterval? = nil,
        focusSessionID: UUID? = nil,
        isBreak: Bool = false
    ) {
        begin(
            StillnessRun(
                practice: practice,
                plannedDuration: duration ?? TimeInterval(practice.defaultDurationSeconds),
                startedAt: clock.now,
                tradition: tradition,
                focusSessionID: focusSessionID,
                isBreak: isBreak,
                intervalBellsEnabled: settings.intervalBellsEnabled
            )
        )
    }

    /// The break with no practice attached. Records nothing.
    func startPlainBreak(duration: TimeInterval, focusSessionID: UUID? = nil) {
        begin(
            StillnessRun(
                practice: nil,
                plannedDuration: duration,
                startedAt: clock.now,
                tradition: tradition,
                focusSessionID: focusSessionID,
                isBreak: true
            )
        )
    }

    private func begin(_ newRun: StillnessRun) {
        stopTicking()
        breakOffer = nil
        lastFinished = nil
        lastStepKey = nil
        bellsRung = 0
        now = clock.now
        run = newRun

        // Fires the first phase pulse for a paced practice.
        refreshBreathTick()

        // The opening bell. Nothing else marks the moment the sit starts.
        ringBell()
        // A paced practice has already had its first breath pulse; adding the
        // start thump on top of it would land as one muddled buzz.
        if newRun.breathPattern == nil {
            haptics.fire(.start)
        }
        startTicking()
    }

    /// Ends the run. `reachedEnd` separates "the time ran out" from "the user
    /// stopped", which is the difference between a completed sit and one that
    /// was cut short.
    func end(reachedEnd: Bool) async {
        guard let current = run else { return }

        stopTicking()
        now = clock.now
        let elapsed = current.elapsed(asOf: now)

        run = nil
        breathTick = nil

        // A plain break timer is not a sit and leaves no record.
        guard let practice = current.practice else { return }

        // Same rule as focus sessions: a mis-tap should not leave litter.
        guard elapsed >= StillnessRules.minimumRecordableDuration else { return }

        let completed = reachedEnd || Self.countsAsCompleted(elapsed: elapsed, planned: current.plannedDuration)

        var sit = StillnessSession()
        sit.practiceType = practice.type
        sit.practiceID = practice.id
        sit.startedAt = current.startedAt
        sit.durationSeconds = Int(elapsed.rounded())
        sit.completed = completed
        sit.tradition = current.tradition
        sit.focusSessionID = current.focusSessionID

        do {
            let saved = try await repositories.stillness.upsert(sit)
            lastFinished = saved

            if completed {
                ringBell()
                haptics.fire(.complete)
            }

            completedSits = try await repositories.stillness.completedSitCount()
            recentSits = try await repositories.stillness.recentSits(limit: 30)
            await refreshCalmStreak()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func dismissClosing() {
        lastFinished = nil
    }

    /// Recomputes against the wall clock and acts on any boundary crossed.
    /// Not private: tests drive it directly against a hand-moved clock.
    func tick() async {
        guard let current = run else { return }
        now = clock.now

        if current.hasReachedEnd(asOf: now) {
            await end(reachedEnd: true)
            return
        }

        refreshBreathTick()
        ringIntervalBellIfDue(elapsed: current.elapsed(asOf: now), run: current)
    }

    func scenePhaseChanged(to phase: ScenePhase) async {
        switch phase {
        case .active:
            now = clock.now
            guard let current = run else { return }
            if current.hasReachedEnd(asOf: now) {
                await end(reachedEnd: true)
                return
            }
            // Coming back mid-sit must not replay every phase that was missed.
            lastStepKey = nil
            bellsRung = Self.bellsDue(elapsed: current.elapsed(asOf: now), run: current)
            refreshBreathTick()
            startTicking()
        case .inactive, .background:
            stopTicking()
        @unknown default:
            break
        }
    }

    // MARK: Breaks

    /// Offers the break after a focus session, if the mode has one and the user
    /// asked for practices to be offered.
    func offerBreak(after session: FocusSession, settings: AppSettings) {
        guard settings.offerBreakPractice else { return }

        let profile = settings.resolvedProfile(for: session.mode)
        // `elapsed(asOf:)` reads the session's own `endedAt` when it has one, so
        // this is the real length of the work interval, not a guess.
        let duration = profile.breakDuration(forElapsedWork: session.elapsed(asOf: clock.now))
        guard duration >= 60 else { return }

        breakOffer = BreakOffer(
            duration: duration,
            suggested: suggestedPractice(forBreakOf: duration),
            focusSessionID: session.id
        )
    }

    func dismissBreakOffer() {
        breakOffer = nil
    }

    /// The practice that fits the break.
    ///
    /// Longest practice whose shortest option fits inside the break, preferring
    /// the paced breath practices — the ones that need no reading and no floor
    /// space, which is what a break at a desk actually allows.
    func suggestedPractice(forBreakOf duration: TimeInterval) -> Practice? {
        let fits = practices.filter { practice in
            guard practice.matches(tradition: tradition) else { return false }
            guard practice.isAvailable(level: level, completedSits: completedSits) else { return false }
            guard let shortest = practice.durationOptionsSeconds.min() else { return false }
            return TimeInterval(shortest) <= duration
        }

        let paced = fits
            .filter { $0.type.usesBreathPacer }
            .max { Self.bestDuration(of: $0, within: duration) < Self.bestDuration(of: $1, within: duration) }

        return paced ?? fits.first
    }

    /// The longest offered length of `practice` that fits in `duration`.
    static func bestDuration(of practice: Practice, within duration: TimeInterval) -> TimeInterval {
        let fitting = practice.durationOptionsSeconds.filter { TimeInterval($0) <= duration }
        guard let best = fitting.max() else {
            return TimeInterval(practice.defaultDurationSeconds)
        }
        return TimeInterval(best)
    }

    // MARK: Internals

    private func refreshBreathTick() {
        guard let current = run, let pattern = current.breathPattern else {
            breathTick = nil
            return
        }

        let tick = pattern.tick(atElapsed: current.elapsed(asOf: now))
        breathTick = tick

        // One pulse per phase boundary. Compared against the last key rather
        // than timed, so a slow tick fires it late but never twice.
        if lastStepKey != tick.stepKey {
            if lastStepKey != nil || tick.stepKey == 0 {
                haptics.fire(tick.phase.haptic)
            }
            lastStepKey = tick.stepKey
        }
    }

    private func ringIntervalBellIfDue(elapsed: TimeInterval, run current: StillnessRun) {
        let due = Self.bellsDue(elapsed: elapsed, run: current)
        guard due > bellsRung else { return }
        bellsRung = due
        ringBell()
    }

    /// How many interval bells should have rung by now.
    ///
    /// Derived from elapsed time rather than counted from the last one, so the
    /// spacing cannot drift over a ten-minute sit.
    nonisolated static func bellsDue(elapsed: TimeInterval, run: StillnessRun) -> Int {
        guard run.ringsIntervalBells else { return 0 }
        guard StillnessRules.intervalBellSpacing > 0 else { return 0 }
        return Int(elapsed / StillnessRules.intervalBellSpacing)
    }

    /// A sit stopped this far in still counts. Same eighty-percent rule the
    /// focus timer uses, for the same reason.
    nonisolated static func countsAsCompleted(elapsed: TimeInterval, planned: TimeInterval) -> Bool {
        guard planned > 0 else { return elapsed >= StillnessRules.minimumRecordableDuration }
        return elapsed / planned >= StillnessRules.completionThreshold
    }

    private func ringBell() {
        bodyDoubling?.ringBell(frequency: tradition.bellFrequency)
    }

    private func startTicking() {
        guard ticksAutomatically, tickTask == nil else { return }
        let interval = run?.breathPattern == nil
            ? StillnessRules.plainTickInterval
            : StillnessRules.pacedTickInterval

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
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
}

extension StillnessRun {
    /// Whether this run rings bells as it goes.
    ///
    /// The sound anchor always does, because the bell *is* the practice. Every
    /// other long sit does only if the user asked for it.
    var ringsIntervalBells: Bool {
        guard let practice else { return false }
        if practice.alwaysRingsIntervalBells { return true }
        return intervalBellsEnabled && plannedDuration >= StillnessRules.intervalBellMinimumDuration
    }
}

/// One row of the practice library, with its gate resolved.
struct PracticeEntry: Sendable, Identifiable, Equatable {
    var practice: Practice
    var isAvailable: Bool
    var sitsRemaining: Int

    var id: UUID { practice.id }

    /// Plain about what is missing. Never "locked" with no explanation.
    var lockLabel: String? {
        guard !isAvailable else { return nil }
        if sitsRemaining > 0 {
            return "After \(sitsRemaining) more sit\(sitsRemaining == 1 ? "" : "s")"
        }
        return "Not yet"
    }
}
