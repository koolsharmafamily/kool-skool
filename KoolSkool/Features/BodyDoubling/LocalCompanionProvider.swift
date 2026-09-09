import Foundation

/// The offline half of body doubling: one companion, always present, never
/// chatty.
///
/// An actor rather than a class because the engine talks to it from session
/// lifecycle callbacks and the view reads from it, and neither should have to
/// think about which thread the other is on.
actor LocalCompanionProvider: BodyDoublingProvider {
    nonisolated var identifier: String { "local.companion" }

    private var state: Coworker.WorkState = .arriving
    private var skinKey: String
    private var lastMilestone: CompanionMilestone?

    init(skinKey: String = CompanionSkin.default.key) {
        self.skinKey = skinKey
    }

    func setSkin(_ key: String) {
        skinKey = key
    }

    func coworkers() async -> [Coworker] {
        [
            Coworker(
                id: identifier,
                displayName: CompanionSkin.named(skinKey).displayName,
                kind: .companion(skinKey: skinKey),
                state: state
            )
        ]
    }

    func begin(session: FocusSession) async {
        state = .working
        lastMilestone = nil
    }

    func reportMilestone(_ milestone: CompanionMilestone) async {
        lastMilestone = milestone
    }

    func end(session: FocusSession, completed: Bool) async {
        state = completed ? .justFinished : .onBreak
    }

    func reset() async {
        state = .arriving
        lastMilestone = nil
    }
}

/// The drawn companions.
///
/// SF Symbols rather than bundled artwork: no assets to ship, they inherit the
/// energy-state colour for free, and `symbolEffect` gives the reactions without
/// a sprite sheet.
struct CompanionSkin: Sendable, Equatable {
    var key: String
    var displayName: String
    var symbolName: String
    /// Shown under the companion while a session runs.
    var idleLine: String

    static let `default` = CompanionSkin(
        key: "companion.lamp",
        displayName: "Desk Lamp",
        symbolName: "lightbulb.fill",
        idleLine: "On until you are done."
    )

    static let all: [CompanionSkin] = [
        .default,
        CompanionSkin(
            key: "companion.owl",
            displayName: "Owl",
            symbolName: "bird.fill",
            idleLine: "Awake at the same hours you are."
        ),
        CompanionSkin(
            key: "companion.cat",
            displayName: "Cat",
            symbolName: "pawprint.fill",
            idleLine: "Supervising, mostly."
        ),
        CompanionSkin(
            key: "companion.plant",
            displayName: "Plant",
            symbolName: "leaf.fill",
            idleLine: "Growing while you work."
        ),
    ]

    static func named(_ key: String) -> CompanionSkin {
        all.first { $0.key == key } ?? .default
    }
}
