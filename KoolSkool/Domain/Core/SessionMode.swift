import Foundation

/// The rhythms a focus session can run on.
///
/// Raw values are persisted, so they are frozen: rename the display strings
/// freely, never the cases.
enum SessionMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case justStart
    case classicPomodoro
    case deepWork
    case flowmodoro
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justStart: "Just Start"
        case .classicPomodoro: "Pomodoro"
        case .deepWork: "Deep Work"
        case .flowmodoro: "Flowmodoro"
        case .custom: "Custom"
        }
    }

    /// One line, plain, no hype. Shown under the mode name at setup.
    var tagline: String {
        switch self {
        case .justStart: "Five minutes. Quit after if you want."
        case .classicPomodoro: "25 on, 5 off. The default."
        case .deepWork: "52 on, 17 off. For high-energy days."
        case .flowmodoro: "Counts up. Stop when the flow stops."
        case .custom: "Your own numbers."
        }
    }

    /// Ordering for the mode picker. Just Start is first, deliberately —
    /// it is the activation-energy killer and the whole pitch of the app.
    static var pickerOrder: [SessionMode] {
        [.justStart, .classicPomodoro, .deepWork, .flowmodoro, .custom]
    }
}

/// The timing rules for a mode. Kept as a value type so the focus engine can be
/// tested without touching persistence.
struct SessionModeProfile: Sendable, Hashable, Codable {
    /// Planned work length. Ignored when `countsUp` is true.
    var workDuration: TimeInterval
    var breakDuration: TimeInterval
    var longBreakDuration: TimeInterval?
    /// Number of completed work intervals before a long break is offered.
    var sessionsUntilLongBreak: Int?
    /// Flowmodoro: the timer counts up instead of down.
    var countsUp: Bool
    /// Flowmodoro: break length is elapsed work divided by this.
    var flowBreakDivisor: Double?
    /// Whether finishing this session should offer to roll into a longer one.
    var offersExtension: Bool

    static let flowBreakBounds: ClosedRange<TimeInterval> = 60...(30 * 60)

    /// How long a break should be, given how long the work interval actually ran.
    ///
    /// For fixed modes this is just `breakDuration`. For Flowmodoro it is
    /// `elapsed / divisor`, clamped to `flowBreakBounds` — a six-hour hyperfocus
    /// should not produce a seventy-minute break.
    func breakDuration(forElapsedWork elapsed: TimeInterval) -> TimeInterval {
        guard let divisor = flowBreakDivisor, divisor > 0 else { return breakDuration }
        let raw = elapsed / divisor
        return min(max(raw, Self.flowBreakBounds.lowerBound), Self.flowBreakBounds.upperBound)
    }
}

extension SessionMode {
    /// The built-in profile for this mode.
    ///
    /// `.custom` has no built-in profile — it is resolved from `AppSettings`
    /// via `profile(customWorkMinutes:customBreakMinutes:)`.
    var defaultProfile: SessionModeProfile {
        switch self {
        case .justStart:
            SessionModeProfile(
                workDuration: 5 * 60,
                breakDuration: 0,
                longBreakDuration: nil,
                sessionsUntilLongBreak: nil,
                countsUp: false,
                flowBreakDivisor: nil,
                offersExtension: true
            )
        case .classicPomodoro:
            SessionModeProfile(
                workDuration: 25 * 60,
                breakDuration: 5 * 60,
                longBreakDuration: 15 * 60,
                sessionsUntilLongBreak: 4,
                countsUp: false,
                flowBreakDivisor: nil,
                offersExtension: false
            )
        case .deepWork:
            SessionModeProfile(
                workDuration: 52 * 60,
                breakDuration: 17 * 60,
                longBreakDuration: nil,
                sessionsUntilLongBreak: nil,
                countsUp: false,
                flowBreakDivisor: nil,
                offersExtension: false
            )
        case .flowmodoro:
            SessionModeProfile(
                workDuration: 0,
                breakDuration: 5 * 60,
                longBreakDuration: nil,
                sessionsUntilLongBreak: nil,
                countsUp: true,
                flowBreakDivisor: 5,
                offersExtension: false
            )
        case .custom:
            SessionModeProfile(
                workDuration: 30 * 60,
                breakDuration: 6 * 60,
                longBreakDuration: nil,
                sessionsUntilLongBreak: nil,
                countsUp: false,
                flowBreakDivisor: nil,
                offersExtension: false
            )
        }
    }

    func profile(customWorkMinutes: Int, customBreakMinutes: Int) -> SessionModeProfile {
        guard self == .custom else { return defaultProfile }
        return SessionModeProfile(
            workDuration: TimeInterval(max(1, customWorkMinutes) * 60),
            breakDuration: TimeInterval(max(0, customBreakMinutes) * 60),
            longBreakDuration: nil,
            sessionsUntilLongBreak: nil,
            countsUp: false,
            flowBreakDivisor: nil,
            offersExtension: false
        )
    }
}
