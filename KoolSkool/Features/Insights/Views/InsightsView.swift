import SwiftUI

/// What the history says.
///
/// Every sentence on this screen is an observation about the user's own data,
/// computed in `InsightsCalculator` and gated on there being enough of it. None
/// of them are advice. Where there is not enough to say something true yet, the
/// screen says how long until there will be instead of guessing.
struct InsightsView: View {
    let model: InsightsModel
    /// The answer to onboarding's "when do you work best?", if one was given.
    var preferredWorkTime: TimeOfDay?

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    totals
                    calendarCard
                    timeOfDayCard
                    if model.hasQualityData { qualityCard }
                    estimatesCard
                    historyCard

                    if let error = model.error {
                        Text(error)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.accent(.overrun))
                    }
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .task { await model.load(preferredWorkTime: preferredWorkTime) }
    }

    // MARK: Totals

    private var totals: some View {
        HStack(spacing: KSSpacing.sm) {
            stat(value: "\(model.completedCount)", label: "sessions")
            stat(value: "\(model.totalFocusMinutes)", label: "minutes")
            stat(value: model.progress.currentStreak == 0 ? "—" : "\(model.progress.currentStreak)", label: "day streak")
            stat(value: "\(model.progress.longestStreak)", label: "longest")
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: KSSpacing.xxs) {
            Text(value)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KSSpacing.sm)
        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Cards

    private var calendarCard: some View {
        section("Last five weeks") {
            StreakCalendarView(days: model.calendarDays)
        }
    }

    private var timeOfDayCard: some View {
        section("When sessions go best") {
            if model.hasEnoughHistory {
                TimeOfDayChart(buckets: model.buckets)
                if let insight = model.insight {
                    insightText(insight.sentence)
                }
                if let preference = model.preferenceSentence {
                    Text(preference)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textSecondary)
                }
            } else {
                waitingText
            }
        }
    }

    private var qualityCard: some View {
        section("How they felt") {
            FocusQualityChart(buckets: model.buckets)
            Text("From the one-tap check-in after each session. 5 is \"went well\".")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
    }

    private var estimatesCard: some View {
        section("Estimates") {
            if let summary = model.calibration.summary {
                insightText(summary)
            } else {
                Text("After \(EstimateCalibrator.minimumSamples) finished tasks with an estimate, this shows how far off they tend to run. \(model.calibration.sampleCount) so far.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var historyCard: some View {
        if !model.recentSessions.isEmpty {
            section("Recent sessions") {
                ForEach(model.recentSessions) { session in
                    SessionHistoryRow(session: session)
                }
            }
        }
    }

    // MARK: Bits

    private var waitingText: some View {
        let days = model.daysUntilPatterns
        let wait = days == 0
            ? "A few more sessions and this will show when yours tend to go best."
            : "About \(days) more day\(days == 1 ? "" : "s") and this will show when your sessions tend to go best."
        return Text(wait)
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textSecondary)
    }

    private func insightText(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.bodyEmphasis)
            .foregroundStyle(KSColor.textPrimary)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text(title)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
                content()
            }
        }
    }
}

private struct SessionHistoryRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: KSSpacing.sm) {
            Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(session.wasCompleted ? KSColor.accent(.focusing) : KSColor.textTertiary)

            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text(session.mode.displayName)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
            }

            Spacer(minLength: 0)

            Text("\(session.actualMinutes) min")
                .ksFont(KSFont.label)
                .foregroundStyle(KSColor.textSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
