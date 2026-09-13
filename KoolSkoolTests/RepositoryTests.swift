import Foundation
import Testing
@testable import KoolSkool

/// Exercises the repository protocols against a real in-memory SwiftData stack.
///
/// These go through the same `any TaskRepository` surface the features will use,
/// so they also assert that the seam actually holds — nothing here mentions
/// SwiftData.
@Suite("Repositories")
struct RepositoryTests {

    private func makeStack() async throws -> (provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 9
        components.minute = 30

        let now = try #require(calendar.date(from: components))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        return (provider, clock)
    }

    // MARK: Capture

    @Test("Brain dump capture trims and stores a task")
    func brainDumpCapture() async throws {
        let (provider, _) = try await makeStack()

        let captured = try await provider.tasks.captureFromBrainDump("   Read chapter three   ")
        #expect(captured.title == "Read chapter three")

        let all = try await provider.tasks.tasks(includeCompleted: false)
        #expect(all.count == 1)
        #expect(all.first?.id == captured.id)
    }

    @Test("Empty capture is rejected rather than creating a blank task")
    func brainDumpRejectsEmpty() async throws {
        let (provider, _) = try await makeStack()

        await #expect(throws: RepositoryError.self) {
            _ = try await provider.tasks.captureFromBrainDump("   \n  ")
        }

        let all = try await provider.tasks.tasks(includeCompleted: true)
        #expect(all.isEmpty)
    }

    @Test("Newest captures sort to the top of the inbox")
    func captureOrdering() async throws {
        let (provider, _) = try await makeStack()

        _ = try await provider.tasks.captureFromBrainDump("First")
        _ = try await provider.tasks.captureFromBrainDump("Second")
        let third = try await provider.tasks.captureFromBrainDump("Third")

        let all = try await provider.tasks.tasks(includeCompleted: false)
        #expect(all.first?.id == third.id)
    }

    // MARK: Round trip

    @Test("A task round-trips every field")
    func taskRoundTrip() async throws {
        let (provider, clock) = try await makeStack()

        var task = FocusTask()
        task.title = "Draft the essay"
        task.notes = "Two thousand words"
        task.nextStep = "Open the doc"
        task.estimateMinutes = 90
        task.resistance = Rating(clamping: 4)
        task.sortOrder = 7

        let saved = try await provider.tasks.upsert(task)
        let fetched = try #require(await provider.tasks.task(id: saved.id))

        #expect(fetched.title == "Draft the essay")
        #expect(fetched.notes == "Two thousand words")
        #expect(fetched.nextStep == "Open the doc")
        #expect(fetched.estimateMinutes == 90)
        #expect(fetched.resistance?.rawValue == 4)
        #expect(fetched.sortOrder == 7)
        #expect(fetched.updatedAt == clock.now)
    }

    @Test("Upserting an existing task updates rather than duplicating")
    func upsertUpdatesInPlace() async throws {
        let (provider, _) = try await makeStack()

        var task = try await provider.tasks.captureFromBrainDump("Original")
        task.title = "Renamed"
        _ = try await provider.tasks.upsert(task)

        let all = try await provider.tasks.tasks(includeCompleted: true)
        #expect(all.count == 1)
        #expect(all.first?.title == "Renamed")
    }

    @Test("startableLabel prefers the next tiny step")
    func startableLabelPrefersNextStep() {
        var task = FocusTask()
        task.title = "Write the dissertation"
        #expect(task.startableLabel == "Write the dissertation")

        task.nextStep = "Open the outline file"
        #expect(task.startableLabel == "Open the outline file")

        task.nextStep = "   "
        #expect(task.startableLabel == "Write the dissertation")
    }

    // MARK: Soft delete

    @Test("Deleting a task hides it but keeps the row")
    func softDeleteHidesTask() async throws {
        let (provider, _) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Temporary")
        try await provider.tasks.softDelete(taskID: task.id)

        let all = try await provider.tasks.tasks(includeCompleted: true)
        #expect(all.isEmpty)

        // Soft-deleted, so it is still addressable by id for a future sync.
        let fetched = try await provider.tasks.task(id: task.id)
        #expect(fetched?.deletedAt != nil)
    }

    @Test("Deleting a task also soft-deletes its steps")
    func softDeleteCascadesToSteps() async throws {
        let (provider, _) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Essay")
        try await provider.tasks.replaceSteps(taskID: task.id, titles: ["Outline", "Draft", "Edit"])
        try await provider.tasks.softDelete(taskID: task.id)

        let fetched = try #require(await provider.tasks.task(id: task.id))
        #expect(fetched.steps.isEmpty)
    }

    @Test("Deleting a task that does not exist reports not-found")
    func softDeleteMissingTask() async throws {
        let (provider, _) = try await makeStack()

        await #expect(throws: RepositoryError.self) {
            try await provider.tasks.softDelete(taskID: UUID())
        }
    }

    // MARK: Steps

    @Test("Templates replace steps in order")
    func replaceStepsOrders() async throws {
        let (provider, _) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Essay")
        try await provider.tasks.replaceSteps(taskID: task.id, titles: StepTemplate.writing.steps)

        let fetched = try #require(await provider.tasks.task(id: task.id))
        #expect(fetched.orderedSteps.map(\.title) == ["Read the brief", "Outline", "Draft", "Edit"])
        #expect(fetched.orderedSteps.map(\.order) == [0, 1, 2, 3])
    }

    @Test("Replacing steps again does not leave the old ones behind")
    func replaceStepsIsNotAdditive() async throws {
        let (provider, _) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Essay")
        try await provider.tasks.replaceSteps(taskID: task.id, titles: ["A", "B", "C"])
        try await provider.tasks.replaceSteps(taskID: task.id, titles: ["X", "Y"])

        let fetched = try #require(await provider.tasks.task(id: task.id))
        #expect(fetched.orderedSteps.map(\.title) == ["X", "Y"])
    }

    @Test("Blank step titles are skipped")
    func blankStepsAreSkipped() async throws {
        let (provider, _) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Essay")
        try await provider.tasks.replaceSteps(taskID: task.id, titles: ["Outline", "  ", "", "Draft"])

        let fetched = try #require(await provider.tasks.task(id: task.id))
        #expect(fetched.orderedSteps.count == 2)
    }

    // MARK: The rule of three

    @Test("Three musts are allowed")
    func threeMustsFit() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today

        for title in ["One", "Two", "Three"] {
            let task = try await provider.tasks.captureFromBrainDump(title)
            try await provider.tasks.setMust(taskID: task.id, day: today)
        }

        let musts = try await provider.tasks.musts(on: today)
        #expect(musts.count == 3)
    }

    @Test("A fourth must is refused")
    func fourthMustIsRefused() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today

        for title in ["One", "Two", "Three"] {
            let task = try await provider.tasks.captureFromBrainDump(title)
            try await provider.tasks.setMust(taskID: task.id, day: today)
        }

        let fourth = try await provider.tasks.captureFromBrainDump("Four")

        await #expect(throws: RepositoryError.mustLimitReached(limit: 3)) {
            try await provider.tasks.setMust(taskID: fourth.id, day: today)
        }

        let musts = try await provider.tasks.musts(on: today)
        #expect(musts.count == 3)
    }

    @Test("Re-flagging a task that is already a must is not blocked by the cap")
    func reflaggingAnExistingMustIsFine() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today

        var ids: [UUID] = []
        for title in ["One", "Two", "Three"] {
            let task = try await provider.tasks.captureFromBrainDump(title)
            try await provider.tasks.setMust(taskID: task.id, day: today)
            ids.append(task.id)
        }

        let first = try #require(ids.first)
        try await provider.tasks.setMust(taskID: first, day: today)

        let musts = try await provider.tasks.musts(on: today)
        #expect(musts.count == 3)
    }

    @Test("Finishing a must frees a slot")
    func completingAMustFreesASlot() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today

        var ids: [UUID] = []
        for title in ["One", "Two", "Three"] {
            let task = try await provider.tasks.captureFromBrainDump(title)
            try await provider.tasks.setMust(taskID: task.id, day: today)
            ids.append(task.id)
        }

        let first = try #require(ids.first)
        try await provider.tasks.complete(taskID: first, at: clock.now, actualMinutes: 25)

        // Only open musts count against the cap: you are never looking at more
        // than three at once, but finishing one lets you pick another.
        let fourth = try await provider.tasks.captureFromBrainDump("Four")
        try await provider.tasks.setMust(taskID: fourth.id, day: today)

        let musts = try await provider.tasks.musts(on: today)
        #expect(musts.count == 4)
        #expect(musts.filter { !$0.isCompleted }.count == 3)
    }

    @Test("Musts belong to a single day")
    func mustsAreScopedToTheirDay() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today
        let tomorrow = today.addingTimeInterval(86_400)

        let task = try await provider.tasks.captureFromBrainDump("Today only")
        try await provider.tasks.setMust(taskID: task.id, day: today)

        try #expect(await provider.tasks.musts(on: today).count == 1)
        try #expect(await provider.tasks.musts(on: tomorrow).isEmpty)
    }

    @Test("Clearing a must removes it")
    func clearingAMust() async throws {
        let (provider, clock) = try await makeStack()
        let today = clock.today

        let task = try await provider.tasks.captureFromBrainDump("Maybe")
        try await provider.tasks.setMust(taskID: task.id, day: today)
        try await provider.tasks.setMust(taskID: task.id, day: nil)

        try #expect(await provider.tasks.musts(on: today).isEmpty)
    }

    // MARK: Completion

    @Test("Completing a task accumulates actual minutes across sessions")
    func actualMinutesAccumulate() async throws {
        let (provider, clock) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Long one")
        try await provider.tasks.complete(taskID: task.id, at: clock.now, actualMinutes: 25)
        try await provider.tasks.reopen(taskID: task.id)
        try await provider.tasks.complete(taskID: task.id, at: clock.now, actualMinutes: 30)

        let fetched = try #require(await provider.tasks.task(id: task.id))
        #expect(fetched.actualMinutes == 55)
        #expect(fetched.isCompleted)
    }

    @Test("Completed tasks are excluded unless asked for")
    func completedTasksAreFilteredOut() async throws {
        let (provider, clock) = try await makeStack()

        let task = try await provider.tasks.captureFromBrainDump("Done")
        try await provider.tasks.complete(taskID: task.id, at: clock.now, actualMinutes: nil)

        try #expect(await provider.tasks.tasks(includeCompleted: false).isEmpty)
        try #expect(await provider.tasks.tasks(includeCompleted: true).count == 1)
    }

    // MARK: Sessions

    @Test("A session with no end date is the active one")
    func activeSessionIsRecoverable() async throws {
        let (provider, clock) = try await makeStack()

        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = clock.now
        session.plannedDuration = 25 * 60
        let saved = try await provider.sessions.upsert(session)

        // This is the force-quit recovery path.
        let active = try #require(await provider.sessions.activeSession())
        #expect(active.id == saved.id)

        var finished = active
        finished.endedAt = clock.now.addingTimeInterval(25 * 60)
        finished.wasCompleted = true
        _ = try await provider.sessions.upsert(finished)

        try #expect(await provider.sessions.activeSession() == nil)
    }

    @Test("Completed session days collapse to distinct local days")
    func completedSessionDaysAreDistinct() async throws {
        let (provider, clock) = try await makeStack()
        let start = clock.today

        // Two sessions today, one yesterday.
        for offset in [0.0, 3600.0, -86_400.0] {
            var session = FocusSession()
            session.startedAt = start.addingTimeInterval(offset + 600)
            session.endedAt = session.startedAt.addingTimeInterval(300)
            session.plannedDuration = 300
            session.wasCompleted = true
            _ = try await provider.sessions.upsert(session)
        }

        let days = try await provider.sessions.completedSessionDays(since: start.addingTimeInterval(-7 * 86_400))
        #expect(days.count == 2)
    }

    @Test("Abandoned sessions do not count toward a streak")
    func abandonedSessionsDoNotCount() async throws {
        let (provider, clock) = try await makeStack()

        var session = FocusSession()
        session.startedAt = clock.now
        session.endedAt = clock.now.addingTimeInterval(60)
        session.wasCompleted = false
        _ = try await provider.sessions.upsert(session)

        let days = try await provider.sessions.completedSessionDays(since: clock.today.addingTimeInterval(-86_400))
        #expect(days.isEmpty)
    }

    // MARK: Singletons

    @Test("Progress is created once and reused")
    func progressIsASingleton() async throws {
        let (provider, _) = try await makeStack()

        let first = try await provider.progress.progress()
        let second = try await provider.progress.progress()
        #expect(first.id == second.id)

        var updated = second
        updated.xp = 400
        updated.coins = 12
        _ = try await provider.progress.update(updated)

        let reloaded = try await provider.progress.progress()
        #expect(reloaded.id == first.id)
        #expect(reloaded.xp == 400)
        #expect(reloaded.coins == 12)
        #expect(reloaded.level == UserProgress.level(forXP: 400))
    }

    @Test("Settings are created once with sensible defaults")
    func settingsAreASingleton() async throws {
        let (provider, _) = try await makeStack()

        let first = try await provider.settings.settings()
        #expect(first.defaultMode == .justStart)
        #expect(first.timeChecksEnabled == false)
        #expect(first.tradition == .secular)
        #expect(first.hasCompletedOnboarding == false)

        var updated = first
        updated.tradition = .zen
        updated.timeChecksEnabled = true
        _ = try await provider.settings.update(updated)

        let reloaded = try await provider.settings.settings()
        #expect(reloaded.id == first.id)
        #expect(reloaded.tradition == .zen)
        #expect(reloaded.timeChecksEnabled)
    }

    // MARK: Reflections

    @Test("Morning and evening land in the same day's row")
    func reflectionMergesByDay() async throws {
        let (provider, clock) = try await makeStack()

        var morning = Reflection()
        morning.day = clock.now
        morning.morningIntention = "One clean pass over chapter two"
        let saved = try await provider.reflections.upsert(morning)

        // Hours later, from a different screen, with a fresh value type.
        var evening = Reflection()
        evening.id = saved.id
        evening.day = clock.now.addingTimeInterval(11 * 3600)
        evening.morningIntention = saved.morningIntention
        evening.eveningWentWell = "Got through it"
        evening.gratitude = "Quiet library"
        _ = try await provider.reflections.upsert(evening)

        let all = try await provider.reflections.reflections(in: clock.today..<clock.today.addingTimeInterval(86_400))
        #expect(all.count == 1)

        let row = try #require(all.first)
        #expect(row.hasMorning)
        #expect(row.hasEvening)
        #expect(row.morningIntention == "One clean pass over chapter two")
    }

    // MARK: Collection

    @Test("Reseeding refreshes copy without taking away what was unlocked")
    func reseedPreservesUnlockState() async throws {
        let (provider, clock) = try await makeStack()

        var item = Unlockable()
        item.key = "theme.midnight"
        item.type = .theme
        item.title = "Midnight"
        item.requiredLevel = 3
        try await provider.collection.seedIfNeeded([item])

        var unlocked = try #require(await provider.collection.unlockable(key: "theme.midnight"))
        unlocked.unlockedAt = clock.now
        _ = try await provider.collection.upsert(unlocked)

        // A later app version renames it and changes the gate.
        var revised = item
        revised.id = UUID()
        revised.title = "Midnight Blue"
        revised.requiredLevel = 2
        try await provider.collection.seedIfNeeded([revised])

        let all = try await provider.collection.unlockables()
        #expect(all.count == 1)

        let row = try #require(all.first)
        #expect(row.title == "Midnight Blue")
        #expect(row.requiredLevel == 2)
        #expect(row.isUnlocked)
    }

    @Test("Equipping one item of a type unequips the others")
    func equippingIsExclusivePerType() async throws {
        let (provider, clock) = try await makeStack()

        for key in ["theme.midnight", "theme.paper"] {
            var item = Unlockable()
            item.key = key
            item.type = .theme
            item.title = key
            item.unlockedAt = clock.now
            _ = try await provider.collection.upsert(item)
        }

        var soundscape = Unlockable()
        soundscape.key = "sound.rain"
        soundscape.type = .soundscape
        soundscape.title = "Rain"
        soundscape.unlockedAt = clock.now
        _ = try await provider.collection.upsert(soundscape)

        try await provider.collection.equip(key: "theme.midnight")
        try await provider.collection.equip(key: "theme.paper")
        try await provider.collection.equip(key: "sound.rain")

        let all = try await provider.collection.unlockables()
        let equippedThemes = all.filter { $0.type == .theme && $0.isEquipped }
        #expect(equippedThemes.count == 1)
        #expect(equippedThemes.first?.key == "theme.paper")

        // A different type is unaffected.
        #expect(all.first { $0.key == "sound.rain" }?.isEquipped == true)
    }

    @Test("A locked collectable cannot be equipped")
    func lockedItemsCannotBeEquipped() async throws {
        let (provider, _) = try await makeStack()

        var item = Unlockable()
        item.key = "theme.locked"
        item.type = .theme
        item.title = "Locked"
        _ = try await provider.collection.upsert(item)

        await #expect(throws: RepositoryError.self) {
            try await provider.collection.equip(key: "theme.locked")
        }
    }
}

/// The on-disk store, as the shipping app actually opens it.
///
/// Every other test in the suite runs in memory, so none of them can tell you
/// whether the real thing works. This one does exactly what `AppEnvironment.live()`
/// does on a cold launch. If it ever fails, the app falls back to a memory-only
/// store and silently keeps nothing — the single worst failure this app has.
@Suite("On-disk store")
struct OnDiskStoreTests {

    @Test("The store the app ships with can be opened on a fresh install")
    func containerOpens() throws {
        // `Library/Application Support` does not exist on a fresh iOS install.
        // Something has to create it, and this asserts that something does.
        let container = try KoolSkoolSchema.makeContainer()
        #expect(container.schema.entities.isEmpty == false)
    }

    @Test("Every model in the schema is registered")
    func schemaIsComplete() throws {
        let container = try KoolSkoolSchema.makeContainer()
        #expect(container.schema.entities.count == KoolSkoolSchema.models.count)
    }
}
