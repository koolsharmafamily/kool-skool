import SwiftUI

/// Five weeks of days.
///
/// A day without a session is drawn in the neutral track colour, never in the
/// overrun red. The calendar is a record, not a report card, and the legend
/// says "no session" rather than "missed".
struct StreakCalendarView: View {
    let days: [CalendarDay]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var swatchSize: CGFloat = 12

    private let columns = Array(repeating: GridItem(.flexible(), spacing: KSSpacing.xs), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            LazyVGrid(columns: columns, spacing: KSSpacing.xs) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }

                ForEach(days) { day in
                    DayCell(day: day)
                }
            }

            legend
        }
    }

    /// Weekday initials starting on the user's own first day of the week, so the
    /// grid lines up with `InsightsCalculator.calendar`.
    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...] + symbols[..<first])
    }

    /// One line normally, a column at accessibility text sizes. Switched with
    /// `AnyLayout`, so the labels stay the same views and keep scaling smoothly
    /// across the change instead of being rebuilt as a second copy.
    private var legend: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: KSSpacing.xs))
            : AnyLayout(HStackLayout(spacing: KSSpacing.md))

        return layout { legendItems }
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem(colour: KSColor.accent(.focusing), label: "Session")
        legendItem(colour: KSColor.accent(.stillness), label: "Freeze")
        legendItem(colour: KSColor.track, label: "No session")
    }

    private func legendItem(colour: Color, label: String) -> some View {
        HStack(spacing: KSSpacing.xxs) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(colour)
                .frame(width: swatchSize, height: swatchSize)
            Text(label)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
                .fixedSize()
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay

    @ScaledMetric(relativeTo: .caption2) private var glyphSize: CGFloat = 11

    var body: some View {
        RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if day.state == .frozen {
                    Image(systemName: "snowflake")
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(KSColor.onDark)
                }
            }
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous)
                        .strokeBorder(KSColor.textPrimary, lineWidth: KSStroke.medium)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(spoken)
    }

    private var fill: Color {
        switch day.state {
        case .active: KSColor.accent(.focusing)
        case .frozen: KSColor.accent(.stillness)
        case .missed: KSColor.track
        case .future, .beforeHistory: KSColor.surface
        }
    }

    private var spoken: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let prefix = day.isToday ? "Today, \(date)" : date
        switch day.state {
        case .active: return "\(prefix), session completed"
        case .frozen: return "\(prefix), covered by a freeze"
        case .missed: return "\(prefix), no session"
        case .future: return day.isToday ? "\(prefix), not over yet" : "\(prefix), still to come"
        case .beforeHistory: return "\(prefix), before your first session"
        }
    }
}
