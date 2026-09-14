import SwiftUI

/// After a sit. One line, the count, and a way out.
///
/// No confetti, no coins, no level bar. The focus layer celebrates loudly on
/// purpose; doing the same here would undo the thing the sit just did.
struct SitClosingView: View {
    let sit: StillnessSession
    let practice: Practice?
    let calmStreak: Int
    let onDone: () -> Void

    private var minutes: Int { max(1, Int((Double(sit.durationSeconds) / 60).rounded())) }

    var body: some View {
        KSScreen(state: .stillness) {
            VStack(alignment: .leading, spacing: KSSpacing.md) {
                // Scrolls only if the largest text sizes need it; Done stays
                // pinned below either way.
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        VStack(alignment: .leading, spacing: KSSpacing.xs) {
                            Text(headline)
                                .ksFont(KSFont.title)
                                .foregroundStyle(KSColor.textPrimary)

                            Text(detail)
                                .ksFont(KSFont.body)
                                .foregroundStyle(KSColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)

                        closingCard

                        if calmStreak > 0 {
                            KSTag(
                                text: StillnessCopy.calmStreakLabel(calmStreak),
                                systemImage: "moon.stars",
                                state: .stillness
                            )
                        }
                    }
                    .padding(.top, KSSpacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)

                KSPrimaryButton(title: "Done", systemImage: "checkmark", action: onDone)
            }
            .padding(.vertical, KSSpacing.lg)
        }
    }

    /// The app's own closing words, in the register the user chose.
    ///
    /// When a practice carries a real `attribution` — verbatim public-domain or
    /// licensed text — it is shown here instead, credited on the line below it.
    /// Nothing bundled in v1 sets that field.
    private var closingCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                if let practice, let attribution = practice.attribution, !practice.scriptText.isEmpty {
                    Text(practice.scriptText)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)

                    Text(attribution)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                } else {
                    Text(StillnessCopy.closing(sit.tradition))
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }
            }
        }
    }

    private var headline: String {
        sit.completed ? "That's the sit." : "Stopped."
    }

    private var detail: String {
        let length = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        guard sit.completed else {
            return "\(length). Short counts. It still happened."
        }
        return "\(length) of \(StillnessCopy.sitNoun(sit.tradition).lowercased())."
    }
}

#Preview {
    SitClosingView(
        sit: {
            var sit = StillnessSession()
            sit.practiceType = .boxBreathing
            sit.durationSeconds = 180
            sit.completed = true
            sit.tradition = .zen
            return sit
        }(),
        practice: PracticeCatalogue.boxBreathing,
        calmStreak: 4,
        onDone: {}
    )
}
