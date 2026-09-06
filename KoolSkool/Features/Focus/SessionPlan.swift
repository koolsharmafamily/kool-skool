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
    /// The commitment card. Written in Milestone 6; the field is here so the
    /// session record does not need changing then.
    var commitment: String

    init(
        mode: SessionMode,
        plannedDuration: TimeInterval,
        intent: String = "",
        resistance: Rating? = nil,
        taskID: UUID? = nil,
        commitment: String = ""
    ) {
        self.mode = mode
        self.plannedDuration = plannedDuration
        self.intent = intent
        self.resistance = resistance
        self.taskID = taskID
        self.commitment = commitment
    }

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
