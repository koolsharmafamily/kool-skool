import Foundation
import Testing
@testable import KoolSkool

@Suite("Insights")
struct InsightsCalculatorTests {

    // MARK: Fixtures

    /// Wednesday 17 June 2026, 10:00 UTC.
    private func clock() throws -> MutableDateProvider {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 10)))
        return MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
    }

    /// A finished session `daysAgo` days back, starting at `hour` local time.
    private func session(
        daysAgo: Int,
        hour: Int,
        completed: Bool,
        clock: MutableDateProvider,
        reason: SessionEndReason? = nil
    ) -> FocusSession {
        let day = clock.startOfDay(for: clock.now.addingTimeInterval(-Double(daysAgo) * 86_400))
        let start = day.addingTimeInterval(Double(hour) * 3600)

        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = start
        session.plannedDuration = 25 * 60
        session.endedAt = start.addingTimeInterval(25 * 60)
        session.wasCompleted = completed
        session.endReason = reason ?? (completed ? .reachedPlannedEnd : .endedByUser)
        return session
    }

    /// `total` sessions at `hour`, the first `completed` of them completed,
    /// spread one per day starting `startingDaysAgo` back.
    private func sessions(
        at hour: Int,
        total: Int,
        completed: Int,
        startingDaysAgo: Int = 20,
        clock: MutableDateProvider
    ) -> [FocusSession] {
        (0..<total).map { index in
            session(daysAgo: startingDaysAgo - index, hour: hour, completed: index < completed, clock: clock)
        }
    }

    // MARK: Time of day

    @Test("Hours fall into the right block, including the one that wraps midnight")
    func blockBoundaries() {
        #expect(TimeOfDay.of(hour: 4) == .late)
        #expect(TimeOfDay.of(hour: 5) == .early)
        #expect(TimeOfDay.of(hour: 7) == .early)
        #expect(TimeOfDay.of(hour: 8) == .morning)
        #expect(TimeOfDay.of(hour: 11) == .morning)
        #expect(TimeOfDay.of(hour: 12) == .afternoon)
        #expect(TimeOfDay.of(hour: 16) == .afternoon)
        #expect(TimeOfDay.of(hour: 17) == .evening)
        #expect(TimeOfDay.of(hour: 20) == .evening)
        #expect(TimeOfDay.of(hour: 21) == .late)
        #expect(TimeOfDay.of(hour: 0) == .late)
    }

    // MARK: Which sessions count

    @Test("Running, deleted and unconfirmed sessions are left out")
    func countableFiltersCorrectly() throws {
        let clock = try clock()

        var running = session(daysAgo: 1, hour: 9, completed: false, clock: clock)
        running.endedAt = nil

        var deleted = session(daysAgo: 1, hour: 9, completed: true, clock: clock)
        deleted.deletedAt = clock.now

        let capped = session(daysAgo: 1, hour: 23, completed: false, clock: clock, reason: .cappedAfterHeartbeat)
        let normal = session(daysAgo: 1, hour: 9, completed: true, clock: clock)

        let counted = InsightsCalculator.countable([running, deleted, capped, normal])
        #expect(counted.map(\.id) == [normal.id])
    }

    // MARK: History gate

    @Test("Nothing is said before two weeks and ten sessions")
    func historyGate() throws {
        let clock = try clock()

        // Plenty of sessions, but all in the last week.
        let recent = sessions(at: 9, total: 12, completed: 6, startingDaysAgo: 6, clock: clock)
        #expect(InsightsCalculator.hasEnoughHistory(recent, now: clock.now) == false)

        // Two weeks back, but only a handful.
        let sparse = sessions(at: 9, total: 4, completed: 2, startingDaysAgo: 20, clock: clock)
        #expect(InsightsCalculator.hasEnoughHistory(sparse, now: clock.now) == false)

        // Both.
        let enough = sessions(at: 9, total: 12, completed: 6, startingDaysAgo: 20, clock: clock)
        #expect(InsightsCalculator.hasEnoughHistory(enough, now: clock.now))
    }

    // MARK: Buckets

    @Test("Sessions land in their block with the right completion rate")
    func bucketsCount() throws {
        let clock = try clock()
        let all = sessions(at: 9, total: 4, completed: 3, clock: clock)
            + sessions(at: 14, total: 2, completed: 0, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        let morning = try #require(buckets.first { $0.block == .morning })
        let afternoon = try #require(buckets.first { $0.block == .afternoon })

        #expect(morning.sessions == 4)
        #expect(morning.completed == 3)
        #expect(morning.completionRate == 0.75)
        #expect(afternoon.completionRate == 0)
        #expect(buckets.count == TimeOfDay.allCases.count)
    }

    @Test("Focus quality comes from post-session check-ins only")
    func qualityFromPostCheckIns() throws {
        let clock = try clock()
        let morning = sessions(at: 9, total: 2, completed: 2, clock: clock)

        func checkIn(_ phase: CheckInPhase, quality: Int?, for session: FocusSession?) -> CheckIn {
            var checkIn = CheckIn()
            checkIn.phase = phase
            checkIn.focusQuality = quality.map { Rating(clamping: $0) }
            checkIn.energy = Rating(clamping: 1)
            checkIn.sessionID = session?.id
            return checkIn
        }

        let checkIns = [
            checkIn(.post, quality: 4, for: morning[0]),
            checkIn(.post, quality: 2, for: morning[1]),
            // A pre-session energy reading is a different question.
            checkIn(.pre, quality: 5, for: morning[0]),
            // One pointing at a session that isn't in the window.
            checkIn(.post, quality: 5, for: nil),
        ]

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: morning, checkIns: checkIns, clock: clock)
        let bucket = try #require(buckets.first { $0.block == .morning })

        #expect(bucket.qualityCount == 2)
        #expect(bucket.averageFocusQuality == 3)
    }

    // MARK: The one sentence

    @Test("A real difference is reported as one")
    func patternFound() throws {
        let clock = try clock()
        let all = sessions(at: 9, total: 10, completed: 8, clock: clock)
            + sessions(at: 14, total: 10, completed: 5, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        let insight = try #require(InsightsCalculator.timeOfDayInsight(buckets))

        // 80% against 50% is 60% more often.
        #expect(insight.isPattern)
        #expect(insight.block == .morning)
        #expect(insight.sentence == "Your morning sessions complete about 60% more often than the rest.")
    }

    @Test("No difference is reported as no difference, not dressed up")
    func noPattern() throws {
        let clock = try clock()
        let all = sessions(at: 9, total: 10, completed: 7, clock: clock)
            + sessions(at: 14, total: 10, completed: 7, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        let insight = try #require(InsightsCalculator.timeOfDayInsight(buckets))

        #expect(insight.isPattern == false)
        #expect(insight.sentence == "Your sessions complete about as often whatever the time of day.")
    }

    @Test("A small wobble stays below the line")
    func smallDifferenceIsNotAFinding() throws {
        let clock = try clock()
        // 80% against 73% is about 10% — under the 15% bar.
        let all = sessions(at: 9, total: 10, completed: 8, clock: clock)
            + sessions(at: 14, total: 15, completed: 11, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        let insight = try #require(InsightsCalculator.timeOfDayInsight(buckets))
        #expect(insight.isPattern == false)
    }

    @Test("Too few sessions in every block says nothing at all")
    func tooThinToSay() throws {
        let clock = try clock()
        let all = sessions(at: 9, total: 3, completed: 3, clock: clock)
            + sessions(at: 14, total: 3, completed: 0, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        #expect(InsightsCalculator.timeOfDayInsight(buckets) == nil)
    }

    @Test("With nothing to compare against there is no comparison to make")
    func noRestToCompare() throws {
        let clock = try clock()
        let all = sessions(at: 9, total: 10, completed: 8, clock: clock)
            + sessions(at: 14, total: 2, completed: 1, clock: clock)

        let buckets = InsightsCalculator.timeOfDayBuckets(sessions: all, checkIns: [], clock: clock)
        #expect(InsightsCalculator.timeOfDayInsight(buckets) == nil)
    }

    // MARK: Medication

    private func log(daysAgo: Int, taken: Bool = true, clock: MutableDateProvider) -> MedicationLog {
        var log = MedicationLog()
        log.timestamp = clock.startOfDay(for: clock.now.addingTimeInterval(-Double(daysAgo) * 86_400))
            .addingTimeInterval(8 * 3600)
        log.taken = taken
        return log
    }

    @Test("Nothing is said about medication until both sides have a week")
    func medicationGate() throws {
        let clock = try clock()
        let loggedDays = Array(1...7)
        let unloggedDays = Array(8...13)

        let all = (loggedDays + unloggedDays).map { session(daysAgo: $0, hour: 10, completed: true, clock: clock) }
        let logs = loggedDays.map { log(daysAgo: $0, clock: clock) }

        #expect(InsightsCalculator.medicationObservation(sessions: all, logs: logs, clock: clock) == nil)
    }

    @Test("The observation is arithmetic on the log and nothing more")
    func medicationObservation() throws {
        let clock = try clock()
        let loggedDays = Array(1...7)
        let unloggedDays = Array(8...14)

        var all: [FocusSession] = []
        for day in loggedDays {
            all.append(session(daysAgo: day, hour: 10, completed: true, clock: clock))
            all.append(session(daysAgo: day, hour: 15, completed: true, clock: clock))
        }
        for day in unloggedDays {
            all.append(session(daysAgo: day, hour: 10, completed: true, clock: clock))
            all.append(session(daysAgo: day, hour: 15, completed: false, clock: clock))
        }
        let logs = loggedDays.map { log(daysAgo: $0, clock: clock) }

        let observation = try #require(InsightsCalculator.medicationObservation(sessions: all, logs: logs, clock: clock))

        #expect(observation.daysWithLog == 7)
        #expect(observation.daysWithoutLog == 7)
        #expect(observation.completionWithLog == 1)
        #expect(observation.completionWithoutLog == 0.5)
        #expect(observation.sentence == "On days you logged it, you completed 100% of sessions. On days you didn't, 50%.")
    }

    @Test("The sentence never offers a reason, a cause, or advice")
    func medicationSentenceIsObservational() throws {
        let observation = MedicationObservation(
            daysWithLog: 10, daysWithoutLog: 10,
            completionWithLog: 0.8, completionWithoutLog: 0.4
        )
        let sentence = observation.sentence.lowercased()

        for forbidden in ["because", "helps", "works", "effective", "should", "improve", "caus", "recommend", "dose"] {
            #expect(!sentence.contains(forbidden), "The medication sentence must not say \"\(forbidden)\"")
        }
    }

    @Test("A log marked not-taken, or deleted, does not count as a logged day")
    func onlyTakenLogsCount() throws {
        let clock = try clock()
        let days = Array(1...14)
        let all = days.map { session(daysAgo: $0, hour: 10, completed: true, clock: clock) }

        var deleted = log(daysAgo: 3, clock: clock)
        deleted.deletedAt = clock.now
        let logs = [log(daysAgo: 1, taken: false, clock: clock), deleted]

        // Nothing actually logged, so there is no "with" group at all.
        #expect(InsightsCalculator.medicationObservation(sessions: all, logs: logs, clock: clock) == nil)
    }

    // MARK: Calendar

    @Test("The calendar is whole weeks ending with this one")
    func calendarShape() throws {
        let clock = try clock()
        let days = InsightsCalculator.calendar(
            completedDays: [],
            frozenDays: [],
            today: clock.now,
            weeks: 5,
            clock: clock
        )

        #expect(days.count == 35)
        #expect(days.filter(\.isToday).count == 1)

        let todayIndex = try #require(days.firstIndex { $0.isToday })
        #expect(days[(todayIndex + 1)...].allSatisfy { $0.state == .future })
    }

    @Test("Each day is drawn as what it was")
    func calendarStates() throws {
        let clock = try clock()
        let dayBefore = clock.now.addingTimeInterval(-2 * 86_400)
        let yesterday = clock.now.addingTimeInterval(-86_400)
        let fourDaysAgo = clock.now.addingTimeInterval(-4 * 86_400)
        let threeDaysAgo = clock.now.addingTimeInterval(-3 * 86_400)

        let days = InsightsCalculator.calendar(
            completedDays: [fourDaysAgo, dayBefore, yesterday],
            frozenDays: [threeDaysAgo],
            today: clock.now,
            weeks: 5,
            clock: clock
        )

        func state(_ date: Date) -> CalendarDayState? {
            days.first { $0.date == clock.startOfDay(for: date) }?.state
        }

        #expect(state(yesterday) == .active)
        #expect(state(dayBefore) == .active)
        #expect(state(threeDaysAgo) == .frozen)
        #expect(state(fourDaysAgo) == .active)
        #expect(state(clock.now.addingTimeInterval(-10 * 86_400)) == .beforeHistory)
    }

    @Test("A gap after the first session reads as no session, and today is not a miss yet")
    func calendarGapsAndToday() throws {
        let clock = try clock()
        let tenDaysAgo = clock.now.addingTimeInterval(-10 * 86_400)
        let fiveDaysAgo = clock.now.addingTimeInterval(-5 * 86_400)

        let days = InsightsCalculator.calendar(
            completedDays: [tenDaysAgo],
            frozenDays: [],
            today: clock.now,
            weeks: 5,
            clock: clock
        )

        let gap = days.first { $0.date == clock.startOfDay(for: fiveDaysAgo) }
        #expect(gap?.state == .missed)

        let today = days.first(where: \.isToday)
        #expect(today?.state == .future)
    }
}

@Suite("Data sensitivity")
struct DataSensitivityTests {

    @Test("Mood, energy, medication and reflections are health-adjacent")
    func healthAdjacent() {
        // A future sync engine excludes these by default and needs separate
        // consent to include them. Changing this list is a privacy decision.
        #expect(DataSensitivity.of(CheckIn()) == .healthAdjacent)
        #expect(DataSensitivity.of(MedicationLog()) == .healthAdjacent)
        #expect(DataSensitivity.of(Reflection()) == .healthAdjacent)
    }

    @Test("Tasks, sessions and progress are not")
    func standard() {
        #expect(DataSensitivity.of(FocusTask()) == .standard)
        #expect(DataSensitivity.of(FocusSession()) == .standard)
        #expect(DataSensitivity.of(UserProgress()) == .standard)
        #expect(DataSensitivity.of(AppSettings()) == .standard)
    }
}
