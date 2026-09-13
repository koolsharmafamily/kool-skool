import SwiftUI

/// The break, offered after a focus session.
///
/// Opt-in (it only appears if the setting is on) and skippable in one tap, as
/// the spec requires. The suggested practice is pre-chosen so that taking the
/// break is a single decision rather than a menu — swapping it is there for
/// anyone who wants it and invisible to anyone who does not.
struct BreakOfferView: View {
    let offer: BreakOffer
    let entries: [PracticeEntry]
    let tradition: Tradition
    let onStart: (Practice, TimeInterval) -> Void
    let onPlainTimer: (TimeInterval) -> Void
    let onSkip: () -> Void

    @State private var selected: Practice?

    private var available: [Practice] {
        entries.filter(\.isAvailable).map(\.practice)
    }

    private var chosen: Practice? {
        selected ?? offer.suggested
    }

    var body: some View {
        KSScreen(state: .stillness) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    Spacer(minLength: KSSpacing.lg)
                    headline

                    if let chosen {
                        practiceCard(chosen)
                        if available.count > 1 { swapRow }
                    }

                    Spacer(minLength: KSSpacing.md)
                    actions
                }
                .padding(.vertical, KSSpacing.lg)
                .frame(minHeight: 560, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Pieces

    private var headline: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("\(offer.minutes) minute\(offer.minutes == 1 ? "" : "s") off")
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            Text("The break is where the recovery happens. Take it however you like — or skip it.")
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func practiceCard(_ practice: Practice) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                KSTag(
                    text: Practice.minutesLabel(Int(StillnessModel.bestDuration(of: practice, within: offer.duration))),
                    systemImage: "timer",
                    state: .stillness
                )

                Text(practice.title)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Text(practice.subtitle)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Swapping the practice without leaving the screen. A break is short, and
    /// sending someone off to browse a library is how a break gets skipped.
    private var swapRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: KSSpacing.xs) {
                ForEach(available) { practice in
                    let isSelected = practice.id == chosen?.id

                    Button {
                        KSHaptics.shared.fire(.selection)
                        selected = practice
                    } label: {
                        Text(practice.title)
                            .ksFont(KSFont.label)
                            .padding(.horizontal, KSSpacing.sm)
                            .frame(minHeight: KSSize.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? KSColor.onAccent(.stillness) : KSColor.textPrimary)
                    .background(
                        isSelected ? KSColor.accent(.stillness) : KSColor.surfaceRaised,
                        in: Capsule(style: .continuous)
                    )
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var actions: some View {
        VStack(spacing: KSSpacing.sm) {
            if let chosen {
                KSPrimaryButton(title: "Start \(chosen.title)", systemImage: "play.fill") {
                    onStart(chosen, StillnessModel.bestDuration(of: chosen, within: offer.duration))
                }
            } else {
                KSPrimaryButton(title: "Start the break", systemImage: "play.fill") {
                    onPlainTimer(offer.duration)
                }
            }

            HStack(spacing: KSSpacing.sm) {
                if chosen != nil {
                    KSSecondaryButton(title: "Just a timer") {
                        onPlainTimer(offer.duration)
                    }
                }
                KSSecondaryButton(title: "Skip", action: onSkip)
            }

            Text(StillnessCopy.settling(tradition))
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    BreakOfferView(
        offer: BreakOffer(duration: 300, suggested: PracticeCatalogue.boxBreathing),
        entries: PracticeCatalogue.all.map { PracticeEntry(practice: $0, isAvailable: $0.requiredCompletedSits == 0, sitsRemaining: $0.requiredCompletedSits) },
        tradition: .secular,
        onStart: { _, _ in },
        onPlainTimer: { _ in },
        onSkip: {}
    )
}
