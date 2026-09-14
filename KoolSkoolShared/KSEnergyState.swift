import Foundation

/// The app has one saturated accent per energy state, and every screen declares
/// which state it is in. Colour is doing real work here: it is the fastest
/// signal of "what is happening right now" that does not require reading.
enum KSEnergyState: String, CaseIterable, Sendable, Identifiable {
    /// Before a session. Electric blue.
    case ready
    /// Mid-session. Acid green.
    case focusing
    /// Break. Warm amber.
    case breakTime
    /// Past the planned end. Hot coral.
    case overrun
    /// The stillness layer. Deep indigo — and the one place the design system
    /// deliberately steps down: slower curves, lower contrast, less motion.
    case stillness

    var id: String { rawValue }

    /// Dark mode is the primary design, so the dark value is the real colour and
    /// the light value is its readable counterpart.
    var accentDarkHex: UInt32 {
        switch self {
        case .ready: 0x4D8BFF
        case .focusing: 0xB8FF2E
        case .breakTime: 0xFFB020
        case .overrun: 0xFF5C6B
        case .stillness: 0x7C6BFF
        }
    }

    /// Deepened in Milestone 11 so accent text reads at 4.5:1 or better on light
    /// surfaces, and light text reads on an accent fill. Green, amber and coral
    /// were the three below the line.
    var accentLightHex: UInt32 {
        switch self {
        case .ready: 0x1F4FE0
        case .focusing: 0x3D6E00
        case .breakTime: 0x8A5200
        case .overrun: 0xB0182C
        case .stillness: 0x4238C7
        }
    }

    func accentHex(dark: Bool) -> UInt32 {
        dark ? accentDarkHex : accentLightHex
    }

    /// Stillness moves slowly and quietly. Everything else is allowed to snap.
    var isSubdued: Bool { self == .stillness }

    var accessibilityName: String {
        switch self {
        case .ready: "Ready"
        case .focusing: "Focusing"
        case .breakTime: "On a break"
        case .overrun: "Running over"
        case .stillness: "Stillness"
        }
    }
}
