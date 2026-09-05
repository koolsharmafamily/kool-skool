import SwiftUI

/// The one big action on a screen.
///
/// Every screen gets exactly one of these. If a screen seems to need two, the
/// screen is wrong.
struct KSPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.ksEnergyState) private var state
    @Environment(\.isEnabled) private var environmentEnabled

    private var enabled: Bool { isEnabled && environmentEnabled }

    var body: some View {
        Button {
            KSHaptics.shared.fire(.tap)
            action()
        } label: {
            HStack(spacing: KSSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .ksFont(KSFont.headline)
            .frame(maxWidth: .infinity, minHeight: KSSize.primaryButtonHeight)
        }
        .buttonStyle(KSPrimaryButtonStyle(state: state))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

/// Quieter action. Never competes with the primary.
struct KSSecondaryButton: View {
    let title: String
    var systemImage: String?
    var role: ButtonRole?
    let action: () -> Void

    @Environment(\.ksEnergyState) private var state

    var body: some View {
        Button(role: role) {
            KSHaptics.shared.fire(.tap)
            action()
        } label: {
            HStack(spacing: KSSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .ksFont(KSFont.label)
            .frame(maxWidth: .infinity, minHeight: KSSize.secondaryButtonHeight)
        }
        .buttonStyle(KSSecondaryButtonStyle(state: state))
    }
}

struct KSPrimaryButtonStyle: ButtonStyle {
    let state: KSEnergyState
    @Environment(\.ksReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(KSColor.onAccent(state))
            .padding(.horizontal, KSSpacing.lg)
            .background(KSColor.accent(state), in: RoundedRectangle(cornerRadius: KSRadius.lg, style: .continuous))
            .scaleEffect(scale(pressed: configuration.isPressed))
            .animation(KSAnimation.resolved(KSAnimation.snappy, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    /// Under Reduce Motion the press feedback becomes opacity rather than
    /// scale, so there is still a response without any movement.
    private func scale(pressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return pressed ? 0.96 : 1
    }
}

struct KSSecondaryButtonStyle: ButtonStyle {
    let state: KSEnergyState
    @Environment(\.ksReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(KSColor.textPrimary)
            .padding(.horizontal, KSSpacing.lg)
            .background(KSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                    .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(KSAnimation.resolved(KSAnimation.snappy, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

#Preview("Buttons") {
    VStack(spacing: KSSpacing.md) {
        ForEach(KSEnergyState.allCases) { state in
            KSPrimaryButton(title: state.accessibilityName, systemImage: "play.fill") {}
                .ksEnergyState(state)
        }
        KSSecondaryButton(title: "End early") {}
    }
    .padding(KSSpacing.screenMargin)
    .frame(maxHeight: .infinity)
    .background(KSColor.canvas)
}
