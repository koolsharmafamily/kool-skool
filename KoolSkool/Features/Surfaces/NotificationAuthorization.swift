import UserNotifications

enum NotificationStatus: Equatable, Sendable {
    case notDetermined
    case authorised
    case denied
}

/// The one place notification permission is read or asked for.
///
/// Shared by the medication reminder and the session-end backstop, so the two
/// can never disagree about whether notifications are allowed. Asking only ever
/// happens in answer to something the user just did.
enum NotificationAuthorization {

    static func status() async -> NotificationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return map(settings.authorizationStatus)
    }

    /// Prompts only if the user has never been asked. Returns whether
    /// notifications can be delivered afterwards.
    static func request() async -> Bool {
        switch await status() {
        case .authorised:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ?? false
        }
    }

    static func map(_ status: UNAuthorizationStatus) -> NotificationStatus {
        switch status {
        case .authorized, .provisional, .ephemeral: .authorised
        case .notDetermined: .notDetermined
        case .denied: .denied
        @unknown default: .denied
        }
    }
}
