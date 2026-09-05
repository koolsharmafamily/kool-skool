import Foundation
import Testing
@testable import KoolSkool

@Suite("Session modes")
struct SessionModeTests {

    @Test("Just Start is five minutes with no break")
    func justStartProfile() {
        let profile = SessionMode.justStart.defaultProfile
        #expect(profile.workDuration == 5 * 60)
        #expect(profile.breakDuration == 0)
        #expect(profile.countsUp == false)
        // The whole point: finishing offers to roll into something longer.
        #expect(profile.offersExtension)
    }

    @Test("Just Start is first in the picker")
    func justStartLeadsThePicker() {
        #expect(SessionMode.pickerOrder.first == .justStart)
        #expect(Set(SessionMode.pickerOrder) == Set(SessionMode.allCases))
    }

    @Test("Classic Pomodoro is 25/5 with a long break after four")
    func pomodoroProfile() {
        let profile = SessionMode.classicPomodoro.defaultProfile
        #expect(profile.workDuration == 25 * 60)
        #expect(profile.breakDuration == 5 * 60)
        #expect(profile.longBreakDuration == 15 * 60)
        #expect(profile.sessionsUntilLongBreak == 4)
    }

    @Test("Deep Work is 52/17")
    func deepWorkProfile() {
        let profile = SessionMode.deepWork.defaultProfile
        #expect(profile.workDuration == 52 * 60)
        #expect(profile.breakDuration == 17 * 60)
    }

    @Test("Flowmodoro counts up")
    func flowmodoroCountsUp() {
        let profile = SessionMode.flowmodoro.defaultProfile
        #expect(profile.countsUp)
        #expect(profile.flowBreakDivisor == 5)
    }

    @Test("Flowmodoro break is elapsed divided by five")
    func flowmodoroBreakMath() {
        let profile = SessionMode.flowmodoro.defaultProfile
        // 50 minutes of work earns a 10 minute break.
        #expect(profile.breakDuration(forElapsedWork: 50 * 60) == 10 * 60)
        // 25 minutes earns 5.
        #expect(profile.breakDuration(forElapsedWork: 25 * 60) == 5 * 60)
    }

    @Test("A very long hyperfocus does not earn an absurd break")
    func flowmodoroBreakIsClampedAtTheTop() {
        let profile = SessionMode.flowmodoro.defaultProfile
        // Six hours divided by five would be 72 minutes.
        let sixHours: TimeInterval = 6 * 60 * 60
        #expect(profile.breakDuration(forElapsedWork: sixHours) == 30 * 60)
    }

    @Test("A very short flow session still earns a real break")
    func flowmodoroBreakIsClampedAtTheBottom() {
        let profile = SessionMode.flowmodoro.defaultProfile
        // Two minutes divided by five would be 24 seconds.
        #expect(profile.breakDuration(forElapsedWork: 120) == 60)
    }

    @Test("Fixed modes ignore elapsed time when sizing the break")
    func fixedModesIgnoreElapsed() {
        let profile = SessionMode.classicPomodoro.defaultProfile
        #expect(profile.breakDuration(forElapsedWork: 90 * 60) == 5 * 60)
        #expect(profile.breakDuration(forElapsedWork: 0) == 5 * 60)
    }

    @Test("Custom mode reads its durations from settings")
    func customModeUsesSettings() {
        let profile = SessionMode.custom.profile(customWorkMinutes: 40, customBreakMinutes: 8)
        #expect(profile.workDuration == 40 * 60)
        #expect(profile.breakDuration == 8 * 60)
    }

    @Test("Custom durations cannot be zero or negative")
    func customModeClampsNonsense() {
        let profile = SessionMode.custom.profile(customWorkMinutes: 0, customBreakMinutes: -5)
        #expect(profile.workDuration == 60)
        #expect(profile.breakDuration == 0)
    }

    @Test("Non-custom modes ignore the custom settings")
    func builtInModesIgnoreCustomSettings() {
        let profile = SessionMode.deepWork.profile(customWorkMinutes: 5, customBreakMinutes: 1)
        #expect(profile.workDuration == 52 * 60)
    }
}

@Suite("Session elapsed-time maths")
struct FocusSessionMathTests {

    private func session(planned: TimeInterval, startedAt: Date) -> FocusSession {
        var session = FocusSession()
        session.startedAt = startedAt
        session.plannedDuration = planned
        return session
    }

    @Test("Elapsed time is wall-clock, not a decrementing counter")
    func elapsedIsWallClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = session(planned: 25 * 60, startedAt: start)

        #expect(session.elapsed(asOf: start) == 0)
        #expect(session.elapsed(asOf: start.addingTimeInterval(600)) == 600)
        // This is the case that matters: the app was killed for an hour and
        // relaunched. Elapsed time reflects reality, not how long the app ran.
        #expect(session.elapsed(asOf: start.addingTimeInterval(3600)) == 3600)
    }

    @Test("Elapsed time is never negative, even if the clock moves backwards")
    func elapsedNeverGoesNegative() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = session(planned: 25 * 60, startedAt: start)
        #expect(session.elapsed(asOf: start.addingTimeInterval(-500)) == 0)
    }

    @Test("Elapsed time freezes once the session ends")
    func elapsedStopsAtEnd() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var session = session(planned: 25 * 60, startedAt: start)
        session.endedAt = start.addingTimeInterval(900)

        #expect(session.elapsed(asOf: start.addingTimeInterval(5000)) == 900)
        #expect(session.actualMinutes == 15)
    }

    @Test("Remaining time goes negative on an overrun")
    func remainingGoesNegative() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = session(planned: 25 * 60, startedAt: start)
        #expect(session.remaining(asOf: start.addingTimeInterval(30 * 60)) == -300)
    }

    @Test("Disc progress is clamped to 0...1")
    func progressIsClamped() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = session(planned: 25 * 60, startedAt: start)

        #expect(session.progress(asOf: start) == 0)
        #expect(session.progress(asOf: start.addingTimeInterval(750)) == 0.5)
        // Overrun holds the disc at full rather than wrapping around.
        #expect(session.progress(asOf: start.addingTimeInterval(9999)) == 1)
    }

    @Test("Count-up sessions report zero progress rather than dividing by zero")
    func countUpProgressIsSafe() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = session(planned: 0, startedAt: start)
        #expect(session.progress(asOf: start.addingTimeInterval(600)) == 0)
    }

    @Test("A session with no end date is still running")
    func runningState() {
        var session = session(planned: 300, startedAt: .now)
        #expect(session.isRunning)
        session.endedAt = .now
        #expect(session.isRunning == false)
    }
}
