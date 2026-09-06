import UIKit

/// Keeps the screen awake while a session is on display.
///
/// Wrapped in a protocol so the engine can be tested without UIKit, and so the
/// setting can be honoured in exactly one place.
@MainActor
protocol ScreenIdleGuarding: AnyObject {
    func setKeepAwake(_ enabled: Bool)
}

@MainActor
final class ScreenIdleGuard: ScreenIdleGuarding {
    init() {}

    func setKeepAwake(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}

@MainActor
final class NoOpScreenIdleGuard: ScreenIdleGuarding {
    private(set) var isKeepingAwake = false

    init() {}

    func setKeepAwake(_ enabled: Bool) {
        isKeepingAwake = enabled
    }
}
