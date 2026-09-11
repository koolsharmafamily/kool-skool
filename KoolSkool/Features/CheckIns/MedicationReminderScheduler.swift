import Foundation
import UserNotifications

/// The daily medication reminder.
///
/// This is the first place the app asks for notification permission, and it is
/// the right place: the user has just switched a reminder on, so the reason is
/// sitting right there on screen. The session-end backstop in Milestone 9 will
/// reuse whatever permission was granted here.
protocol MedicationReminderScheduling: Sendable {
    /// Asks once, in context. Returns whether reminders can be delivered.
    func requestPermission() async -> Bool
    func isAuthorised() async -> Bool
    func schedule(minutesAfterMidnight: Int) async throws
    func cancel() async
}

struct LocalMedicationReminderScheduler: MedicationReminderScheduling {
    static let identifier = "kool-skool.medication-reminder"

    /// What appears on the lock screen. Deliberately says nothing about
    /// medication: a lock screen is readable by anyone standing near the phone,
    /// and what someone takes is theirs to share or not.
    static let notificationTitle = "Kool Skool"
    static let notificationBody = "Your daily reminder."

    init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    func isAuthorised() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func schedule(minutesAfterMidnight: Int) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])

        let clamped = min(max(minutesAfterMidnight, 0), 24 * 60 - 1)
        var components = DateComponents()
        components.hour = clamped / 60
        components.minute = clamped % 60

        let content = UNMutableNotificationContent()
        content.title = Self.notificationTitle
        content.body = Self.notificationBody
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

/// Records calls instead of touching the notification centre.
final class RecordingReminderScheduler: MedicationReminderScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _scheduled: [Int] = []
    private var _cancelCount = 0
    private let grantsPermission: Bool

    init(grantsPermission: Bool = true) {
        self.grantsPermission = grantsPermission
    }

    var scheduled: [Int] {
        lock.lock(); defer { lock.unlock() }
        return _scheduled
    }

    var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _cancelCount
    }

    func requestPermission() async -> Bool { grantsPermission }
    func isAuthorised() async -> Bool { grantsPermission }

    func schedule(minutesAfterMidnight: Int) async throws {
        lock.lock(); _scheduled.append(minutesAfterMidnight); lock.unlock()
    }

    func cancel() async {
        lock.lock(); _cancelCount += 1; lock.unlock()
    }
}
