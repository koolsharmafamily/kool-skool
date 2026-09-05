import Foundation

/// Whether a check-in was taken before or after a session.
enum CheckInPhase: String, Codable, CaseIterable, Sendable {
    case pre
    case post
}

/// A 1–5 self-report. Used for energy, mood, and resistance.
///
/// Modelled as a type rather than a bare `Int` so the clamping happens once and
/// the scale labels live next to the values.
struct Rating: Sendable, Hashable, Codable, RawRepresentable {
    static let range: ClosedRange<Int> = 1...5

    let rawValue: Int

    init?(rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Clamps instead of failing. Use when the value came from persistence.
    init(clamping value: Int) {
        rawValue = min(max(value, Self.range.lowerBound), Self.range.upperBound)
    }

    static let veryLow = Rating(clamping: 1)
    static let low = Rating(clamping: 2)
    static let neutral = Rating(clamping: 3)
    static let high = Rating(clamping: 4)
    static let veryHigh = Rating(clamping: 5)

    static let all: [Rating] = range.map { Rating(clamping: $0) }
}

/// The stillness practices that ship in v1. Raw values are persisted.
enum PracticeType: String, Codable, CaseIterable, Sendable, Identifiable {
    case boxBreathing
    case physiologicalSigh
    case bodyScan
    case walking
    case soundAnchor
    case movement
    case openAwareness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .boxBreathing: "Box Breathing"
        case .physiologicalSigh: "Physiological Sigh"
        case .bodyScan: "Body Scan"
        case .walking: "Walking"
        case .soundAnchor: "Sound Anchor"
        case .movement: "Movement"
        case .openAwareness: "Open Awareness"
        }
    }

    /// Whether this practice drives the breath pacer animation.
    var usesBreathPacer: Bool {
        switch self {
        case .boxBreathing, .physiologicalSigh: true
        case .bodyScan, .walking, .soundAnchor, .movement, .openAwareness: false
        }
    }

    /// Level the user must reach before this appears in the library.
    /// Open awareness is gated on completed sits, not level — see
    /// `Practice.requiredCompletedSits`.
    var isAdvanced: Bool { self == .openAwareness }
}

/// The optional framing applied to stillness practices.
///
/// This changes vocabulary, the optional short reading offered after a sit, and
/// the ambient sound palette. It never changes the mechanics of a practice, and
/// the app is complete on `.secular`.
enum Tradition: String, Codable, CaseIterable, Sendable, Identifiable {
    case secular
    case buddhist
    case yogic
    case zen
    case stoic
    case sufi
    case christianContemplative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .secular: "Secular"
        case .buddhist: "Buddhist / Vipassana"
        case .yogic: "Yogic / Vedantic"
        case .zen: "Zen"
        case .stoic: "Stoic"
        case .sufi: "Sufi"
        case .christianContemplative: "Christian Contemplative"
        }
    }

    static let `default`: Tradition = .secular
}

/// Things a user can unlock or buy.
enum UnlockableType: String, Codable, CaseIterable, Sendable, Identifiable {
    case theme
    case companionSkin
    case soundscape
    case timerStyle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theme: "Theme"
        case .companionSkin: "Companion"
        case .soundscape: "Soundscape"
        case .timerStyle: "Timer Style"
        }
    }
}
