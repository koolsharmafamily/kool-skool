import SwiftUI
import UIKit

/// The whole palette. No feature code contains a hex value.
///
/// Colours are built as dynamic `UIColor`s rather than asset catalogue entries
/// so they can be blended programmatically — the ambient colour shift during a
/// session interpolates between two energy states and needs component access.
enum KSColor {

    /// Every non-accent colour as light and dark hex values. Kept as numbers as
    /// well as `Color`s so `ContrastTests` can check the arithmetic.
    enum Palette {
        static let canvas = HexPair(light: 0xF7F7FA, dark: 0x0A0A0F)
        static let surface = HexPair(light: 0xFFFFFF, dark: 0x14141C)
        static let surfaceRaised = HexPair(light: 0xEFEFF4, dark: 0x1E1E29)
        static let hairline = HexPair(light: 0xD8D8E0, dark: 0x2A2A38)
        static let track = HexPair(light: 0xE2E2EA, dark: 0x22222E)

        static let textPrimary = HexPair(light: 0x0B0B10, dark: 0xF5F5F7)
        static let textSecondary = HexPair(light: 0x55555F, dark: 0xA6A6B4)
        /// Deepened in Milestone 11. The old light value, 0x76767F, measured
        /// about 4.15:1 on the canvas — under the 4.5:1 that 15pt text needs.
        static let textTertiary = HexPair(light: 0x66666F, dark: 0x8A8A99)

        static let onLight: UInt32 = 0x0B0B10
        static let onDark: UInt32 = 0xF5F5F7
    }

    struct HexPair: Sendable, Equatable {
        let light: UInt32
        let dark: UInt32
    }

    // MARK: Surfaces

    static let canvas = dynamic(Palette.canvas)
    static let surface = dynamic(Palette.surface)
    static let surfaceRaised = dynamic(Palette.surfaceRaised)
    static let hairline = dynamic(Palette.hairline)

    /// The unfilled remainder of the depleting disc.
    static let track = dynamic(Palette.track)

    // MARK: Text

    static let textPrimary = dynamic(Palette.textPrimary)
    static let textSecondary = dynamic(Palette.textSecondary)
    /// The quietest text. Still at least 4.5:1 on every surface, in both modes.
    static let textTertiary = dynamic(Palette.textTertiary)

    static let onLight = Color(uiColor: UIColor(hex: Palette.onLight))
    static let onDark = Color(uiColor: UIColor(hex: Palette.onDark))

    // MARK: Energy accents

    static func accent(_ state: KSEnergyState) -> Color {
        dynamic(light: state.accentLightHex, dark: state.accentDarkHex)
    }

    /// A low-alpha wash of an accent, for cards and backgrounds that need to
    /// carry the state without shouting.
    static func accentWash(_ state: KSEnergyState, opacity: Double = 0.14) -> Color {
        accent(state).opacity(opacity)
    }

    /// The text colour on an accent fill.
    ///
    /// Decided by the appearance, not the accent. Every light-mode accent is
    /// deep enough for light text and every dark-mode accent bright enough for
    /// dark text, each pairing at least 4.5:1 — `ContrastTests` holds that. The
    /// old rule put light text on dark mode's blue and coral, about 3:1. The
    /// state stays a parameter so an accent that ever breaks the rule has
    /// somewhere to be handled.
    static func onAccent(_ state: KSEnergyState) -> Color {
        dynamic(light: onAccentHex(dark: false), dark: onAccentHex(dark: true))
    }

    static func onAccentHex(dark: Bool) -> UInt32 {
        dark ? Palette.onLight : Palette.onDark
    }

    /// Continuous blend between two energy states.
    ///
    /// This is what drives the ambient colour shift: as a session runs down, the
    /// background migrates from `focusing` toward `overrun`, giving peripheral
    /// awareness of time passing at zero cognitive cost.
    static func blend(from: KSEnergyState, to: KSEnergyState, progress: Double) -> Color {
        let fraction = min(max(progress, 0), 1)
        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let start = UIColor(hex: from.accentHex(dark: isDark))
            let end = UIColor(hex: to.accentHex(dark: isDark))
            return start.blended(toward: end, fraction: fraction)
        })
    }

    // MARK: Construction

    static func dynamic(_ pair: HexPair) -> Color {
        dynamic(light: pair.light, dark: pair.dark)
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// `UIColor(hex:)` lives in `KoolSkoolShared/SharedColor.swift`, so the widget
// extension draws from the same palette without copying hex values.
extension UIColor {
    /// Linear interpolation in sRGB. Good enough for an ambient wash, and it
    /// avoids pulling in a colour-space dependency.
    func blended(toward other: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        guard getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        else {
            return fraction < 0.5 ? self : other
        }

        let t = min(max(fraction, 0), 1)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
