import Foundation
import SwiftData

@Model
final class SDFocusSession {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var modeRaw: String = SessionMode.justStart.rawValue

    /// The anchor for all elapsed-time maths. Never recomputed.
    var startedAt: Date = Date.distantPast
    var plannedDuration: TimeInterval = 0
    var endedAt: Date?
    var wasCompleted: Bool = false

    var intent: String = ""
    var commitment: String = ""
    var resistanceRaw: Int?

    var xpAwarded: Int = 0
    var coinsAwarded: Int = 0
    var earnedBonus: Bool = false

    var taskID: UUID?

    var lastHeartbeatAt: Date?
    var endReasonRaw: String?

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .justStart }
        set { modeRaw = newValue.rawValue }
    }

    var endReason: SessionEndReason? {
        get { endReasonRaw.flatMap(SessionEndReason.init(rawValue:)) }
        set { endReasonRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        modeRaw: String = SessionMode.justStart.rawValue,
        startedAt: Date = .now,
        plannedDuration: TimeInterval = 0,
        endedAt: Date? = nil,
        wasCompleted: Bool = false,
        intent: String = "",
        commitment: String = "",
        resistanceRaw: Int? = nil,
        xpAwarded: Int = 0,
        coinsAwarded: Int = 0,
        earnedBonus: Bool = false,
        taskID: UUID? = nil,
        lastHeartbeatAt: Date? = nil,
        endReasonRaw: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.modeRaw = modeRaw
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
        self.intent = intent
        self.commitment = commitment
        self.resistanceRaw = resistanceRaw
        self.xpAwarded = xpAwarded
        self.coinsAwarded = coinsAwarded
        self.earnedBonus = earnedBonus
        self.taskID = taskID
        self.lastHeartbeatAt = lastHeartbeatAt
        self.endReasonRaw = endReasonRaw
    }
}

@Model
final class SDCheckIn {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var timestamp: Date = Date.distantPast
    var energyRaw: Int?
    var moodRaw: Int?
    var phaseRaw: String = CheckInPhase.pre.rawValue
    var sessionID: UUID?

    var phase: CheckInPhase {
        get { CheckInPhase(rawValue: phaseRaw) ?? .pre }
        set { phaseRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        timestamp: Date = .now,
        energyRaw: Int? = nil,
        moodRaw: Int? = nil,
        phaseRaw: String = CheckInPhase.pre.rawValue,
        sessionID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.timestamp = timestamp
        self.energyRaw = energyRaw
        self.moodRaw = moodRaw
        self.phaseRaw = phaseRaw
        self.sessionID = sessionID
    }
}

@Model
final class SDMedicationLog {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var timestamp: Date = Date.distantPast
    var taken: Bool = true
    var note: String = ""

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        timestamp: Date = .now,
        taken: Bool = true,
        note: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.timestamp = timestamp
        self.taken = taken
        self.note = note
    }
}

// MARK: - Mapping

extension SDFocusSession {
    func toDomain() -> FocusSession {
        FocusSession(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            mode: mode,
            startedAt: startedAt,
            plannedDuration: plannedDuration,
            endedAt: endedAt,
            wasCompleted: wasCompleted,
            intent: intent,
            commitment: commitment,
            resistanceAtStart: resistanceRaw.map { Rating(clamping: $0) },
            xpAwarded: xpAwarded,
            coinsAwarded: coinsAwarded,
            taskID: taskID,
            earnedBonus: earnedBonus,
            lastHeartbeatAt: lastHeartbeatAt,
            endReason: endReason
        )
    }

    func apply(_ dto: FocusSession) {
        modeRaw = dto.mode.rawValue
        startedAt = dto.startedAt
        plannedDuration = dto.plannedDuration
        endedAt = dto.endedAt
        wasCompleted = dto.wasCompleted
        intent = dto.intent
        commitment = dto.commitment
        resistanceRaw = dto.resistanceAtStart?.rawValue
        xpAwarded = dto.xpAwarded
        coinsAwarded = dto.coinsAwarded
        earnedBonus = dto.earnedBonus
        taskID = dto.taskID
        lastHeartbeatAt = dto.lastHeartbeatAt
        endReasonRaw = dto.endReason?.rawValue
        deletedAt = dto.deletedAt
    }

    static func make(from dto: FocusSession) -> SDFocusSession {
        SDFocusSession(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            modeRaw: dto.mode.rawValue,
            startedAt: dto.startedAt,
            plannedDuration: dto.plannedDuration,
            endedAt: dto.endedAt,
            wasCompleted: dto.wasCompleted,
            intent: dto.intent,
            commitment: dto.commitment,
            resistanceRaw: dto.resistanceAtStart?.rawValue,
            xpAwarded: dto.xpAwarded,
            coinsAwarded: dto.coinsAwarded,
            earnedBonus: dto.earnedBonus,
            taskID: dto.taskID,
            lastHeartbeatAt: dto.lastHeartbeatAt,
            endReasonRaw: dto.endReason?.rawValue
        )
    }
}

extension SDCheckIn {
    func toDomain() -> CheckIn {
        CheckIn(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            timestamp: timestamp,
            energy: energyRaw.map { Rating(clamping: $0) },
            mood: moodRaw.map { Rating(clamping: $0) },
            phase: phase,
            sessionID: sessionID
        )
    }

    func apply(_ dto: CheckIn) {
        timestamp = dto.timestamp
        energyRaw = dto.energy?.rawValue
        moodRaw = dto.mood?.rawValue
        phaseRaw = dto.phase.rawValue
        sessionID = dto.sessionID
        deletedAt = dto.deletedAt
    }

    static func make(from dto: CheckIn) -> SDCheckIn {
        SDCheckIn(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            timestamp: dto.timestamp,
            energyRaw: dto.energy?.rawValue,
            moodRaw: dto.mood?.rawValue,
            phaseRaw: dto.phase.rawValue,
            sessionID: dto.sessionID
        )
    }
}

extension SDMedicationLog {
    func toDomain() -> MedicationLog {
        MedicationLog(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            timestamp: timestamp,
            taken: taken,
            note: note
        )
    }

    func apply(_ dto: MedicationLog) {
        timestamp = dto.timestamp
        taken = dto.taken
        note = dto.note
        deletedAt = dto.deletedAt
    }

    static func make(from dto: MedicationLog) -> SDMedicationLog {
        SDMedicationLog(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            timestamp: dto.timestamp,
            taken: dto.taken,
            note: dto.note
        )
    }
}
