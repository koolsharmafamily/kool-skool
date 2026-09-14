import Foundation
import Testing
@testable import KoolSkool

/// WCAG contrast, computed from the palette's own hex values.
///
/// The UI accessibility audit only sees the appearance a simulator is in and
/// the screens it happens to visit. These check every text-and-background
/// pairing the design system relies on, in both modes, on every run — so a
/// palette tweak that quietly drops a pairing below the line fails here.
@Suite("Colour contrast")
struct ContrastTests {

    /// The bar for normal-size text. The app's smallest text is 15pt, which is
    /// not large enough to use WCAG's lower 3:1 bar, so nothing relies on it.
    static let minimum = 4.5

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let first = luminance(a)
        let second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func rounded(_ ratio: Double) -> String {
        String(format: "%.2f", ratio)
    }

    @Test("The arithmetic matches the WCAG reference points")
    func arithmetic() {
        #expect(abs(Self.contrast(0x000000, 0xFFFFFF) - 21) < 0.01)
        #expect(Self.contrast(0x777777, 0x777777) == 1)
    }

    @Test("Every text colour reads on every surface, in both modes")
    func textOnSurfaces() {
        let texts: [(String, KSColor.HexPair)] = [
            ("primary", KSColor.Palette.textPrimary),
            ("secondary", KSColor.Palette.textSecondary),
            ("tertiary", KSColor.Palette.textTertiary),
        ]
        let surfaces: [(String, KSColor.HexPair)] = [
            ("canvas", KSColor.Palette.canvas),
            ("surface", KSColor.Palette.surface),
            ("raised surface", KSColor.Palette.surfaceRaised),
        ]

        for (textName, text) in texts {
            for (surfaceName, surface) in surfaces {
                let light = Self.contrast(text.light, surface.light)
                let dark = Self.contrast(text.dark, surface.dark)
                #expect(light >= Self.minimum, "\(textName) text on \(surfaceName), light mode: \(Self.rounded(light)):1")
                #expect(dark >= Self.minimum, "\(textName) text on \(surfaceName), dark mode: \(Self.rounded(dark)):1")
            }
        }
    }

    /// Accent-coloured text sits on the canvas and on cards. Not on raised
    /// surfaces, which carry chips and buttons, so that pairing isn't claimed.
    @Test("Accent text reads on the canvas and on cards, in both modes", arguments: KSEnergyState.allCases)
    func accentText(state: KSEnergyState) {
        let surfaces: [(String, KSColor.HexPair)] = [
            ("canvas", KSColor.Palette.canvas),
            ("surface", KSColor.Palette.surface),
        ]

        for (surfaceName, surface) in surfaces {
            let light = Self.contrast(state.accentLightHex, surface.light)
            let dark = Self.contrast(state.accentDarkHex, surface.dark)
            #expect(light >= Self.minimum, "\(state) text on \(surfaceName), light mode: \(Self.rounded(light)):1")
            #expect(dark >= Self.minimum, "\(state) text on \(surfaceName), dark mode: \(Self.rounded(dark)):1")
        }
    }

    @Test("Text on an accent fill reads, in both modes", arguments: KSEnergyState.allCases)
    func textOnAccentFill(state: KSEnergyState) {
        let light = Self.contrast(KSColor.onAccentHex(dark: false), state.accentLightHex)
        let dark = Self.contrast(KSColor.onAccentHex(dark: true), state.accentDarkHex)
        #expect(light >= Self.minimum, "text on a \(state) fill, light mode: \(Self.rounded(light)):1")
        #expect(dark >= Self.minimum, "text on a \(state) fill, dark mode: \(Self.rounded(dark)):1")
    }

    @Test("The Lock Screen timer's accents read on its black background")
    func liveActivityAccents() {
        // The Live Activity and the Dynamic Island draw on black whatever the
        // system appearance, so they use the dark-mode accents.
        for state in [KSEnergyState.focusing, .overrun] {
            let ratio = Self.contrast(state.accentDarkHex, 0x0A0A0F)
            #expect(ratio >= Self.minimum, "\(state) on the Lock Screen: \(Self.rounded(ratio)):1")
        }
    }
}
