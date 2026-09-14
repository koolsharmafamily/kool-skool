import Foundation

/// Coarse times of day.
///
/// The spec asks for focus quality "by hour of day". With one person's sessions
/// that is twenty-four mostly empty bars and a lot of noise — two sessions at
/// 3pm is not a pattern. Five named blocks give each bar enough in it to mean
/// something, and read as a sentence rather than a histogram.
///
/// Lives in the domain because onboarding stores the answer to "when do you
/// work best?" in these same blocks, so Insights can hold what someone said up
/// against what their sessions show.
enum TimeOfDay: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case early
    case morning
    case afternoon
    case evening
    case late

    var id: Int { rawValue }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.rawValue < rhs.rawValue }

    static func of(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<8: .early
        case 8..<12: .morning
        case 12..<17: .afternoon
        case 17..<21: .evening
        default: .late
        }
    }

    var displayName: String {
        switch self {
        case .early: "Early"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .late: "Late"
        }
    }

    var hoursLabel: String {
        switch self {
        case .early: "5–8am"
        case .morning: "8am–12"
        case .afternoon: "12–5pm"
        case .evening: "5–9pm"
        case .late: "9pm–5am"
        }
    }

    /// For the sentence, lower-cased and made to sit after "your".
    var phrase: String { displayName.lowercased() }

    /// Sits after "you work best", e.g. "in the afternoon".
    var whenPhrase: String {
        switch self {
        case .early: "early in the morning"
        case .morning: "in the morning"
        case .afternoon: "in the afternoon"
        case .evening: "in the evening"
        case .late: "late at night"
        }
    }
}
