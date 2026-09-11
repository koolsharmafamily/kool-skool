import Foundation
import Observation

/// A log, and nothing more.
///
/// No drug database, no interaction warnings, no dosing guidance — not now and
/// not later. The only facts recorded are the ones the user typed: that they
/// took it, when, and an optional note.
@MainActor
@Observable
final class MedicationModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider
    private let reminders: any MedicationReminderScheduling

    private(set) var todaysLog: MedicationLog?
    private(set) var recent: [MedicationLog] = []
    private(set) var permissionDenied = false
    private(set) var error: String?

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider,
        reminders: any MedicationReminderScheduling = LocalMedicationReminderScheduler()
    ) {
        self.repositories = repositories
        self.clock = clock
        self.reminders = reminders
    }

    var isLoggedToday: Bool { todaysLog?.taken == true }

    var todaysLabel: String {
        guard let todaysLog, todaysLog.taken else { return "Not logged today" }
        return "Logged at \(todaysLog.timestamp.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: Loading

    func load() async {
        do {
            let today = clock.today
            let tomorrow = today.addingTimeInterval(86_400)
            let monthAgo = today.addingTimeInterval(-30 * 86_400)

            let todays = try await repositories.medication.logs(in: today..<tomorrow)
            todaysLog = todays.first { $0.taken }

            recent = try await repositories.medication.logs(in: monthAgo..<tomorrow)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Logging

    /// One tap. Tapping again undoes it, because a mis-tap in a health log is
    /// worse than useless.
    func toggleToday(note: String = "") async {
        do {
            if let existing = todaysLog, existing.taken {
                try await repositories.medication.softDelete(logID: existing.id)
            } else {
                var log = MedicationLog()
                log.timestamp = clock.now
                log.taken = true
                log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                try await repositories.medication.upsert(log)
            }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateNote(_ note: String) async {
        guard var log = todaysLog else { return }
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await repositories.medication.upsert(log)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ log: MedicationLog) async {
        do {
            try await repositories.medication.softDelete(logID: log.id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Reminder

    /// Permission is asked for here and only here: the user just switched a
    /// reminder on, so the reason is already on screen. Returns whether the
    /// reminder is actually armed, so the toggle can tell the truth.
    func setReminder(enabled: Bool, minutesAfterMidnight: Int) async -> Bool {
        guard enabled else {
            await reminders.cancel()
            permissionDenied = false
            return false
        }

        guard await reminders.requestPermission() else {
            permissionDenied = true
            await reminders.cancel()
            return false
        }

        do {
            try await reminders.schedule(minutesAfterMidnight: minutesAfterMidnight)
            permissionDenied = false
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Re-arms the reminder at launch if the setting says it should be on, so an
    /// app reinstall or a cleared notification centre does not quietly drop it.
    func restoreReminder(settings: AppSettings) async {
        guard settings.medicationTrackingEnabled, settings.medicationReminderEnabled else {
            await reminders.cancel()
            return
        }
        guard await reminders.isAuthorised() else {
            permissionDenied = true
            return
        }
        try? await reminders.schedule(minutesAfterMidnight: settings.medicationReminderMinutes)
    }

    static func timeLabel(minutesAfterMidnight: Int) -> String {
        var components = DateComponents()
        components.hour = minutesAfterMidnight / 60
        components.minute = minutesAfterMidnight % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
