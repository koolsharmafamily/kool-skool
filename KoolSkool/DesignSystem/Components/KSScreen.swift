import SwiftUI

/// Standard screen chrome: the canvas colour, the screen margin, and the energy
/// state pushed into the environment so everything inside colours itself.
struct KSScreen<Content: View>: View {
    var state: KSEnergyState = .ready
    var horizontalMargin: CGFloat = KSSpacing.screenMargin
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            KSColor.canvas
                .ignoresSafeArea()

            content
                .padding(.horizontal, horizontalMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ksEnergyState(state)
        .tint(KSColor.accent(state))
    }
}

/// A raised surface. Used for anything that groups content.
struct KSCard<Content: View>: View {
    var padding: CGFloat = KSSpacing.md
    var cornerRadius: CGFloat = KSRadius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KSColor.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
            )
    }
}

/// A small state-coloured chip. Streaks, levels, mode names.
struct KSTag: View {
    let text: String
    var systemImage: String?
    var state: KSEnergyState?

    @Environment(\.ksEnergyState) private var environmentState

    private var resolvedState: KSEnergyState { state ?? environmentState }

    var body: some View {
        HStack(spacing: KSSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .ksFont(KSFont.label)
        .foregroundStyle(KSColor.accent(resolvedState))
        .padding(.horizontal, KSSpacing.sm)
        .padding(.vertical, KSSpacing.xxs)
        .background(
            KSColor.accentWash(resolvedState),
            in: Capsule(style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("Screen") {
    KSScreen(state: .focusing) {
        VStack(alignment: .leading, spacing: KSSpacing.md) {
            Text("Kool Skool")
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    KSTag(text: "Day 4", systemImage: "flame.fill")
                    Text("Finish the chapter summary")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)
                    Text("Open the doc and read the first heading")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }

            KSPrimaryButton(title: "Just start", systemImage: "bolt.fill") {}
        }
        .padding(.top, KSSpacing.lg)
    }
}
