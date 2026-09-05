import Foundation

/// All time-dependent logic — the focus timer, streaks, freeze accrual, the
/// daily reset of the rule of three — reads the clock through this, never
/// through `Date()` directly.
///
/// This is the single most important testability seam in the app. Timer and
/// streak correctness across backgrounding, timezone changes, and DST can only
/// be tested if the clock can be moved by hand.
protocol DateProvider: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
    var timeZone: TimeZone { get }
}

extension DateProvider {
    /// Midnight in the user's current timezone. Used as the identity of a "day"
    /// for streaks, musts, and reflections.
    func startOfDay(for date: Date) -> Date {
        var cal = calendar
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }

    var today: Date { startOfDay(for: now) }

    /// Whole calendar days between two instants, ignoring time of day.
    /// Uses `startOfDay` on both sides so DST transitions cannot produce a
    /// fractional day and silently break a streak.
    func dayDifference(from earlier: Date, to later: Date) -> Int {
        var cal = calendar
        cal.timeZone = timeZone
        let a = cal.startOfDay(for: earlier)
        let b = cal.startOfDay(for: later)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool {
        dayDifference(from: a, to: b) == 0
    }
}

struct SystemDateProvider: DateProvider {
    var now: Date { Date() }
    var calendar: Calendar { Calendar.current }
    var timeZone: TimeZone { TimeZone.current }

    init() {}
}

/// Test/preview clock. `now` is mutable so a test can advance time.
final class MutableDateProvider: DateProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    private let _calendar: Calendar
    private let _timeZone: TimeZone

    init(now: Date, calendar: Calendar = Calendar(identifier: .gregorian), timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .current) {
        self._now = now
        var cal = calendar
        cal.timeZone = timeZone
        self._calendar = cal
        self._timeZone = timeZone
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _now
    }

    var calendar: Calendar { _calendar }
    var timeZone: TimeZone { _timeZone }

    func set(_ date: Date) {
        lock.lock()
        _now = date
        lock.unlock()
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        _now = _now.addingTimeInterval(interval)
        lock.unlock()
    }

    func advanceDays(_ days: Int) {
        advance(by: TimeInterval(days) * 86_400)
    }
}
