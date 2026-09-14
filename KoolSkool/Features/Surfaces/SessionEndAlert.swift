import Foundation
import UserNotifications

/// What the session-end backstop would schedule, decided without touching the
/// notification centre so every branch is testable.
enum SessionEndAlert {
    static let identifierPrefix = "kool-skool.session-end."

    struct Plan: Equatable, Sendable {
        var identifier: String
        var fireDate: Date
        var title: String
        var body: String
    }

    /// Nil when there is nothing to back up: a count-up session has no planned
    /// end, and one whose end has already passed is handled on return.
    static func plan(for session: FocusSession, now: Date) -> Plan? {
        guard session.plannedDuration > 0, !session.mode.defaultProfile.countsUp else { return nil }

        let end = session.startedAt.addingTimeInterval(session.plannedDuration)
        guard end > now else { return nil }

        let minutes = max(1, Int((session.plannedDuration / 60).rounded()))
        return Plan(
            identifier: identifier(for: session.id),
            fireDate: end,
            title: "Time's up",
            // Plain, and never the task or the intent: a lock screen is readable
            // by whoever is standing nearby.
            body: "\(minutes) minute\(minutes == 1 ? "" : "s") of focus, done. Tap to wrap it up."
        )
    }

    static func identifier(for sessionID: UUID) -> String {
        identifierPrefix + sessionID.uuidString
    }

    /// Cancelling session alerts must never take the medication reminder with it.
    static func isSessionEnd(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }
}

/// The local-notification backstop for when the app is not on screen when a
/// session ends. Schedules only when notifications are already allowed — it
/// never prompts, because the moment a session starts is the worst possible
/// moment to interrupt someone with a permission dialog.
struct LocalSessionAlertScheduler: SessionAlertScheduling {
    private let clock: any DateProvider

    init(clock: any DateProvider = SystemDateProvider()) {
        self.clock = clock
    }

    func scheduleEnd(for session: FocusSession) async {
        guard let plan = SessionEndAlert.plan(for: session, now: clock.now) else { return }
        guard await NotificationAuthorization.status() == .authorised else { return }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        let interval = max(1, plan.fireDate.timeIntervalSince(clock.now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Clears pending *and* delivered session alerts, so ending early leaves
    /// nothing behind and opening the app after one fired tidies it away.
    func cancelAll() async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
            .map { $0.identifier }
            .filter { SessionEndAlert.isSessionEnd($0) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        let delivered = await center.deliveredNotifications()
            .map { $0.request.identifier }
            .filter { SessionEndAlert.isSessionEnd($0) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }
}

/// Decides how a notification appears while the app is open.
///
/// A session-end alert arriving while the app is on screen would duplicate the
/// completion screen, so it is suppressed. The medication reminder still shows.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    /// The notification centre holds its delegate weakly, so something has to
    /// keep this alive for the life of the process.
    static let shared = NotificationPresenter()

    @MainActor
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundOptions(for: notification.request.identifier)
    }

    static func foregroundOptions(for identifier: String) -> UNNotificationPresentationOptions {
        SessionEndAlert.isSessionEnd(identifier) ? [] : [.banner, .list, .sound]
    }
}
