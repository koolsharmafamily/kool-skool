import Foundation
import SwiftUI
import Testing
@testable import KoolSkool

/// The highest-risk area in the app. Every test here moves a fake clock by hand
/// rather than sleeping, so the backgrounding, force-quit, restart, timezone and
/// DST cases are all reachable.
@MainActor
@Suite("Focus engine")
struct FocusEngineTests {

    struct Stack {
        let engine: FocusEngine
        let provider: SwiftDataRepositoryProvider
        let clock: MutableDateProvider
        let haptics: NoOpHaptics
        let alerts: RecordingSessionAlertScheduler
        let idleGuard: NoOpScreenIdleGuard
    }

    private func makeStack(
        timeZone identifier: String = "UTC",
        year: Int = 2026, month: Int = 6, day: Int = 15, hour: Int = 9, minute: Int = 0
    ) async throws -> Stack {
        let zone = try #require(TimeZone(identifier: identifier))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        let now = try #require(calendar.date(from: components))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: zone)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

        let haptics = NoOpHaptics()
        let alerts = RecordingSessionAlertScheduler()
        let idleGuard = NoOpScreenIdleGuard()

        let engine = FocusEngine(
            repositories: provider,
            clock: clock,
            haptics: haptics,
            alerts: alerts,
            idleGuard: idleGuard,
            ticksAutomatically: false
        )
        engine.apply(settings: AppSettings())

        return Stack(engine: engine, provider: provider, clock: clock, haptics: haptics, alerts: alerts, idleGuard: idleGuard)
    }

    private func pomodoroPlan() -> SessionPlan {
        SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60, intent: "One clean pass")
    }

    private func justStartPlan() -> SessionPlan {
        SessionPlan(mode: .justStart, plannedDuration: 5 * 60)
    }

    private func flowPlan() -> SessionPlan {
        SessionPlan(mode: .flowmodoro, plannedDuration: 0)
    }

    // MARK: Starting

    @Test("Starting persists immediately, before anything else can go wrong")
    func startPersistsAtOnce() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        #expect(stack.engine.status == .running)

        // The durable record exists even though not a single tick has fired.
        let active = try #require(await stack.provider.sessions.activeSession())
        #expect(active.plannedDuration == 25 * 60)
        #expect(active.intent == "One clean pass")
        #expect(active.startedAt == stack.clock.now)
    }

    @Test("Starting schedules the end alert and keeps the screen awake")
    func startArrangesSideEffects() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        #expect(stack.alerts.scheduled.count == 1)
        #expect(stack.idleGuard.isKeepingAwake)
        #expect(stack.haptics.fired.contains(.start))
    }

    @Test("Starting twice does not stack two sessions")
    func startIsIdempotentWhileRunning() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        let first = try #require(stack.engine.session?.id)

        await stack.engine.start(justStartPlan())
        #expect(stack.engine.session?.id == first)
    }

    @Test("Keeping the screen awake honours the setting")
    func idleGuardFollowsSettings() async throws {
        let stack = try await makeStack()

        var settings = AppSettings()
        settings.keepScreenAwakeDuringSession = false
        stack.engine.apply(settings: settings)

        await stack.engine.start(pomodoroPlan())
        #expect(stack.idleGuard.isKeepingAwake == false)
    }

    // MARK: Running

    @Test("Elapsed time comes from the wall clock, not from tick count")
    func elapsedIgnoresMissedTicks() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        // Ten minutes pass with exactly one tick. A counter would read one
        // second; wall-clock derivation reads ten minutes.
        stack.clock.advance(by: 600)
        await stack.engine.tick()

        let snapshot = try #require(stack.engine.snapshot)
        #expect(snapshot.elapsed == 600)
        #expect(snapshot.remaining == 900)
    }

    @Test("Reaching the planned end finishes the session at the planned instant")
    func reachingPlannedEndFinishes() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        let startedAt = try #require(stack.engine.session?.startedAt)

        // The tick lands slightly late, as real ticks do.
        stack.clock.advance(by: 25 * 60 + 3)
        await stack.engine.tick()

        #expect(stack.engine.status == .finished)
        let finished = try #require(stack.engine.finishedSession)
        #expect(finished.wasCompleted)
        #expect(finished.endReason == .reachedPlannedEnd)
        // Dated at the planned end, not at whenever the tick happened to fire.
        #expect(finished.endedAt == startedAt.addingTimeInterval(25 * 60))
        #expect(finished.actualMinutes == 25)
    }

    @Test("Finishing cancels the alert and releases the screen")
    func finishingCleansUp() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        stack.clock.advance(by: 25 * 60)
        await stack.engine.tick()

        #expect(stack.alerts.cancelCount >= 1)
        #expect(stack.idleGuard.isKeepingAwake == false)
        #expect(stack.haptics.fired.contains(.complete))
    }

    @Test("Nothing is left running once a session finishes")
    func noActiveSessionAfterFinish() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        stack.clock.advance(by: 25 * 60)
        await stack.engine.tick()

        #expect(try await stack.provider.sessions.activeSession() == nil)
    }

    // MARK: The escape hatch

    @Test("Ending early records what actually happened")
    func endEarlyRecordsTruthfully() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        stack.clock.advance(by: 6 * 60)
        await stack.engine.endEarly()

        let finished = try #require(stack.engine.finishedSession)
        #expect(finished.endReason == .endedByUser)
        #expect(finished.actualMinutes == 6)
        #expect(finished.wasCompleted == false)
        #expect(stack.alerts.cancelCount >= 1)
    }

    @Test("Ending early once most of the way through still counts")
    func endEarlyPastThresholdCounts() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        // 24 of 25 minutes is a finished Pomodoro by any honest reading.
        stack.clock.advance(by: 24 * 60)
        await stack.engine.endEarly()

        let finished = try #require(stack.engine.finishedSession)
        #expect(finished.wasCompleted)
        #expect(finished.endReason == .endedByUser)
    }

    @Test("An instant start-then-stop leaves no litter")
    func trivialSessionIsDiscarded() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        stack.clock.advance(by: 3)
        await stack.engine.endEarly()

        #expect(stack.engine.status == .idle)
        #expect(stack.engine.finishedSession == nil)
        #expect(try await stack.provider.sessions.recentSessions(limit: 10).isEmpty)
    }

    @Test("Stopping a Flowmodoro session is how it finishes, so it counts")
    func stoppingFlowCounts() async throws {
        let stack = try await makeStack()
        await stack.engine.start(flowPlan())

        stack.clock.advance(by: 40 * 60)
        await stack.engine.endEarly()

        let finished = try #require(stack.engine.finishedSession)
        #expect(finished.wasCompleted)
        #expect(finished.actualMinutes == 40)
    }

    // MARK: Surviving the app going away

    @Test("A session survives force quit and is picked up on relaunch")
    func survivesForceQuit() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        let sessionID = try #require(stack.engine.session?.id)

        // The app dies. A brand new engine over the same store is exactly what
        // relaunching looks like.
        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        stack.clock.advance(by: 8 * 60)
        await relaunched.restore()

        #expect(relaunched.status == .running)
        #expect(relaunched.session?.id == sessionID)

        let snapshot = try #require(relaunched.snapshot)
        #expect(snapshot.elapsed == 8 * 60)
        #expect(snapshot.remaining == TimeInterval(17 * 60))
    }

    @Test("A session whose end passed while the app was gone is credited, dated honestly")
    func finishesWhileAway() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        let startedAt = try #require(stack.engine.session?.startedAt)

        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        // Three hours later. The Pomodoro ended two and a half hours ago.
        stack.clock.advance(by: 3 * 60 * 60)
        await relaunched.restore()

        #expect(relaunched.status == .finished)
        let finished = try #require(relaunched.finishedSession)
        #expect(finished.wasCompleted)
        #expect(finished.endReason == .finishedWhileAway)
        #expect(finished.endedAt == startedAt.addingTimeInterval(25 * 60))
        // Crucially not three hours.
        #expect(finished.actualMinutes == 25)
    }

    @Test("Returning to the foreground settles the session immediately")
    func foregroundResolvesWithoutWaitingForATick() async throws {
        let stack = try await makeStack()
        await stack.engine.start(justStartPlan())

        await stack.engine.scenePhaseChanged(to: .background)
        stack.clock.advance(by: 20 * 60)
        await stack.engine.scenePhaseChanged(to: .active)

        #expect(stack.engine.status == .finished)
        #expect(stack.engine.finishedSession?.actualMinutes == 5)
    }

    @Test("Backgrounding leaves a heartbeat and releases the screen")
    func backgroundWritesHeartbeat() async throws {
        let stack = try await makeStack()
        await stack.engine.start(flowPlan())

        stack.clock.advance(by: 12 * 60)
        await stack.engine.scenePhaseChanged(to: .background)

        #expect(stack.idleGuard.isKeepingAwake == false)
        let active = try #require(await stack.provider.sessions.activeSession())
        #expect(active.lastHeartbeatAt == stack.clock.now)
    }

    @Test("A Flowmodoro session left running overnight is not credited as a marathon")
    func countUpIsCappedAtItsHeartbeat() async throws {
        let stack = try await makeStack()
        await stack.engine.start(flowPlan())

        // Twenty minutes of real work, then the phone dies.
        stack.clock.advance(by: 20 * 60)
        await stack.engine.scenePhaseChanged(to: .background)
        let heartbeat = stack.clock.now

        // Found again the next morning.
        stack.clock.advance(by: 14 * 60 * 60)

        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        await relaunched.restore()

        #expect(relaunched.status == .finished)
        let finished = try #require(relaunched.finishedSession)
        #expect(finished.endReason == .cappedAfterHeartbeat)
        #expect(finished.endedAt == heartbeat)
        #expect(finished.actualMinutes == 20)
        // Recorded, but nobody confirmed it, so it earns no credit.
        #expect(finished.wasCompleted == false)
    }

    @Test("A Flowmodoro session inside the ceiling keeps running")
    func countUpWithinCeilingSurvives() async throws {
        let stack = try await makeStack()
        await stack.engine.start(flowPlan())

        stack.clock.advance(by: 90 * 60)

        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        await relaunched.restore()

        #expect(relaunched.status == .running)
        #expect(relaunched.snapshot?.elapsed == TimeInterval(90 * 60))
    }

    @Test("Nothing to restore means idle, not a phantom session")
    func restoreWithNothingRunning() async throws {
        let stack = try await makeStack()
        await stack.engine.restore()
        #expect(stack.engine.status == .idle)
        #expect(stack.engine.session == nil)
    }

    // MARK: Keep going

    @Test("Keep going credits the short session and starts a fresh one")
    func keepGoingRollsIntoPomodoro() async throws {
        let stack = try await makeStack()
        await stack.engine.start(SessionPlan(mode: .justStart, plannedDuration: 5 * 60, intent: "Open the file"))

        stack.clock.advance(by: 5 * 60)
        await stack.engine.tick()
        #expect(stack.engine.offersExtension)

        await stack.engine.continueSession(as: .classicPomodoro)

        #expect(stack.engine.status == .running)
        let running = try #require(stack.engine.session)
        #expect(running.mode == .classicPomodoro)
        #expect(running.plannedDuration == 25 * 60)
        // The intent carries across rather than being asked for again.
        #expect(running.intent == "Open the file")

        // Both intervals are on the record, and the five minutes are credited.
        let all = try await stack.provider.sessions.recentSessions(limit: 10)
        #expect(all.count == 2)
        #expect(all.filter(\.wasCompleted).count == 1)
    }

    @Test("Only modes that offer it get the keep-going prompt")
    func extensionIsOfferedOnlyByJustStart() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())
        stack.clock.advance(by: 25 * 60)
        await stack.engine.tick()

        #expect(stack.engine.status == .finished)
        #expect(stack.engine.offersExtension == false)
    }

    @Test("An abandoned session is not offered an extension")
    func noExtensionAfterAbandoning() async throws {
        let stack = try await makeStack()
        await stack.engine.start(justStartPlan())
        stack.clock.advance(by: 30)
        await stack.engine.endEarly()

        #expect(stack.engine.offersExtension == false)
    }

    @Test("Dismissing the completion screen returns to idle")
    func dismissCompletion() async throws {
        let stack = try await makeStack()
        await stack.engine.start(justStartPlan())
        stack.clock.advance(by: 5 * 60)
        await stack.engine.tick()

        stack.engine.dismissCompletion()
        #expect(stack.engine.status == .idle)
        #expect(stack.engine.finishedSession == nil)
    }

    // MARK: Clocks behaving badly

    @Test("A session spanning a DST change is measured in real elapsed time")
    func dstDoesNotDistortASession() async throws {
        // 8 March 2026, 01:30 New York — thirty minutes before the clocks jump
        // forward. Wall-clock time skips 02:00 to 03:00.
        let stack = try await makeStack(
            timeZone: "America/New_York",
            year: 2026, month: 3, day: 8, hour: 1, minute: 30
        )
        await stack.engine.start(SessionPlan(mode: .deepWork, plannedDuration: 52 * 60))
        let startedAt = try #require(stack.engine.session?.startedAt)

        stack.clock.advance(by: 52 * 60)
        await stack.engine.tick()

        let finished = try #require(stack.engine.finishedSession)
        // 52 real minutes, whatever the wall clock displayed in between.
        #expect(finished.endedAt == startedAt.addingTimeInterval(52 * 60))
        #expect(finished.actualMinutes == 52)
        #expect(finished.wasCompleted)
    }

    @Test("Flying to another timezone mid-session changes nothing")
    func timezoneChangeDoesNotDistortASession() async throws {
        let stack = try await makeStack(timeZone: "UTC")
        await stack.engine.start(pomodoroPlan())
        let startedAt = try #require(stack.engine.session?.startedAt)

        // Same absolute instants, a clock nine hours off.
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyo
        let travelled = MutableDateProvider(
            now: startedAt.addingTimeInterval(10 * 60),
            calendar: calendar,
            timeZone: tokyo
        )

        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: travelled,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        await relaunched.restore()

        #expect(relaunched.status == .running)
        #expect(relaunched.snapshot?.elapsed == 600)
    }

    @Test("A clock dragged backwards cannot produce negative time")
    func clockMovingBackwards() async throws {
        let stack = try await makeStack()
        await stack.engine.start(pomodoroPlan())

        stack.clock.advance(by: -3600)
        await stack.engine.tick()

        let snapshot = try #require(stack.engine.snapshot)
        #expect(snapshot.elapsed == 0)
        #expect(snapshot.displayInterval == 25 * 60)
        #expect(stack.engine.status == .running)
    }
}

// MARK: - Pure decision logic

@Suite("Unattended session resolution")
struct UnattendedResolutionTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(mode: SessionMode, planned: TimeInterval, heartbeat: TimeInterval? = nil) -> FocusSession {
        var session = FocusSession()
        session.mode = mode
        session.startedAt = start
        session.plannedDuration = planned
        session.lastHeartbeatAt = heartbeat.map { start.addingTimeInterval($0) }
        return session
    }

    @Test("A count-down session still inside its window is left alone")
    func countDownStillRunning() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .classicPomodoro, planned: 25 * 60),
            now: start.addingTimeInterval(10 * 60)
        )
        #expect(result == nil)
    }

    @Test("A count-down session past its end is closed at its end")
    func countDownPastEnd() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .classicPomodoro, planned: 25 * 60),
            now: start.addingTimeInterval(9 * 60 * 60)
        )
        #expect(result?.reason == .finishedWhileAway)
        #expect(result?.endedAt == start.addingTimeInterval(25 * 60))
    }

    @Test("An already-ended session is never resolved twice")
    func endedSessionIsIgnored() {
        var ended = session(mode: .classicPomodoro, planned: 25 * 60)
        ended.endedAt = start.addingTimeInterval(25 * 60)
        #expect(FocusEngine.resolveUnattended(ended, now: start.addingTimeInterval(99_999)) == nil)
    }

    @Test("A count-up session under the ceiling keeps running")
    func countUpUnderCeiling() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .flowmodoro, planned: 0),
            now: start.addingTimeInterval(2 * 60 * 60)
        )
        #expect(result == nil)
    }

    @Test("A count-up session over the ceiling falls back to its heartbeat")
    func countUpOverCeilingUsesHeartbeat() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .flowmodoro, planned: 0, heartbeat: 25 * 60),
            now: start.addingTimeInterval(20 * 60 * 60)
        )
        #expect(result?.reason == .cappedAfterHeartbeat)
        #expect(result?.endedAt == start.addingTimeInterval(25 * 60))
    }

    @Test("With no heartbeat, a runaway count-up session is closed at its start")
    func countUpOverCeilingWithoutHeartbeat() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .flowmodoro, planned: 0),
            now: start.addingTimeInterval(20 * 60 * 60)
        )
        #expect(result?.reason == .cappedAfterHeartbeat)
        // No heartbeat ever fired, so the last moment the app knew anyone was
        // there is the moment it started. Crediting the full four-hour ceiling
        // instead would be exactly the "phone died overnight reads as deep
        // work" outcome the cap exists to prevent — and it is not counted as
        // completed either way, so the only thing at stake is whether the
        // history tells the truth.
        #expect(result?.endedAt == start)
    }

    @Test("A heartbeat later than the ceiling is clamped to the ceiling")
    func heartbeatCannotExceedCeiling() {
        let result = FocusEngine.resolveUnattended(
            session(mode: .flowmodoro, planned: 0, heartbeat: 10 * 60 * 60),
            now: start.addingTimeInterval(20 * 60 * 60)
        )
        #expect(result?.endedAt == start.addingTimeInterval(FocusRules.maximumUnattendedCountUp))
    }
}

@Suite("Completion credit")
struct CompletionCreditTests {

    private func session(mode: SessionMode, planned: TimeInterval) -> FocusSession {
        var session = FocusSession()
        session.mode = mode
        session.plannedDuration = planned
        return session
    }

    @Test("Running to the planned end always counts")
    func plannedEndCounts() {
        let pomodoro = session(mode: .classicPomodoro, planned: 25 * 60)
        #expect(FocusEngine.countsAsCompleted(reason: .reachedPlannedEnd, session: pomodoro, elapsed: 25 * 60))
        #expect(FocusEngine.countsAsCompleted(reason: .finishedWhileAway, session: pomodoro, elapsed: 25 * 60))
    }

    @Test("Ending early counts once past the threshold")
    func earlyEndThreshold() {
        let pomodoro = session(mode: .classicPomodoro, planned: 25 * 60)
        let threshold = 25 * 60 * FocusRules.completionThreshold

        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: pomodoro, elapsed: threshold))
        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: pomodoro, elapsed: threshold - 1) == false)
    }

    @Test("A five-minute Just Start counts from four minutes in")
    func justStartThreshold() {
        let justStart = session(mode: .justStart, planned: 5 * 60)
        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: justStart, elapsed: 4 * 60))
        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: justStart, elapsed: 2 * 60) == false)
    }

    @Test("Stopping a count-up session counts once it is worth recording")
    func countUpCounts() {
        let flow = session(mode: .flowmodoro, planned: 0)
        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: flow, elapsed: 30 * 60))
        #expect(FocusEngine.countsAsCompleted(reason: .endedByUser, session: flow, elapsed: 2) == false)
    }

    @Test("A capped session is recorded but never credited")
    func cappedNeverCounts() {
        let flow = session(mode: .flowmodoro, planned: 0)
        #expect(FocusEngine.countsAsCompleted(reason: .cappedAfterHeartbeat, session: flow, elapsed: 4 * 60 * 60) == false)
    }
}
