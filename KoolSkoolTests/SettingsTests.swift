import Foundation
import Testing
@testable import KoolSkool

private func exportClock() throws -> MutableDateProvider {
    let utc = try #require(TimeZone(identifier: "UTC"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
    return MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
}

/// One of everything, including every kind of health-adjacent record, each
/// carrying a marker that must never appear in an export that excludes it.
private func seededStore() async throws -> (provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
    let clock = try exportClock()
    let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

    try await provider.tasks.captureFromBrainDump("Write the literature review")

    var session = FocusSession()
    session.mode = .classicPomodoro
    session.startedAt = clock.now
    session.plannedDuration = 25 * 60
    session.endedAt = clock.now.addingTimeInterval(25 * 60)
    session.endReason = .reachedPlannedEnd
    session.wasCompleted = true
    try await provider.sessions.upsert(session)

    var sit = StillnessSession()
    sit.startedAt = clock.now
    sit.durationSeconds = 60
    sit.completed = true
    try await provider.stillness.upsert(sit)

    var checkIn = CheckIn()
    checkIn.timestamp = clock.now
    checkIn.phase = .post
    checkIn.focusQuality = Rating(clamping: 4)
    checkIn.sessionID = session.id
    try await provider.checkIns.upsert(checkIn)

    var log = MedicationLog()
    log.timestamp = clock.now
    log.taken = true
    log.note = "MARKER-MEDICATION-NOTE"
    try await provider.medication.upsert(log)

    var reflection = Reflection()
    reflection.day = clock.today
    reflection.gratitude = "MARKER-GRATITUDE"
    try await provider.reflections.upsert(reflection)

    var settings = try await provider.settings.settings()
    settings.medicationTrackingEnabled = true
    settings.medicationReminderEnabled = true
    settings.medicationReminderMinutes = 437
    try await provider.settings.update(settings)

    return (provider, clock)
}

private func topLevelKeys(_ data: Data) throws -> [String: Any] {
    try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@MainActor
@Suite("Data export", .serialized)
struct DataExportTests {

    @Test("By default nothing health-adjacent leaves the app — not even the medication settings")
    func healthExcludedByDefault() async throws {
        let stack = try await seededStore()
        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: false, clock: stack.clock)
        let data = try DataExporter.encode(document)
        let text = String(decoding: data, as: UTF8.self)

        #expect(document.healthAdjacent == nil)
        #expect(text.contains("MARKER-MEDICATION-NOTE") == false)
        #expect(text.contains("MARKER-GRATITUDE") == false)
        #expect(text.contains("focusQuality") == false)
        #expect(text.contains("medicationReminderMinutes") == false)
        #expect(text.contains("medicationTrackingEnabled") == false)

        let expected: Set<String> = [
            "format", "version", "exportedAt", "includesHealthAdjacentData",
            "tasks", "sessions", "sits", "progress", "collection", "settings",
        ]
        #expect(Set(try topLevelKeys(data).keys) == expected)
    }

    @Test("Asking for health-adjacent data includes all of it")
    func healthIncludedWhenAsked() async throws {
        let stack = try await seededStore()
        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: true, clock: stack.clock)
        let text = String(decoding: try DataExporter.encode(document), as: UTF8.self)

        let health = try #require(document.healthAdjacent)
        #expect(health.checkIns.count == 1)
        #expect(health.medicationLogs.count == 1)
        #expect(health.reflections.count == 1)
        #expect(health.medicationSettings.medicationReminderMinutes == 437)
        #expect(document.includesHealthAdjacentData)
        #expect(text.contains("MARKER-MEDICATION-NOTE"))
        #expect(text.contains("MARKER-GRATITUDE"))
    }

    @Test("The everyday data is all there either way")
    func standardDataPresent() async throws {
        let stack = try await seededStore()
        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: false, clock: stack.clock)

        #expect(document.tasks.count == 1)
        #expect(document.sessions.count == 1)
        #expect(document.sits.count == 1)
        #expect(document.format == ExportDocument.formatName)
        #expect(document.version == ExportDocument.currentVersion)
    }

    @Test("Every setting is exported somewhere, and the medication ones only with health data")
    func settingsCoverage() throws {
        var settings = AppSettings()
        settings.soundscapeKey = "sound.brown"
        settings.preferredWorkTime = .morning

        let metadata: Set<String> = ["id", "createdAt", "updatedAt", "deletedAt"]
        let all = try Self.keys(of: settings).subtracting(metadata)
        let standard = try Self.keys(of: ExportedSettings(settings))
        let medication = try Self.keys(of: MedicationSettings(settings))

        // A new setting that is not added to one of the two fails here, rather
        // than silently going missing from everyone's export.
        #expect(standard.union(medication) == all)
        #expect(standard.isDisjoint(with: medication))

        let expectedMedication: Set<String> = ["medicationTrackingEnabled", "medicationReminderEnabled", "medicationReminderMinutes"]
        #expect(medication == expectedMedication)
    }

    @Test("Deleted tasks are not exported")
    func deletedLeftOut() async throws {
        let stack = try await seededStore()
        let doomed = try await stack.provider.tasks.captureFromBrainDump("Changed my mind")
        try await stack.provider.tasks.softDelete(taskID: doomed.id)

        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: false, clock: stack.clock)
        #expect(document.tasks.contains { $0.id == doomed.id } == false)
    }

    @Test("The file reads back")
    func readsBack() async throws {
        let stack = try await seededStore()
        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: true, clock: stack.clock)
        let decoded = try DataExporter.decode(try DataExporter.encode(document))

        #expect(decoded.tasks.map { $0.id } == document.tasks.map { $0.id })
        #expect(decoded.sessions.map { $0.id } == document.sessions.map { $0.id })
        #expect(decoded.healthAdjacent?.medicationLogs.map { $0.id } == document.healthAdjacent?.medicationLogs.map { $0.id })
        #expect(decoded.includesHealthAdjacentData == document.includesHealthAdjacentData)
    }

    @Test("Dates are written in a form a person can read")
    func readableDates() async throws {
        let stack = try await seededStore()
        let document = try await DataExporter.document(from: stack.provider, includeHealthAdjacent: false, clock: stack.clock)
        let object = try topLevelKeys(try DataExporter.encode(document))

        #expect(object["exportedAt"] as? String == "2026-06-15T09:00:00Z")
    }

    @Test("The file is named for the day")
    func fileName() throws {
        let clock = try exportClock()
        #expect(DataExporter.fileName(exportedAt: clock.now, clock: clock) == "kool-skool-2026-06-15.json")
    }

    @Test("A new export replaces the last one instead of piling up copies of someone's history")
    func replacesPreviousFile() throws {
        let first = try DataExporter.write(Data("one".utf8), named: "kool-skool-2026-06-14.json")
        let second = try DataExporter.write(Data("two".utf8), named: "kool-skool-2026-06-15.json")

        #expect(FileManager.default.fileExists(atPath: first.path) == false)
        #expect(FileManager.default.fileExists(atPath: second.path))
        let contents = try FileManager.default.contentsOfDirectory(atPath: DataExporter.exportDirectory.path)
        #expect(contents == ["kool-skool-2026-06-15.json"])
    }

    @Test("The export screen leaves health-adjacent data out until asked")
    func screenDefault() async throws {
        let stack = try await seededStore()
        let model = DataExportModel(repositories: stack.provider, clock: stack.clock)
        #expect(model.includeHealthAdjacent == false)
    }

    @Test("Changing what's included throws away a file prepared under the other choice")
    func toggleInvalidates() async throws {
        let stack = try await seededStore()
        let model = DataExportModel(repositories: stack.provider, clock: stack.clock)
        await model.prepare()

        guard case .ready = model.state else {
            Issue.record("Expected a prepared export, got \(model.state)")
            return
        }

        model.setIncludeHealthAdjacent(true)
        #expect(model.state == .idle)
    }

    private static func keys<T: Encodable>(of value: T) throws -> Set<String> {
        let data = try JSONEncoder().encode(value)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }
}

@Suite("Settings persistence")
struct SettingsPersistenceTests {

    @Test("Every setting survives a round trip through the store")
    func everySettingPersists() async throws {
        let clock = try exportClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let original = try await provider.settings.settings()

        var object = try Self.dictionary(original)

        // Flip every flag and bump every number, generically, so a new setting
        // that is added to `AppSettings` but not mirrored in the store fails
        // here instead of quietly resetting itself on the next launch.
        for (key, value) in object where !Self.metadata.contains(key) {
            let number = value as AnyObject
            if CFGetTypeID(number) == CFBooleanGetTypeID(), let flag = value as? Bool {
                object[key] = !flag
            } else if let integer = value as? Int {
                object[key] = integer + 1
            }
        }

        // Strings and optionals cannot be changed generically.
        object["defaultMode"] = SessionMode.deepWork.rawValue
        object["tradition"] = Tradition.zen.rawValue
        object["soundscapeKey"] = "sound.pink"
        object["preferredWorkTime"] = TimeOfDay.evening.rawValue

        let mutated = try JSONDecoder().decode(AppSettings.self, from: try JSONSerialization.data(withJSONObject: object))
        try await provider.settings.update(mutated)
        let reloaded = try await provider.settings.settings()

        let expected = try Self.dictionary(mutated).filter { !Self.metadata.contains($0.key) } as NSDictionary
        let actual = try Self.dictionary(reloaded).filter { !Self.metadata.contains($0.key) } as NSDictionary
        #expect(actual == expected)
    }

    private static let metadata: Set<String> = ["id", "createdAt", "updatedAt", "deletedAt"]

    private static func dictionary(_ settings: AppSettings) throws -> [String: Any] {
        let data = try JSONEncoder().encode(settings)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
