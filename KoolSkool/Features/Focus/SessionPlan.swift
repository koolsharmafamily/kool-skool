import Foundation

/// What the pre-session ritual produces. The whole screen exists to fill this
/// in, and it has to be fillable in about ten seconds — everything except the
/// mode is optional.
struct SessionPlan: Equatable, Sendable {
    var mode: SessionMode
    /// Resolved from the mode and, for `.custom`, from settings.
    var plannedDuration: TimeInterval
    /// What does done look like?
    var intent: String
    var resistance: Rating?
    var taskID: UUID?
    /// The commitment card, when it is switched on.
    var commitment: String
    /// The optional pre-session check-in. Saved as a separate `CheckIn` once
    /// the session exists, so a skipped check-in leaves no row at all.
    var energy: Rating?
    var mood: Rating?

    init(
        mode: SessionMode,
        plannedDuration: TimeInterval,
        intent: String = "",
        resistance: Rating? = nil,
        taskID: UUID? = nil,
        commitment: String = "",
        energy: Rating? = nil,
        mood: Rating? = nil
    ) {
        self.mode = mode
        self.plannedDuration = plannedDuration
        self.intent = intent
        self.resistance = resistance
        self.taskID = taskID
        self.commitment = commitment
        self.energy = energy
        self.mood = mood
    }

    var hasCheckIn: Bool { energy != nil || mood != nil }

    static func make(mode: SessionMode, settings: AppSettings) -> SessionPlan {
        let profile = settings.resolvedProfile(for: mode)
        return SessionPlan(mode: mode, plannedDuration: profile.workDuration)
    }

    func session(startedAt: Date) -> FocusSession {
        var session = FocusSession()
        session.mode = mode
        session.startedAt = startedAt
        session.plannedDuration = plannedDuration
        session.intent = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        session.commitment = commitment.trimmingCharacters(in: .whitespacesAndNewlines)
        session.resistanceAtStart = resistance
        session.taskID = taskID
        session.lastHeartbeatAt = startedAt
        return session
    }
}
