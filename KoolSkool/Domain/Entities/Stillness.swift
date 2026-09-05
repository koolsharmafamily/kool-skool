import Foundation

/// One completed (or abandoned) stillness practice.
struct StillnessSession: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var practiceType: PracticeType = .boxBreathing
    var practiceID: UUID?

    var startedAt: Date = .now
    var durationSeconds: Int = 0
    var completed: Bool = false

    /// The tradition framing in effect at the time of the sit. Recorded rather
    /// than looked up, so history stays truthful if the user switches later.
    var tradition: Tradition = .secular

    /// Set when the sit was offered as part of a focus break.
    var focusSessionID: UUID?
}

/// The morning intention and evening close for one day.
struct Reflection: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    /// Midnight local time. One reflection per day.
    var day: Date = .now

    var morningIntention: String = ""
    var eveningWentWell: String = ""
    var eveningWasHard: String = ""
    var gratitude: String = ""

    var hasMorning: Bool {
        !morningIntention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasEvening: Bool {
        [eveningWentWell, eveningWasHard, gratitude]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

/// A bundled practice: its script, its optional audio, and how it is gated.
///
/// Content rule: everything here is either written for this app or genuinely
/// public domain with `attribution` filled in. Nothing is generated in the voice
/// of a named real person, and no teacher's voice or likeness is synthesised.
struct Practice: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var title: String = ""
    var subtitle: String = ""
    var type: PracticeType = .boxBreathing

    /// Offered lengths, in seconds. First entry is the default.
    var durationOptionsSeconds: [Int] = []

    /// Name of a bundled audio asset. Nil means text-and-visual only.
    var audioAssetName: String?

    /// The app's own words unless `attribution` says otherwise.
    var scriptText: String = ""

    /// Set only for verbatim public-domain or explicitly licensed text.
    /// Rendered next to the passage whenever present.
    var attribution: String?

    var requiredLevel: Int = 0
    /// Open awareness unlocks after this many completed sits.
    var requiredCompletedSits: Int = 0

    /// Which tradition framings offer this practice. Empty means all of them.
    var traditionTags: [Tradition] = []

    // Reserved for the v2 guided path. Unused in v1 but present so adding
    // programs later is not a schema migration.
    var programID: UUID?
    var orderInProgram: Int?

    var defaultDurationSeconds: Int { durationOptionsSeconds.first ?? 180 }

    func isAvailable(level: Int, completedSits: Int) -> Bool {
        level >= requiredLevel && completedSits >= requiredCompletedSits
    }

    func matches(tradition: Tradition) -> Bool {
        traditionTags.isEmpty || traditionTags.contains(tradition)
    }
}
