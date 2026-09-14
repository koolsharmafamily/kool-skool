import Foundation

/// When a widget needs to redraw on its own.
///
/// A running timer never needs a redraw — `Text(timerInterval:)` counts itself.
/// Only two moments change what a widget should say without the app telling it:
/// the planned end, when "running" becomes "time's up", and midnight, when
/// today's musts stop being today's.
enum WidgetTimeline {

    static func refreshDates(for snapshot: WidgetSnapshot?, now: Date, calendar: Calendar) -> [Date] {
        var dates: Set<Date> = [now, nextMidnight(after: now, calendar: calendar)]
        if let end = snapshot?.session?.plannedEnd, end > now {
            dates.insert(end)
        }
        return dates.sorted()
    }

    /// Calendar arithmetic rather than adding 86,400 seconds, which is wrong on
    /// the two days a year the clocks change.
    static func nextMidnight(after date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
    }
}
