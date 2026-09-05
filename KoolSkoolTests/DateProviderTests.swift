import Foundation
import Testing
@testable import KoolSkool

/// Streaks, musts, and reflections are all keyed on "what day is it", so the
/// day maths has to survive DST and timezone changes. These are the cases that
/// silently break a streak if they are got wrong.
@Suite("Day arithmetic")
struct DateProviderTests {

    private func newYork() throws -> TimeZone {
        try #require(TimeZone(identifier: "America/New_York"))
    }

    private func makeDate(
        _ year: Int, _ month: Int, _ day: Int,
        hour: Int = 12, minute: Int = 0,
        timeZone: TimeZone
    ) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        return try #require(calendar.date(from: components))
    }

    private func provider(timeZone: TimeZone, now: Date) -> MutableDateProvider {
        MutableDateProvider(now: now, calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
    }

    @Test("Spring forward still counts as one day")
    func springForwardIsOneDay() throws {
        // 8 March 2026 is 23 hours long in New York.
        let tz = try newYork()
        let before = try makeDate(2026, 3, 7, timeZone: tz)
        let after = try makeDate(2026, 3, 8, timeZone: tz)
        let clock = provider(timeZone: tz, now: after)

        #expect(clock.dayDifference(from: before, to: after) == 1)
    }

    @Test("Spanning the spring-forward boundary counts as two days")
    func springForwardSpansTwoDays() throws {
        let tz = try newYork()
        let before = try makeDate(2026, 3, 7, timeZone: tz)
        let after = try makeDate(2026, 3, 9, timeZone: tz)
        let clock = provider(timeZone: tz, now: after)

        // 47 hours of wall time, but unambiguously two calendar days. A naive
        // `interval / 86400` would give 1 here and break a streak.
        #expect(clock.dayDifference(from: before, to: after) == 2)
    }

    @Test("Fall back still counts as one day")
    func fallBackIsOneDay() throws {
        // 1 November 2026 is 25 hours long in New York.
        let tz = try newYork()
        let before = try makeDate(2026, 11, 1, timeZone: tz)
        let after = try makeDate(2026, 11, 2, timeZone: tz)
        let clock = provider(timeZone: tz, now: after)

        #expect(clock.dayDifference(from: before, to: after) == 1)
    }

    @Test("Times late and early in the same day are the same day")
    func sameDayAcrossHours() throws {
        let tz = try newYork()
        let earlyMorning = try makeDate(2026, 6, 15, hour: 0, minute: 5, timeZone: tz)
        let lateNight = try makeDate(2026, 6, 15, hour: 23, minute: 55, timeZone: tz)
        let clock = provider(timeZone: tz, now: lateNight)

        #expect(clock.isSameDay(earlyMorning, lateNight))
        #expect(clock.dayDifference(from: earlyMorning, to: lateNight) == 0)
    }

    @Test("Five minutes past midnight is a new day")
    func midnightRollsOver() throws {
        let tz = try newYork()
        let lateNight = try makeDate(2026, 6, 15, hour: 23, minute: 55, timeZone: tz)
        let justAfter = try makeDate(2026, 6, 16, hour: 0, minute: 5, timeZone: tz)
        let clock = provider(timeZone: tz, now: justAfter)

        #expect(clock.isSameDay(lateNight, justAfter) == false)
        #expect(clock.dayDifference(from: lateNight, to: justAfter) == 1)
    }

    @Test("startOfDay lands on local midnight, not UTC midnight")
    func startOfDayIsLocal() throws {
        let tz = try newYork()
        let afternoon = try makeDate(2026, 6, 15, hour: 15, timeZone: tz)
        let clock = provider(timeZone: tz, now: afternoon)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = calendar.dateComponents([.hour, .minute, .second], from: clock.startOfDay(for: afternoon))

        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("The same instant can fall on different days in different timezones")
    func timezoneChangesTheDay() throws {
        // 15 June 2026, 02:00 UTC is still 14 June in New York. A user who flies
        // west must not lose a day off their streak, which is why every day
        // comparison goes through one clock rather than raw `Date` maths.
        let utc = try #require(TimeZone(identifier: "UTC"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let instant = try makeDate(2026, 6, 15, hour: 2, timeZone: utc)

        let utcClock = provider(timeZone: utc, now: instant)
        let tokyoClock = provider(timeZone: tokyo, now: instant)

        #expect(utcClock.startOfDay(for: instant) != tokyoClock.startOfDay(for: instant))
    }

    @Test("The mutable clock advances predictably")
    func mutableClockAdvances() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let start = try makeDate(2026, 6, 15, hour: 9, timeZone: utc)
        let clock = provider(timeZone: utc, now: start)

        clock.advance(by: 3600)
        #expect(clock.now == start.addingTimeInterval(3600))

        clock.advanceDays(3)
        #expect(clock.dayDifference(from: start, to: clock.now) == 3)
    }
}
