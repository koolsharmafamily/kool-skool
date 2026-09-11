import Charts
import SwiftUI

/// When sessions tend to go best.
///
/// Bars with too few sessions behind them are drawn faded rather than hidden.
/// Hiding them would make the chart look more certain than it is; drawing them
/// at full strength would make two sessions look like a trend.
struct TimeOfDayChart: View {
    let buckets: [TimeOfDayBucket]

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(
                x: .value("Time of day", bucket.block.displayName),
                y: .value("Completed", bucket.completionRate * 100)
            )
            .foregroundStyle(KSColor.accent(.focusing))
            .opacity(isConfident(bucket) ? 1 : 0.3)
            .cornerRadius(KSRadius.sm)
            .accessibilityLabel(bucket.block.displayName)
            .accessibilityValue(spoken(bucket))
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) {
                        Text("\(percent)%")
                            .ksFont(KSFont.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(label)
                            .ksFont(KSFont.caption)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private func isConfident(_ bucket: TimeOfDayBucket) -> Bool {
        bucket.sessions >= InsightsCalculator.minimumSessionsPerBlock
    }

    private func spoken(_ bucket: TimeOfDayBucket) -> String {
        guard bucket.sessions > 0 else { return "No sessions" }
        let percent = Int((bucket.completionRate * 100).rounded())
        let sessions = bucket.sessions == 1 ? "1 session" : "\(bucket.sessions) sessions"
        let caveat = isConfident(bucket) ? "" : ", too few to go on"
        return "\(percent) percent completed, \(sessions)\(caveat)"
    }
}

/// The optional second view: how sessions *felt*, from the one-tap check-in.
/// Only shown once there is something in it.
struct FocusQualityChart: View {
    let buckets: [TimeOfDayBucket]

    private var rated: [TimeOfDayBucket] {
        buckets.filter { $0.averageFocusQuality != nil }
    }

    var body: some View {
        Chart(rated) { bucket in
            if let quality = bucket.averageFocusQuality {
                PointMark(
                    x: .value("Time of day", bucket.block.displayName),
                    y: .value("How it went", quality)
                )
                .foregroundStyle(KSColor.accent(.stillness))
                .symbolSize(140)
                .accessibilityLabel(bucket.block.displayName)
                .accessibilityValue("Average \(String(format: "%.1f", quality)) out of 5, from \(bucket.qualityCount) check-ins")
            }
        }
        .chartYScale(domain: 1...5)
        .chartYAxis {
            AxisMarks(values: [1, 3, 5]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rating = value.as(Int.self) {
                        Text("\(rating)")
                            .ksFont(KSFont.caption)
                    }
                }
            }
        }
        .frame(height: 140)
    }
}
