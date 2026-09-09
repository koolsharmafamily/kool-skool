import Foundation
import SwiftUI
import Testing
@testable import KoolSkool

@MainActor
@Suite("Time check pulses")
struct TimeCheckTests {

    private func makeStack(
        checksEnabled: Bool,
        intervalMinutes: Int = 10
    ) async throws -> (engine: FocusEngine, clock: MutableDateProvider, haptics: NoOpHaptics, provider: SwiftDataRepositoryProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))

        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let haptics = NoOpHaptics()

        let engine = FocusEngine(
            repositories: provider,
            clock: clock,
            haptics: haptics,
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )

        var settings = AppSettings()
        settings.timeChecksEnabled = checksEnabled
        settings.timeCheckIntervalMinutes = intervalMinutes
        engine.apply(settings: settings)

        return (engine, clock, haptics, provider)
    }

    private func pulseCount(_ haptics: NoOpHaptics) -> Int {
        haptics.fired.filter { $0 == .timeCheck }.count
    }

    private var deepWork: SessionPlan {
        SessionPlan(mode: .deepWork, plannedDuration: 52 * 60)
    }

    @Test("Off by default, so nobody gets buzzed who did not ask")
    func silentByDefault() async throws {
        #expect(AppSettings().timeChecksEnabled == false)

        let stack = try await makeStack(checksEnabled: false)
        await stack.engine.start(deepWork)

        stack.clock.advance(by: 30 * 60)
        await stack.engine.tick()

        #expect(pulseCount(stack.haptics) == 0)
    }

    @Test("A pulse arrives at the interval")
    func firesAtTheInterval() async throws {
        let stack = try await makeStack(checksEnabled: true)
        await stack.engine.start(deepWork)

        stack.clock.advance(by: 9 * 60)
        await stack.engine.tick()
        #expect(pulseCount(stack.haptics) == 0)

        stack.clock.advance(by: 60)
        await stack.engine.tick()
        #expect(pulseCount(stack.haptics) == 1)
    }

    @Test("Pulses keep coming, one per interval")
    func firesRepeatedly() async throws {
        let stack = try await makeStack(checksEnabled: true)
        await stack.engine.start(deepWork)

        for _ in 0..<4 {
            stack.clock.advance(by: 10 * 60)
            await stack.engine.tick()
        }

        #expect(pulseCount(stack.haptics) == 4)
    }

    @Test("Coming back from the background buzzes once, not once per missed interval")
    func doesNotBurstAfterBackgrounding() async throws {
        let stack = try await makeStack(checksEnabled: true)
        await stack.engine.start(deepWork)

        // Thirty-five minutes pass with the app away. Three intervals elapsed.
        stack.clock.advance(by: 35 * 60)
        await stack.engine.tick()

        // Three buzzes in a row would be an alarm, not a time check.
        #expect(pulseCount(stack.haptics) == 1)

        stack.clock.advance(by: 10 * 60)
        await stack.engine.tick()
        #expect(pulseCount(stack.haptics) == 2)
    }

    @Test("A custom interval is honoured")
    func customInterval() async throws {
        let stack = try await makeStack(checksEnabled: true, intervalMinutes: 5)
        await stack.engine.start(deepWork)

        stack.clock.advance(by: 12 * 60)
        await stack.engine.tick()
        #expect(pulseCount(stack.haptics) == 1)

        stack.clock.advance(by: 3 * 60)
        await stack.engine.tick()
        #expect(pulseCount(stack.haptics) == 2)
    }

    @Test("Restoring mid-session does not replay the pulses already missed")
    func restoreDoesNotReplay() async throws {
        let stack = try await makeStack(checksEnabled: true)
        await stack.engine.start(SessionPlan(mode: .flowmodoro, plannedDuration: 0))

        // Forty-five minutes into a count-up session, the app is killed.
        stack.clock.advance(by: 45 * 60)

        let haptics = NoOpHaptics()
        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: haptics,
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        var settings = AppSettings()
        settings.timeChecksEnabled = true
        relaunched.apply(settings: settings)
        await relaunched.restore()

        // Four intervals already went by. Relaunching must not buzz four times
        // to catch up.
        #expect(relaunched.status == .running)
        #expect(pulseCount(haptics) == 0)

        // The next one still arrives on schedule.
        stack.clock.advance(by: 5 * 60)
        await relaunched.tick()
        #expect(pulseCount(haptics) == 1)
    }
}

@MainActor
@Suite("Depleting disc")
struct DepletingDiscTests {

    private let frame = CGRect(x: 0, y: 0, width: 200, height: 200)

    @Test("An empty disc draws nothing")
    func emptyAtZero() {
        #expect(DiscWedge(remaining: 0).path(in: frame).isEmpty)
        #expect(DiscWedge(remaining: -0.5).path(in: frame).isEmpty)
    }

    @Test("A full disc is a whole circle")
    func fullAtOne() {
        let bounds = DiscWedge(remaining: 1).path(in: frame).boundingRect
        #expect(abs(bounds.width - 200) < 0.5)
        #expect(abs(bounds.height - 200) < 0.5)
    }

    @Test("Overshooting clamps to full rather than wrapping around")
    func clampsAboveOne() {
        let clamped = DiscWedge(remaining: 4).path(in: frame).boundingRect
        let full = DiscWedge(remaining: 1).path(in: frame).boundingRect
        #expect(clamped == full)
    }

    @Test("A partial disc draws something smaller than the whole")
    func partialWedge() {
        let path = DiscWedge(remaining: 0.25).path(in: frame)
        #expect(path.isEmpty == false)

        // A quarter drains from twelve o'clock clockwise, so it stays in the
        // top-right quadrant plus the centre point.
        let bounds = path.boundingRect
        #expect(bounds.width <= 101)
        #expect(bounds.height <= 101)
    }

    @Test("The wedge animates as one continuous value")
    func animatableData() {
        var wedge = DiscWedge(remaining: 0.4)
        #expect(wedge.animatableData == 0.4)

        wedge.animatableData = 0.9
        #expect(wedge.remaining == 0.9)
    }
}

@Suite("Ambient shift")
struct AmbientShiftTests {

    private func snapshot(mode: SessionMode, planned: TimeInterval, elapsed: TimeInterval) -> SessionSnapshot {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var session = FocusSession()
        session.mode = mode
        session.startedAt = start
        session.plannedDuration = planned
        return SessionSnapshot(session: session, now: start.addingTimeInterval(elapsed))
    }

    @Test("The background warms in step with the session")
    func tracksProgress() {
        #expect(snapshot(mode: .classicPomodoro, planned: 1500, elapsed: 0).ambientProgress == 0)
        #expect(snapshot(mode: .classicPomodoro, planned: 1500, elapsed: 750).ambientProgress == 0.5)
        #expect(snapshot(mode: .classicPomodoro, planned: 1500, elapsed: 1500).ambientProgress == 1)
    }

    @Test("A count-up session never implies a deadline it does not have")
    func flowNeverWarms() {
        // Migrating toward the overrun colour would invent a finish line for a
        // mode whose whole point is not having one.
        #expect(snapshot(mode: .flowmodoro, planned: 0, elapsed: 3 * 3600).ambientProgress == 0)
    }
}
