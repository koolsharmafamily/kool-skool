import ActivityKit
import Foundation

/// The Live Activity for a running focus session.
///
/// It carries dates, not a countdown. The lock screen and the Dynamic Island
/// render the timer themselves from `startedAt` and `plannedEnd`, so the app
/// never has to push an update while a session runs — the same "nothing counts
/// down" rule the focus engine is built on, applied outside the app.
struct FocusActivityAttributes: ActivityAttributes, Hashable, Sendable {

    struct ContentState: Codable, Hashable, Sendable {
        var startedAt: Date
        /// Nil for Flowmodoro, which counts up and has no planned end.
        var plannedEnd: Date?
    }

    var sessionID: UUID
    var modeName: String
    /// Shown because this is a session the user started moments ago. Always-on
    /// surfaces such as Lock Screen widgets never show task text.
    var taskTitle: String?
}

extension FocusActivityAttributes.ContentState {
    var countsUp: Bool { plannedEnd == nil }

    /// Never a backwards range: `ClosedRange` traps on one, and a Live Activity
    /// crash takes the whole extension down with it.
    var timerRange: ClosedRange<Date> {
        startedAt...max(startedAt, plannedEnd ?? startedAt)
    }
}
