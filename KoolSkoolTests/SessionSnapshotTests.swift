import Foundation
import Testing
@testable import KoolSkool

@Suite("Session snapshot")
struct SessionSnapshotTests {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func countDown(_ planned: TimeInterval = 25 * 60) -> FocusSession {
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = start
        session.plannedDuration = planned
        return session
    }

    private func countUp() -> FocusSession {
        var session = FocusSession()
        session.mode = .flowmodoro
        session.startedAt = start
        session.plannedDuration = 0
        return session
    }

    @Test("Count-down shows time remaining")
    func countDownShowsRemaining() {
        let snapshot = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(600))
        #expect(snapshot.countsUp == false)
        #expect(snapshot.remaining == 900)
        #expect(snapshot.displayInterval == 900)
        #expect(snapshot.formattedTime == "15:00")
    }

    @Test("Count-up shows time spent")
    func countUpShowsElapsed() {
        let snapshot = SessionSnapshot(session: countUp(), now: start.addingTimeInterval(600))
        #expect(snapshot.countsUp)
        #expect(snapshot.remaining == nil)
        #expect(snapshot.displayInterval == 600)
        #expect(snapshot.formattedTime == "10:00")
    }

    @Test("The clock never shows a negative number")
    func displayNeverGoesNegative() {
        let snapshot = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(40 * 60))
        #expect(snapshot.displayInterval == 0)
        #expect(snapshot.formattedTime == "0:00")
    }

    @Test("Past an hour the format grows a field")
    func longFormat() {
        #expect(SessionSnapshot.format(0) == "0:00")
        #expect(SessionSnapshot.format(59) == "0:59")
        #expect(SessionSnapshot.format(60) == "1:00")
        #expect(SessionSnapshot.format(59 * 60 + 59) == "59:59")
        #expect(SessionSnapshot.format(3600) == "1:00:00")
        #expect(SessionSnapshot.format(3661) == "1:01:01")
    }

    @Test("VoiceOver gets words, not a time of day")
    func spokenTime() {
        let mid = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(600))
        #expect(mid.spokenTime == "15 minutes remaining")

        let nearlyDone = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(25 * 60 - 30))
        #expect(nearlyDone.spokenTime == "30 seconds remaining")

        let flow = SessionSnapshot(session: countUp(), now: start.addingTimeInterval(90))
        #expect(flow.spokenTime == "1 minute elapsed")
    }

    @Test("Seconds are only spoken when they are the whole story")
    func spokenTimeOmitsNoisySeconds() {
        // Announcing "14 minutes 59 seconds" then "14 minutes 58 seconds" makes
        // the screen unusable with VoiceOver on.
        #expect(SessionSnapshot.spoken(14 * 60 + 59) == "14 minutes")
        #expect(SessionSnapshot.spoken(45) == "45 seconds")
        #expect(SessionSnapshot.spoken(3600 + 120) == "1 hour 2 minutes")
    }

    @Test("Time being up is announced as such")
    func spokenTimeAtZero() {
        let snapshot = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(25 * 60))
        #expect(snapshot.spokenTime == "Time is up")
    }

    @Test("The ambient shift tracks progress, and count-up never shifts")
    func ambientProgress() {
        let half = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(750))
        #expect(half.ambientProgress == 0.5)

        // Flowmodoro has no deadline. Implying one with a colour ramp would
        // defeat the entire point of the mode.
        let flow = SessionSnapshot(session: countUp(), now: start.addingTimeInterval(3600))
        #expect(flow.ambientProgress == 0)
    }

    @Test("Overrun is only possible while the session is still running")
    func overrunState() {
        let running = SessionSnapshot(session: countDown(), now: start.addingTimeInterval(26 * 60))
        #expect(running.isOverrun)
        #expect(running.energyState == .overrun)

        var ended = countDown()
        ended.endedAt = start.addingTimeInterval(25 * 60)
        let finished = SessionSnapshot(session: ended, now: start.addingTimeInterval(60 * 60))
        #expect(finished.isOverrun == false)
    }

    @Test("A session with no planned duration counts up whatever its mode says")
    func zeroDurationCountsUp() {
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = start
        session.plannedDuration = 0

        let snapshot = SessionSnapshot(session: session, now: start.addingTimeInterval(120))
        #expect(snapshot.countsUp)
        #expect(snapshot.displayInterval == 120)
    }
}
