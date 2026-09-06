import Foundation

/// Schedules the local notification that fires when a session's planned end
/// arrives, as a backstop for when the app is not on screen.
///
/// The real `UNUserNotificationCenter` implementation lands in Milestone 9 along
/// with Live Activities and widgets, because that is where the permission prompt
/// belongs. The seam exists now so the engine's cancel-on-early-end path is
/// written and tested from the start rather than bolted on later.
protocol SessionAlertScheduling: Sendable {
    func scheduleEnd(for session: FocusSession) async
    func cancelAll() async
}

struct NoOpSessionAlertScheduler: SessionAlertScheduling {
    init() {}
    func scheduleEnd(for session: FocusSession) async {}
    func cancelAll() async {}
}

/// Records what it was asked to do, so the engine's scheduling and cancelling
/// can be asserted in tests.
final class RecordingSessionAlertScheduler: SessionAlertScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _scheduled: [UUID] = []
    private var _cancelCount = 0

    init() {}

    var scheduled: [UUID] {
        lock.lock(); defer { lock.unlock() }
        return _scheduled
    }

    var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _cancelCount
    }

    func scheduleEnd(for session: FocusSession) async {
        lock.lock(); _scheduled.append(session.id); lock.unlock()
    }

    func cancelAll() async {
        lock.lock(); _cancelCount += 1; lock.unlock()
    }
}
