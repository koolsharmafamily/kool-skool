import Foundation
import Testing
@testable import KoolSkool

@MainActor
@Suite("Check-ins")
struct CheckInTests {

    private func makeStack() async throws -> (engine: FocusEngine, provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

        let engine = FocusEngine(
            repositories: provider,
            clock: clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            ticksAutomatically: false
        )
        engine.apply(settings: AppSettings())
        return (engine, provider, clock)
    }

    private func allCheckIns(_ provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) async throws -> [CheckIn] {
        try await provider.checkIns.checkIns(in: clock.now.addingTimeInterval(-86_400)..<clock.now.addingTimeInterval(86_400))
    }

    // MARK: Before

    @Test("Energy and mood given at setup are saved against the session")
    func preCheckInIsSaved() async throws {
        let stack = try await makeStack()
        let plan = SessionPlan(
            mode: .classicPomodoro,
            plannedDuration: 25 * 60,
            energy: Rating(clamping: 2),
            mood: Rating(clamping: 4)
        )
        await stack.engine.start(plan)

        let sessionID = try #require(stack.engine.session?.id)
        let saved = try await stack.provider.checkIns.checkIns(forSessionID: sessionID)

        #expect(saved.count == 1)
        #expect(saved.first?.phase == .pre)
        #expect(saved.first?.energy?.rawValue == 2)
        #expect(saved.first?.mood?.rawValue == 4)
    }

    @Test("A skipped check-in leaves no row at all")
    func skippedCheckInWritesNothing() async throws {
        let stack = try await makeStack()
        await stack.engine.start(SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60))

        // An empty row would be indistinguishable from a real "don't know".
        #expect(try await allCheckIns(stack.provider, clock: stack.clock).isEmpty)
    }

    // MARK: After

    private func finishedSession(_ stack: (engine: FocusEngine, provider: SwiftDataRepositoryProvider, clock: MutableDateProvider)) async {
        await stack.engine.start(SessionPlan(mode: .justStart, plannedDuration: 5 * 60))
        stack.clock.advance(by: 5 * 60)
        await stack.engine.tick()
    }

    @Test("One tap after a session records how it went")
    func postCheckInIsSaved() async throws {
        let stack = try await makeStack()
        await finishedSession(stack)
        let sessionID = try #require(stack.engine.finishedSession?.id)

        await stack.engine.recordPostCheckIn(quality: Rating(clamping: 4))

        let saved = try await stack.provider.checkIns.checkIns(forSessionID: sessionID)
        #expect(saved.count == 1)
        #expect(saved.first?.phase == .post)
        #expect(saved.first?.focusQuality?.rawValue == 4)
        #expect(stack.engine.postCheckInRecorded)
    }

    @Test("Changing the answer updates the same row instead of adding another")
    func changingTheAnswerUpdatesInPlace() async throws {
        let stack = try await makeStack()
        await finishedSession(stack)
        let sessionID = try #require(stack.engine.finishedSession?.id)

        await stack.engine.recordPostCheckIn(quality: Rating(clamping: 2))
        await stack.engine.recordPostCheckIn(quality: Rating(clamping: 5))

        let saved = try await stack.provider.checkIns.checkIns(forSessionID: sessionID)
        #expect(saved.count == 1)
        #expect(saved.first?.focusQuality?.rawValue == 5)
    }

    @Test("Clearing the answer removes it")
    func clearingRemoves() async throws {
        let stack = try await makeStack()
        await finishedSession(stack)
        let sessionID = try #require(stack.engine.finishedSession?.id)

        await stack.engine.recordPostCheckIn(quality: Rating(clamping: 3))
        await stack.engine.recordPostCheckIn(quality: nil)

        #expect(try await stack.provider.checkIns.checkIns(forSessionID: sessionID).isEmpty)
        #expect(stack.engine.postCheckInRecorded == false)
    }

    @Test("The next session starts with a fresh question")
    func nextSessionResets() async throws {
        let stack = try await makeStack()
        await finishedSession(stack)
        await stack.engine.recordPostCheckIn(quality: Rating(clamping: 3))

        stack.engine.dismissCompletion()
        await finishedSession(stack)

        #expect(stack.engine.postCheckInRecorded == false)
    }

    @Test("Keep going does not carry the old check-in into the new session")
    func keepGoingDoesNotCopyTheCheckIn() async throws {
        let stack = try await makeStack()
        let plan = SessionPlan(mode: .justStart, plannedDuration: 5 * 60, energy: Rating(clamping: 5))
        await stack.engine.start(plan)
        stack.clock.advance(by: 5 * 60)
        await stack.engine.tick()

        await stack.engine.continueSession(as: .classicPomodoro)
        let newID = try #require(stack.engine.session?.id)

        // Energy five minutes ago is not energy now.
        #expect(try await stack.provider.checkIns.checkIns(forSessionID: newID).isEmpty)
    }

    @Test("Check-in defaults respect the setup screen")
    func defaults() {
        let settings = AppSettings()
        // The setup screen is where people bounce, so the two-tap version is off
        // until someone asks for it. The one-tap version after is on.
        #expect(settings.preSessionCheckIn == false)
        #expect(settings.postSessionCheckIn)
    }
}

@MainActor
@Suite("Medication log")
struct MedicationModelTests {

    private func makeModel(grantsPermission: Bool = true) async throws -> (model: MedicationModel, reminders: RecordingReminderScheduler, provider: SwiftDataRepositoryProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 8, minute: 14)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let reminders = RecordingReminderScheduler(grantsPermission: grantsPermission)
        let model = MedicationModel(repositories: provider, clock: clock, reminders: reminders)
        return (model, reminders, provider)
    }

    @Test("Medication tracking is off until someone switches it on")
    func offByDefault() {
        let settings = AppSettings()
        #expect(settings.medicationTrackingEnabled == false)
        #expect(settings.medicationReminderEnabled == false)
    }

    @Test("One tap logs today")
    func logToday() async throws {
        let stack = try await makeModel()
        await stack.model.load()
        #expect(stack.model.isLoggedToday == false)

        await stack.model.toggleToday()
        #expect(stack.model.isLoggedToday)
        #expect(stack.model.todaysLabel.hasPrefix("Logged at"))
    }

    @Test("Tapping again undoes it")
    func undo() async throws {
        let stack = try await makeModel()
        await stack.model.toggleToday()
        await stack.model.toggleToday()

        // A mis-tap in a health log is worse than no log.
        #expect(stack.model.isLoggedToday == false)
        #expect(stack.model.recent.isEmpty)
    }

    @Test("A note can be added and trimmed")
    func note() async throws {
        let stack = try await makeModel()
        await stack.model.toggleToday()
        await stack.model.updateNote("  took it late  ")

        #expect(stack.model.todaysLog?.note == "took it late")
    }

    @Test("Switching the reminder on asks, then schedules")
    func reminderSchedules() async throws {
        let stack = try await makeModel()
        let armed = await stack.model.setReminder(enabled: true, minutesAfterMidnight: 450)

        #expect(armed)
        #expect(stack.reminders.scheduled == [450])
        #expect(stack.model.permissionDenied == false)
    }

    @Test("A refused permission leaves the toggle honestly off")
    func reminderRespectsDenial() async throws {
        let stack = try await makeModel(grantsPermission: false)
        let armed = await stack.model.setReminder(enabled: true, minutesAfterMidnight: 450)

        // A switch that says "on" while nothing will ever arrive is a quiet lie.
        #expect(armed == false)
        #expect(stack.model.permissionDenied)
        #expect(stack.reminders.scheduled.isEmpty)
    }

    @Test("Switching it off cancels it")
    func reminderCancels() async throws {
        let stack = try await makeModel()
        _ = await stack.model.setReminder(enabled: true, minutesAfterMidnight: 450)
        _ = await stack.model.setReminder(enabled: false, minutesAfterMidnight: 450)

        #expect(stack.reminders.cancelCount >= 1)
    }

    @Test("A reminder is never restored for someone not tracking")
    func restoreRequiresTracking() async throws {
        let stack = try await makeModel()

        var settings = AppSettings()
        settings.medicationTrackingEnabled = false
        settings.medicationReminderEnabled = true
        await stack.model.restoreReminder(settings: settings)

        #expect(stack.reminders.scheduled.isEmpty)
        #expect(stack.reminders.cancelCount == 1)
    }

    @Test("Restoring re-arms an enabled reminder without prompting")
    func restoreRearms() async throws {
        let stack = try await makeModel()

        var settings = AppSettings()
        settings.medicationTrackingEnabled = true
        settings.medicationReminderEnabled = true
        settings.medicationReminderMinutes = 510
        await stack.model.restoreReminder(settings: settings)

        #expect(stack.reminders.scheduled == [510])
    }

    @Test("The lock screen text says nothing about medication")
    func reminderIsDiscreet() {
        // Anyone near the phone can read a lock screen. A future edit to this
        // copy has to get past a failing test first.
        let visible = (LocalMedicationReminderScheduler.notificationTitle
            + " " + LocalMedicationReminderScheduler.notificationBody).lowercased()

        for revealing in ["medic", "meds", "pill", "dose", "tablet", "adhd", "prescri", "take your"] {
            #expect(!visible.contains(revealing), "The reminder must not say \"\(revealing)\" on the lock screen")
        }
    }
}
