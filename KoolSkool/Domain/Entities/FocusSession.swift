import Foundation

/// One focus interval, from the moment Start is tapped.
///
/// Timer correctness note: the only source of truth for elapsed time is
/// `startedAt` compared against wall-clock now. Nothing here decrements. That is
/// what makes a session survive backgrounding, force quit, and device restart.
struct FocusSession: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var mode: SessionMode = .justStart
    var startedAt: Date = .now

    /// Zero for count-up modes (Flowmodoro).
    var plannedDuration: TimeInterval = 0

    var endedAt: Date?

    /// True only when the session ran to its planned end, or — for count-up
    /// modes — was ended deliberately by the user rather than abandoned.
    var wasCompleted: Bool = false

    /// What does done look like? Set in the pre-session ritual.
    var intent: String = ""

    /// The commitment card text, stated before the session and shown back at
    /// the end.
    var commitment: String = ""

    var resistanceAtStart: Rating?

    var xpAwarded: Int = 0
    var coinsAwarded: Int = 0

    var taskID: UUID?

    /// Whether this session produced a bonus chest.
    var earnedBonus: Bool = false

    /// Last moment the app was known to be watching this session.
    ///
    /// Only count-up modes need it. A Flowmodoro session has no planned end, so
    /// if the phone dies mid-session there is otherwise nothing to distinguish
    /// "worked for four hours" from "started one and went to bed". On restore
    /// the heartbeat is the last defensible end point.
    var lastHeartbeatAt: Date?

    /// How the session finished. Nil while it is still running.
    var endReason: SessionEndReason?

    /// Wall-clock elapsed time as of `date`, never negative.
    func elapsed(asOf date: Date) -> TimeInterval {
        let end = endedAt ?? date
        return max(0, end.timeIntervalSince(startedAt))
    }

    /// Remaining time for count-down modes. Negative once the session overruns,
    /// which the ambient colour shift uses.
    func remaining(asOf date: Date) -> TimeInterval {
        plannedDuration - elapsed(asOf: date)
    }

    /// 0...1 for the depleting disc. Clamped, so an overrun holds at full.
    func progress(asOf date: Date) -> Double {
        guard plannedDuration > 0 else { return 0 }
        return min(max(elapsed(asOf: date) / plannedDuration, 0), 1)
    }

    var isRunning: Bool { endedAt == nil }

    var actualMinutes: Int {
        guard let endedAt else { return 0 }
        return Int(max(0, endedAt.timeIntervalSince(startedAt)) / 60)
    }

    /// True once the planned end has passed. Always false for count-up modes,
    /// which have no planned end.
    func hasReachedPlannedEnd(asOf date: Date) -> Bool {
        plannedDuration > 0 && elapsed(asOf: date) >= plannedDuration
    }
}

/// Why a session stopped. Persisted, because "how do my sessions actually end"
/// is exactly what the Insights screen will want to answer.
enum SessionEndReason: String, Codable, CaseIterable, Sendable {
    /// Ran to its planned end with the app watching.
    case reachedPlannedEnd
    /// The user tapped the escape hatch.
    case endedByUser
    /// The planned end passed while the app was backgrounded or closed. The
    /// session is credited, ended at its planned end rather than at the moment
    /// the app happened to come back.
    case finishedWhileAway
    /// A count-up session was left running far too long to be believable and
    /// was closed at its last heartbeat.
    case cappedAfterHeartbeat

    /// Whether this counts as a completed session for streaks and rewards.
    var countsAsCompleted: Bool {
        switch self {
        case .reachedPlannedEnd, .finishedWhileAway: true
        case .endedByUser, .cappedAfterHeartbeat: false
        }
    }
}

/// A reading taken either side of a session.
///
/// Before: energy and mood, two taps. After: one tap, "how did that go?" —
/// stored as `focusQuality` rather than squeezed into `mood`, because it is a
/// different question and it is the one the Insights energy curve is built on.
///
/// Every field is optional, and every check-in is skippable. A check-in the
/// app has to nag for is data it should not have.
struct CheckIn: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var timestamp: Date = .now
    var energy: Rating?
    var mood: Rating?
    var phase: CheckInPhase = .pre
    var sessionID: UUID?
    /// Post-session only.
    var focusQuality: Rating?

    var isEmpty: Bool { energy == nil && mood == nil && focusQuality == nil }
}

/// A log entry, and only a log entry.
///
/// Deliberately has no drug database, no interaction checking, and no dose
/// guidance. Kool Skool is not a medical device.
struct MedicationLog: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var timestamp: Date = .now
    var taken: Bool = true
    var note: String = ""
}
