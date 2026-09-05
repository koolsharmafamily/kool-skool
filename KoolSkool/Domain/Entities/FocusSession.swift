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
}

/// A two-tap energy and mood reading, taken either side of a session.
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
