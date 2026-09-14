import ActivityKit
import Foundation

/// Starts and ends the Live Activity for a focus session.
///
/// Behind a protocol so the engine is testable without ActivityKit, which does
/// not run in unit tests.
@MainActor
protocol SessionLiveActivityManaging: AnyObject {
    func start(_ content: FocusActivityContent) async
    func end(sessionID: UUID) async
}

/// The mapping from a session to what the Live Activity shows. Pure.
struct FocusActivityContent: Equatable, Sendable {
    var attributes: FocusActivityAttributes
    var state: FocusActivityAttributes.ContentState

    /// Marks the activity stale at the planned end, so a session that runs out
    /// while the app is closed reads "time's up" rather than a frozen 0:00.
    var staleDate: Date? { state.plannedEnd }

    static func make(for session: FocusSession, taskTitle: String?) -> FocusActivityContent {
        let countsUp = session.mode.defaultProfile.countsUp || session.plannedDuration <= 0
        let trimmed = taskTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return FocusActivityContent(
            attributes: FocusActivityAttributes(
                sessionID: session.id,
                modeName: session.mode.displayName,
                taskTitle: trimmed.isEmpty ? nil : trimmed
            ),
            state: FocusActivityAttributes.ContentState(
                startedAt: session.startedAt,
                plannedEnd: countsUp ? nil : session.startedAt.addingTimeInterval(session.plannedDuration)
            )
        )
    }
}

/// What to do with whatever activities already exist when a session starts.
///
/// Relaunching mid-session calls `start` again for the same session, and that
/// must update the existing activity rather than stack a second one on the Lock
/// Screen. Anything left over from another session has already ended.
enum LiveActivityReconciler {
    struct Plan: Equatable, Sendable {
        var update: UUID?
        var request: Bool
        var end: [UUID]
    }

    static func plan(existing: [UUID], desired: UUID) -> Plan {
        let alreadyShowing = existing.contains(desired)
        return Plan(
            update: alreadyShowing ? desired : nil,
            request: !alreadyShowing,
            end: existing.filter { $0 != desired }
        )
    }
}

@MainActor
final class ActivityKitLiveActivityManager: SessionLiveActivityManaging {
    init() {}

    func start(_ content: FocusActivityContent) async {
        // Someone who switched Live Activities off in Settings gets none.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let activities = Activity<FocusActivityAttributes>.activities
        let plan = LiveActivityReconciler.plan(
            existing: activities.map { $0.attributes.sessionID },
            desired: content.attributes.sessionID
        )

        for activity in activities where plan.end.contains(activity.attributes.sessionID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let activityContent = ActivityContent(state: content.state, staleDate: content.staleDate)

        if let id = plan.update, let existing = activities.first(where: { $0.attributes.sessionID == id }) {
            await existing.update(activityContent)
        }

        if plan.request {
            // A Live Activity that fails to start costs the session nothing.
            _ = try? Activity.request(attributes: content.attributes, content: activityContent, pushType: nil)
        }
    }

    /// Dismissed immediately: a session only ever finishes with the app in the
    /// foreground, where the completion screen has already replaced it.
    func end(sessionID: UUID) async {
        for activity in Activity<FocusActivityAttributes>.activities where activity.attributes.sessionID == sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor
final class NoOpLiveActivityManager: SessionLiveActivityManaging {
    init() {}
    func start(_ content: FocusActivityContent) async {}
    func end(sessionID: UUID) async {}
}

@MainActor
final class RecordingLiveActivityManager: SessionLiveActivityManaging {
    private(set) var started: [FocusActivityContent] = []
    private(set) var ended: [UUID] = []

    init() {}

    func start(_ content: FocusActivityContent) async {
        started.append(content)
    }

    func end(sessionID: UUID) async {
        ended.append(sessionID)
    }
}
