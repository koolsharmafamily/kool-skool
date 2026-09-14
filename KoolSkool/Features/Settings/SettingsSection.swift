import Foundation

/// The groups Settings is split into, in the order they are listed.
///
/// Eight short pages rather than one long one: a single scroll of every switch
/// was already long before durations, haptics, accessibility, export and about
/// joined it.
enum SettingsSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case focus
    case feel
    case notifications
    case checkIns
    case stillness
    case accessibility
    case data
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: "Focus and time"
        case .feel: "Sound and haptics"
        case .notifications: "Notifications"
        case .checkIns: "Check-ins and medication"
        case .stillness: "Stillness"
        case .accessibility: "Accessibility"
        case .data: "Your data"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "timer"
        case .feel: "speaker.wave.2"
        case .notifications: "bell"
        case .checkIns: "heart.text.square"
        case .stillness: "moon.stars"
        case .accessibility: "accessibility"
        case .data: "square.and.arrow.up"
        case .about: "info.circle"
        }
    }
}
