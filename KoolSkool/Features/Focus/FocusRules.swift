import Foundation

/// The numbers that govern session lifecycle. Collected here because most of
/// them are judgement calls that deserve to be visible and easy to change.
enum FocusRules {

    /// How much of a count-down session must run before ending early still
    /// counts as completed.
    ///
    /// The escape hatch has to be honest and non-punishing. Stopping at 24 of 25
    /// minutes is a finished Pomodoro by any reasonable reading, and treating it
    /// as a failure is exactly the shame mechanic this app refuses to use.
    static let completionThreshold: Double = 0.8

    /// Sessions shorter than this are discarded rather than recorded. A mis-tap
    /// should not leave litter in the history.
    static let minimumRecordableDuration: TimeInterval = 10

    /// Absolute ceiling on a count-up session recovered after the app was gone.
    ///
    /// Flowmodoro has no planned end, so there is nothing to bound it. Without
    /// a cap, a phone that dies during a session and gets charged overnight
    /// would credit twelve hours of deep work.
    static let maximumUnattendedCountUp: TimeInterval = 4 * 60 * 60

    /// How often a running session records that the app was still watching.
    static let heartbeatInterval: TimeInterval = 30

    /// How often the running session recomputes. The display is derived from
    /// wall-clock on every tick, so a missed tick costs nothing.
    static let tickInterval: TimeInterval = 1

    /// Longest gap the "keep going?" offer stays available after a Just Start
    /// session ends. Past this the moment has passed and the offer is stale.
    static let extensionOfferWindow: TimeInterval = 10 * 60
}
