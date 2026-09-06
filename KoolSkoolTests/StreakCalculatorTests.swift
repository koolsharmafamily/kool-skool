import Foundation
import Testing
@testable import KoolSkool

/// Streak logic is the second-highest-risk area in the app after the timer.
/// Every case here walks a hand-built history against a fixed clock.
@Suite("Streaks with mercy")
struct StreakCalculatorTests {

    // MARK: Fixtures

    private func clock(timeZone identifier: String = "UTC", year: Int = 2026, month: Int = 6, day: Int = 15) throws -> MutableDateProvider {
        let zone = try #require(TimeZone(identifier: identifier))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10)))
        return MutableDateProvider(now: now, calendar: calendar, timeZone: zone)
    }

    /// Days ago, as an instant partway through that day.
    private func daysAgo(_ offsets: [Int], from clock: MutableDateProvider) -> [Date] {
        offsets.map { clock.now.addingTimeInterval(-Double($0) * 86_400) }
    }

    private func evaluate(_ offsets: [Int], clock: MutableDateProvider, previousLongest: Int = 0) -> StreakOutcome {
        StreakCalculator.evaluate(
            completedDays: daysAgo(offsets, from: clock),
            today: clock.now,
            previousLongest: previousLongest,
            clock: clock
        )
    }

    // MARK: The basics

    @Test("No history is a fresh start, not a broken streak")
    func emptyHistory() throws {
        let clock = try clock()
        let outcome = evaluate([], clock: clock)

        #expect(outcome.current == 0)
        #expect(outcome.lastActiveDay == nil)
        #expect(outcome.freezesRemaining == UserProgress.freezesPerMonth)
    }

    @Test("One session today is day one")
    func singleDay() throws {
        let clock = try clock()
        #expect(evaluate([0], clock: clock).current == 1)
    }

    @Test("Consecutive days accumulate")
    func consecutiveDays() throws {
        let clock = try clock()
        #expect(evaluate([0, 1, 2, 3, 4], clock: clock).current == 5)
    }

    @Test("Several sessions on one day still count as one day")
    func duplicateDaysCollapse() throws {
        let clock = try clock()
        let sameDay = [clock.now, clock.now.addingTimeInterval(-3600), clock.now.addingTimeInterval(-7200)]
        let outcome = StreakCalculator.evaluate(
            completedDays: sameDay,
            today: clock.now,
            previousLongest: 0,
            clock: clock
        )
        #expect(outcome.current == 1)
    }

    @Test("Order of the history does not matter")
    func unorderedHistory() throws {
        let clock = try clock()
        #expect(evaluate([3, 0, 4, 1, 2], clock: clock).current == 5)
    }

    // MARK: Today is not over yet

    @Test("A streak survives until the day it is missed actually ends")
    func todayIsNotHeldAgainstYou() throws {
        let clock = try clock()
        // Worked yesterday and the day before. Nothing today, yet.
        let outcome = evaluate([1, 2], clock: clock)
        #expect(outcome.current == 2)
        #expect(outcome.freezesUsedThisMonth == 0)
    }

    @Test("Working today extends yesterday's streak")
    func todayExtends() throws {
        let clock = try clock()
        #expect(evaluate([0, 1, 2], clock: clock).current == 3)
    }

    // MARK: Freezes

    @Test("A single missed day is covered automatically")
    func oneMissedDayIsFrozen() throws {
        let clock = try clock()
        // Worked today and three days ago, missing days 1 and 2.
        let outcome = evaluate([0, 2, 3], clock: clock)

        #expect(outcome.current == 3)
        #expect(outcome.frozenDays.count == 1)
        #expect(outcome.freezesUsedThisMonth == 1)
        #expect(outcome.freezesRemaining == 1)
    }

    @Test("Two missed days in a month are both covered")
    func twoMissedDaysAreFrozen() throws {
        let clock = try clock()
        // Active on 0, 2, 4. Missing 1 and 3.
        let outcome = evaluate([0, 2, 4], clock: clock)

        #expect(outcome.current == 3)
        #expect(outcome.freezesUsedThisMonth == 2)
        #expect(outcome.freezesRemaining == 0)
    }

    @Test("A third missed day in the same month breaks the streak")
    func thirdMissedDayBreaksIt() throws {
        let clock = try clock()
        // Active on 0, 2, 4, 6. Three gaps, only two freezes.
        let outcome = evaluate([0, 2, 4, 6], clock: clock)

        // Today, day 2, day 4 — then the third gap stops the walk.
        #expect(outcome.current == 3)
        #expect(outcome.freezesUsedThisMonth == 2)
    }

    @Test("Freezes are applied retroactively without being asked for")
    func freezesAreRetroactive() throws {
        let clock = try clock()
        // Nothing today. Last session was two days ago, so yesterday is a gap.
        let outcome = evaluate([2, 3, 4], clock: clock)

        #expect(outcome.current == 3)
        #expect(outcome.frozenDays.count == 1)
    }

    @Test("Freezes spent on a streak that broke anyway are handed back")
    func wastedFreezesAreReturned() throws {
        let clock = try clock()
        // Last session was five days ago. Two freezes cannot bridge four gaps,
        // so the streak is gone and nothing should have been spent.
        let outcome = evaluate([5], clock: clock)

        #expect(outcome.current == 0)
        #expect(outcome.frozenDays.isEmpty)
        #expect(outcome.freezesUsedThisMonth == 0)
        #expect(outcome.freezesRemaining == UserProgress.freezesPerMonth)
    }

    @Test("Each calendar month gets its own two freezes")
    func freezeBudgetIsPerMonth() throws {
        // 2 July 2026. A gap on 1 July and gaps in late June draw on separate
        // budgets.
        let clock = try clock(year: 2026, month: 7, day: 2)
        let outcome = evaluate([0, 2, 4], clock: clock)

        // Day 0 is 2 July, day 2 is 30 June, day 4 is 28 June.
        // Gaps: 1 July (July budget) and 29 June (June budget).
        #expect(outcome.current == 3)
        #expect(outcome.freezesUsedThisMonth == 1)
        #expect(outcome.freezesRemaining == 1)
        #expect(outcome.frozenDays.count == 2)
    }

    // MARK: Records

    @Test("The longest streak is never lost")
    func longestIsSticky() throws {
        let clock = try clock()
        let outcome = evaluate([0], clock: clock, previousLongest: 47)

        #expect(outcome.current == 1)
        #expect(outcome.longest == 47)
    }

    @Test("A new record replaces the old one")
    func newRecord() throws {
        let clock = try clock()
        let outcome = evaluate([0, 1, 2, 3, 4, 5], clock: clock, previousLongest: 4)
        #expect(outcome.longest == 6)
    }

    @Test("The last active day is reported for the calendar")
    func lastActiveDay() throws {
        let clock = try clock()
        let outcome = evaluate([1, 2], clock: clock)
        let expected = clock.startOfDay(for: clock.now.addingTimeInterval(-86_400))
        #expect(outcome.lastActiveDay == expected)
    }

    // MARK: Idempotence and clocks

    @Test("Recomputing the same history twice gives the same answer")
    func isIdempotent() throws {
        let clock = try clock()
        let history = daysAgo([0, 1, 3, 4], from: clock)

        let first = StreakCalculator.evaluate(completedDays: history, today: clock.now, previousLongest: 0, clock: clock)
        let second = StreakCalculator.evaluate(completedDays: history, today: clock.now, previousLongest: 0, clock: clock)
        #expect(first == second)
    }

    @Test("A streak spanning spring forward is not shortened")
    func springForwardDoesNotBreakAStreak() throws {
        // 10 March 2026 in New York, two days after the clocks jumped forward.
        let clock = try clock(timeZone: "America/New_York", year: 2026, month: 3, day: 10)
        let outcome = evaluate([0, 1, 2, 3, 4], clock: clock)

        // 8 March was 23 hours long. Naive division by 86,400 would lose a day.
        #expect(outcome.current == 5)
    }

    @Test("A streak spanning fall back is not lengthened")
    func fallBackDoesNotInflateAStreak() throws {
        // 3 November 2026 in New York, two days after the clocks went back.
        let clock = try clock(timeZone: "America/New_York", year: 2026, month: 11, day: 3)
        let outcome = evaluate([0, 1, 2, 3], clock: clock)

        // 1 November was 25 hours long.
        #expect(outcome.current == 4)
    }

    @Test("A very long history does not run away")
    func longHistoryIsBounded() throws {
        let clock = try clock()
        let outcome = evaluate(Array(0..<800), clock: clock)

        #expect(outcome.current <= StreakCalculator.maximumLookbackDays + 1)
        #expect(outcome.current > 700)
    }

    @Test("Folding an outcome into progress keeps the record")
    func applyingToProgress() throws {
        let clock = try clock()
        var progress = UserProgress()
        progress.longestStreak = 12

        let updated = progress.applying(evaluate([0, 1, 2], clock: clock))

        #expect(updated.currentStreak == 3)
        #expect(updated.longestStreak == 12)
        #expect(updated.freezesRemaining == UserProgress.freezesPerMonth)
    }

    @Test("A broken streak reads as a fresh start, never as a loss")
    func copyIsNeverShaming() {
        var progress = UserProgress()
        progress.currentStreak = 0
        #expect(progress.streakLabel == "Fresh start")

        progress.currentStreak = 47
        #expect(progress.streakLabel == "Day 47")
    }
}
