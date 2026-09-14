import SwiftUI

/// Someone working alongside you.
///
/// Drawn rather than illustrated: an SF Symbol on a desk, breathing slowly. It
/// costs no assets, takes the energy-state colour for free, and — most usefully
/// — reacts at milestones with `symbolEffect` instead of a sprite sheet.
///
/// The bar for this is low on purpose. A companion that moves constantly is a
/// pet demanding attention, which is the opposite of what body doubling is for.
struct CompanionView: View {
    let coworker: Coworker
    var milestoneCount: Int = 0

    @Environment(\.ksEnergyState) private var energyState
    @Environment(\.ksReduceMotion) private var reduceMotion
    @State private var isBreathing = false
    /// Grows with the user's text size, like everything else on the screen.
    @ScaledMetric(relativeTo: .largeTitle) private var figureSize: CGFloat = 34

    private var skin: CompanionSkin {
        guard case let .companion(skinKey) = coworker.kind else { return .default }
        return CompanionSkin.named(skinKey)
    }

    var body: some View {
        VStack(spacing: KSSpacing.xs) {
            figure
            desk
            caption
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(coworker.spokenState)
    }

    private var figure: some View {
        Image(systemName: skin.symbolName)
            .font(.system(size: figureSize, weight: .semibold))
            .foregroundStyle(KSColor.accent(energyState))
            .symbolEffect(.bounce, value: milestoneCount)
            // The milestone bounce is motion like any other: under Reduce Motion
            // — the system's or the app's own — it does not play.
            .symbolEffectsRemoved(reduceMotion)
            .scaleEffect(breathScale)
            .animation(breathAnimation, value: isBreathing)
            .onAppear { isBreathing = true }
    }

    /// A surface to sit on, so the symbol reads as a scene rather than an icon.
    private var desk: some View {
        Capsule(style: .continuous)
            .fill(KSColor.surfaceRaised)
            .frame(width: 76, height: 6)
    }

    private var caption: some View {
        Text(captionText)
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textTertiary)
            .multilineTextAlignment(.center)
    }

    private var captionText: String {
        switch coworker.state {
        case .arriving: "\(coworker.displayName) is settling in."
        case .working: skin.idleLine
        case .onBreak: "Taking a break too."
        case .justFinished: "Done at the same time as you."
        }
    }

    // MARK: Motion

    private var breathScale: CGFloat {
        guard !reduceMotion else { return 1 }
        return isBreathing ? 1.05 : 0.97
    }

    private var breathAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
    }
}

#Preview("Companion") {
    HStack(spacing: KSSpacing.xl) {
        ForEach(CompanionSkin.all, id: \.key) { skin in
            CompanionView(
                coworker: Coworker(
                    id: skin.key,
                    displayName: skin.displayName,
                    kind: .companion(skinKey: skin.key),
                    state: .working
                )
            )
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KSColor.canvas)
    .ksEnergyState(.focusing)
}
