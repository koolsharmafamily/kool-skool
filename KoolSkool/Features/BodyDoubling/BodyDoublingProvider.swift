import Foundation

/// Someone visibly working alongside you.
///
/// In v1 there is exactly one of these and it is synthetic. The type is shaped
/// for the version where there are five and they are real people, so the views
/// that render a row of coworkers do not change when that arrives.
struct Coworker: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// A drawn companion. `skinKey` matches an `Unlockable` key.
        case companion(skinKey: String)
        /// Reserved for the remote rooms in a later version.
        case person
    }

    enum WorkState: Sendable, Equatable {
        case arriving
        case working
        case onBreak
        case justFinished
    }

    var id: String
    var displayName: String
    var kind: Kind
    var state: WorkState

    /// What a screen reader says about them.
    var spokenState: String {
        switch state {
        case .arriving: "\(displayName) is settling in"
        case .working: "\(displayName) is working alongside you"
        case .onBreak: "\(displayName) is taking a break"
        case .justFinished: "\(displayName) has finished"
        }
    }
}

/// Points during a session where the companion reacts.
///
/// Deliberately few. A companion that responds to everything is a pet demanding
/// attention, which is the opposite of what body doubling is for.
enum CompanionMilestone: Sendable, Equatable, CaseIterable {
    case quarter
    case half
    case threeQuarters
    case nearlyDone

    var fraction: Double {
        switch self {
        case .quarter: 0.25
        case .half: 0.5
        case .threeQuarters: 0.75
        case .nearlyDone: 0.9
        }
    }

    /// The milestone a session at this progress has most recently passed.
    static func reached(at progress: Double) -> CompanionMilestone? {
        allCases.last { progress >= $0.fraction }
    }
}

/// Where "who is working alongside me" comes from.
///
/// v1 ships `LocalCompanionProvider` and nothing else — real multiplayer rooms
/// need a backend, which is out of scope. This protocol is the seam so that
/// adding `RemoteRoomProvider` later is a new file and a line in the composition
/// root, rather than a rewrite of the session screen.
protocol BodyDoublingProvider: Sendable {
    /// A stable identifier for the provider itself, for settings and telemetry.
    var identifier: String { get }

    /// Everyone currently working alongside the user.
    func coworkers() async -> [Coworker]

    func begin(session: FocusSession) async
    func reportMilestone(_ milestone: CompanionMilestone) async
    func end(session: FocusSession, completed: Bool) async
    func reset() async
}
