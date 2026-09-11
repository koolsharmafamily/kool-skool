import SwiftUI

/// Five taps' worth of self-report: energy, mood, "how did that go?".
///
/// Tapping the selected value again clears it. Every check-in in the app is
/// skippable up front, and this makes it skippable after the fact too.
struct KSRatingRow: View {
    let title: String
    @Binding var selection: Rating?
    var lowLabel: String = ""
    var highLabel: String = ""
    /// Inline title with no end labels, for rows that share a screen.
    var isCompact: Bool = false
    var accessibilityValueFor: (Rating) -> String = { "\($0.rawValue) of 5" }

    @Environment(\.ksEnergyState) private var state

    var body: some View {
        if isCompact {
            HStack(spacing: KSSpacing.sm) {
                titleText
                    .frame(minWidth: 64, alignment: .leading)
                pips
            }
        } else {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                titleText
                pips
                if !lowLabel.isEmpty || !highLabel.isEmpty {
                    HStack {
                        Text(lowLabel)
                        Spacer()
                        Text(highLabel)
                    }
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .ksFont(KSFont.label)
            .foregroundStyle(KSColor.textSecondary)
    }

    private var pips: some View {
        HStack(spacing: KSSpacing.xs) {
            ForEach(Rating.all, id: \.rawValue) { value in
                let isSelected = selection == value

                Button {
                    KSHaptics.shared.fire(.selection)
                    selection = isSelected ? nil : value
                } label: {
                    Text("\(value.rawValue)")
                        .ksFont(KSFont.label)
                        .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? KSColor.onAccent(state) : KSColor.textPrimary)
                .background(
                    isSelected ? KSColor.accent(state) : KSColor.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                )
                .accessibilityLabel("\(title), \(accessibilityValueFor(value))")
                .accessibilityHint(isSelected ? "Selected. Tap again to clear." : "")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

#Preview("Rating rows") {
    @Previewable @State var energy: Rating? = Rating(clamping: 3)
    @Previewable @State var mood: Rating?

    return VStack(spacing: KSSpacing.lg) {
        KSRatingRow(title: "How did that go?", selection: $energy, lowLabel: "Rough", highLabel: "Great")
        KSRatingRow(title: "Energy", selection: $energy, isCompact: true)
        KSRatingRow(title: "Mood", selection: $mood, isCompact: true)
    }
    .padding(KSSpacing.screenMargin)
    .frame(maxHeight: .infinity)
    .background(KSColor.canvas)
}
