import Foundation

/// A copy of everything, in a file the user controls.
///
/// Check-ins, the medication log and reflections are left out unless the user
/// switches them in — the same default the future sync consent will have. When
/// they are left out, so are the medication settings: a reminder time on its
/// own says that someone takes something.
struct ExportDocument: Codable, Equatable, Sendable {
    static let formatName = "kool-skool-export"
    static let currentVersion = 1

    var format: String = ExportDocument.formatName
    var version: Int = ExportDocument.currentVersion
    var exportedAt: Date
    var includesHealthAdjacentData: Bool

    var tasks: [FocusTask]
    var sessions: [FocusSession]
    var sits: [StillnessSession]
    var progress: UserProgress
    var collection: [Unlockable]
    var settings: ExportedSettings
    /// Absent from the file entirely — not empty — when it was not included.
    var healthAdjacent: HealthAdjacentExport?
}

struct HealthAdjacentExport: Codable, Equatable, Sendable {
    var checkIns: [CheckIn]
    var medicationLogs: [MedicationLog]
    var reflections: [Reflection]
    var medicationSettings: MedicationSettings
}

/// The medication preferences, which travel with the health-adjacent data.
struct MedicationSettings: Codable, Equatable, Sendable {
    var medicationTrackingEnabled: Bool
    var medicationReminderEnabled: Bool
    var medicationReminderMinutes: Int

    init(_ settings: AppSettings) {
        medicationTrackingEnabled = settings.medicationTrackingEnabled
        medicationReminderEnabled = settings.medicationReminderEnabled
        medicationReminderMinutes = settings.medicationReminderMinutes
    }
}

/// Every preference except the medication ones.
///
/// Listed out rather than derived, so it is plain to read what leaves the app.
/// A test fails if a setting is added to `AppSettings` and not to this or to
/// `MedicationSettings`, so nothing can go silently missing from an export.
struct ExportedSettings: Codable, Equatable, Sendable {
    var defaultMode: SessionMode
    var customWorkMinutes: Int
    var customBreakMinutes: Int
    var keepScreenAwakeDuringSession: Bool
    var sessionEndAlertsEnabled: Bool
    var timeChecksEnabled: Bool
    var timeCheckIntervalMinutes: Int
    var showDigitalTimer: Bool
    var autoPadEstimates: Bool
    var hapticsEnabled: Bool
    var soundsEnabled: Bool
    var soundscapeKey: String?
    var commitmentCardEnabled: Bool
    var companionEnabled: Bool
    var preSessionCheckIn: Bool
    var postSessionCheckIn: Bool
    var reduceMotionOverride: Bool
    var tradition: Tradition
    var offerBreakPractice: Bool
    var intervalBellsEnabled: Bool
    var preferredWorkTime: TimeOfDay?
    var hasCompletedOnboarding: Bool

    init(_ settings: AppSettings) {
        defaultMode = settings.defaultMode
        customWorkMinutes = settings.customWorkMinutes
        customBreakMinutes = settings.customBreakMinutes
        keepScreenAwakeDuringSession = settings.keepScreenAwakeDuringSession
        sessionEndAlertsEnabled = settings.sessionEndAlertsEnabled
        timeChecksEnabled = settings.timeChecksEnabled
        timeCheckIntervalMinutes = settings.timeCheckIntervalMinutes
        showDigitalTimer = settings.showDigitalTimer
        autoPadEstimates = settings.autoPadEstimates
        hapticsEnabled = settings.hapticsEnabled
        soundsEnabled = settings.soundsEnabled
        soundscapeKey = settings.soundscapeKey
        commitmentCardEnabled = settings.commitmentCardEnabled
        companionEnabled = settings.companionEnabled
        preSessionCheckIn = settings.preSessionCheckIn
        postSessionCheckIn = settings.postSessionCheckIn
        reduceMotionOverride = settings.reduceMotionOverride
        tradition = settings.tradition
        offerBreakPractice = settings.offerBreakPractice
        intervalBellsEnabled = settings.intervalBellsEnabled
        preferredWorkTime = settings.preferredWorkTime
        hasCompletedOnboarding = settings.hasCompletedOnboarding
    }
}

extension ExportDocument {
    struct Line: Identifiable, Equatable, Sendable {
        var label: String
        var count: Int
        var id: String { label }
    }

    /// What is in the file, shown before it is shared.
    var summary: [Line] {
        var lines = [
            Line(label: "Tasks", count: tasks.count),
            Line(label: "Focus sessions", count: sessions.count),
            Line(label: "Stillness sits", count: sits.count),
            Line(label: "Unlocked items", count: collection.filter { $0.isUnlocked }.count),
        ]
        if let healthAdjacent {
            lines.append(Line(label: "Check-ins", count: healthAdjacent.checkIns.count))
            lines.append(Line(label: "Medication log entries", count: healthAdjacent.medicationLogs.count))
            lines.append(Line(label: "Reflections", count: healthAdjacent.reflections.count))
        }
        return lines
    }
}

enum DataExporter {

    static func document(
        from repositories: any RepositoryProvider,
        includeHealthAdjacent: Bool,
        clock: any DateProvider
    ) async throws -> ExportDocument {
        let allTime = Date.distantPast..<Date.distantFuture

        let settings = try await repositories.settings.settings()
        let tasks = try await repositories.tasks.tasks(includeCompleted: true)
        let sessions = try await repositories.sessions.sessions(in: allTime)
        let sits = try await repositories.stillness.sits(in: allTime)
        let progress = try await repositories.progress.progress()
        let collection = try await repositories.collection.unlockables()

        var healthAdjacent: HealthAdjacentExport?
        if includeHealthAdjacent {
            healthAdjacent = HealthAdjacentExport(
                checkIns: try await repositories.checkIns.checkIns(in: allTime),
                medicationLogs: try await repositories.medication.logs(in: allTime),
                reflections: try await repositories.reflections.reflections(in: allTime),
                medicationSettings: MedicationSettings(settings)
            )
        }

        return ExportDocument(
            exportedAt: clock.now,
            includesHealthAdjacentData: includeHealthAdjacent,
            tasks: tasks,
            sessions: sessions,
            sits: sits,
            progress: progress,
            collection: collection,
            settings: ExportedSettings(settings),
            healthAdjacent: healthAdjacent
        )
    }

    /// Pretty-printed, sorted, and with dates a person can read. Sub-second
    /// precision is lost from timestamps; nothing else is.
    static func encode(_ document: ExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    /// There is no import yet. This proves the file could support one.
    static func decode(_ data: Data) throws -> ExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportDocument.self, from: data)
    }

    static func fileName(exportedAt date: Date, clock: any DateProvider) -> String {
        var calendar = clock.calendar
        calendar.timeZone = clock.timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "kool-skool-%04d-%02d-%02d.json", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static var exportDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("KoolSkoolExport", isDirectory: true)
    }

    /// Replaces any earlier export rather than letting copies of someone's
    /// history pile up in the app's temporary folder.
    static func write(_ data: Data, named name: String) throws -> URL {
        let manager = FileManager.default
        let directory = exportDirectory

        if manager.fileExists(atPath: directory.path) {
            try manager.removeItem(at: directory)
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
