import Foundation
import SwiftData

@Model
final class SDStillnessSession {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var practiceTypeRaw: String = PracticeType.boxBreathing.rawValue
    var practiceID: UUID?

    var startedAt: Date = Date.distantPast
    var durationSeconds: Int = 0
    var completed: Bool = false

    var traditionRaw: String = Tradition.secular.rawValue
    var focusSessionID: UUID?

    var practiceType: PracticeType {
        get { PracticeType(rawValue: practiceTypeRaw) ?? .boxBreathing }
        set { practiceTypeRaw = newValue.rawValue }
    }

    var tradition: Tradition {
        get { Tradition(rawValue: traditionRaw) ?? .secular }
        set { traditionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        practiceTypeRaw: String = PracticeType.boxBreathing.rawValue,
        practiceID: UUID? = nil,
        startedAt: Date = .now,
        durationSeconds: Int = 0,
        completed: Bool = false,
        traditionRaw: String = Tradition.secular.rawValue,
        focusSessionID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.practiceTypeRaw = practiceTypeRaw
        self.practiceID = practiceID
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.traditionRaw = traditionRaw
        self.focusSessionID = focusSessionID
    }
}

@Model
final class SDReflection {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    /// Local midnight. One row per day.
    var day: Date = Date.distantPast

    var morningIntention: String = ""
    var eveningWentWell: String = ""
    var eveningWasHard: String = ""
    var gratitude: String = ""

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        day: Date = .now,
        morningIntention: String = "",
        eveningWentWell: String = "",
        eveningWasHard: String = "",
        gratitude: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.day = day
        self.morningIntention = morningIntention
        self.eveningWentWell = eveningWentWell
        self.eveningWasHard = eveningWasHard
        self.gratitude = gratitude
    }
}

@Model
final class SDPractice {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var title: String = ""
    var subtitle: String = ""
    var typeRaw: String = PracticeType.boxBreathing.rawValue

    var durationOptionsSeconds: [Int] = []
    var audioAssetName: String?
    var scriptText: String = ""

    /// Present only for verbatim public-domain or explicitly licensed text.
    var attribution: String?

    var requiredLevel: Int = 0
    var requiredCompletedSits: Int = 0
    var traditionTagsRaw: [String] = []

    // Reserved for the v2 guided path.
    var programID: UUID?
    var orderInProgram: Int?

    var type: PracticeType {
        get { PracticeType(rawValue: typeRaw) ?? .boxBreathing }
        set { typeRaw = newValue.rawValue }
    }

    var traditionTags: [Tradition] {
        get { traditionTagsRaw.compactMap(Tradition.init(rawValue:)) }
        set { traditionTagsRaw = newValue.map(\.rawValue) }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        title: String = "",
        subtitle: String = "",
        typeRaw: String = PracticeType.boxBreathing.rawValue,
        durationOptionsSeconds: [Int] = [],
        audioAssetName: String? = nil,
        scriptText: String = "",
        attribution: String? = nil,
        requiredLevel: Int = 0,
        requiredCompletedSits: Int = 0,
        traditionTagsRaw: [String] = [],
        programID: UUID? = nil,
        orderInProgram: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.title = title
        self.subtitle = subtitle
        self.typeRaw = typeRaw
        self.durationOptionsSeconds = durationOptionsSeconds
        self.audioAssetName = audioAssetName
        self.scriptText = scriptText
        self.attribution = attribution
        self.requiredLevel = requiredLevel
        self.requiredCompletedSits = requiredCompletedSits
        self.traditionTagsRaw = traditionTagsRaw
        self.programID = programID
        self.orderInProgram = orderInProgram
    }
}

// MARK: - Mapping

extension SDStillnessSession {
    func toDomain() -> StillnessSession {
        StillnessSession(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            practiceType: practiceType,
            practiceID: practiceID,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            completed: completed,
            tradition: tradition,
            focusSessionID: focusSessionID
        )
    }

    func apply(_ dto: StillnessSession) {
        practiceTypeRaw = dto.practiceType.rawValue
        practiceID = dto.practiceID
        startedAt = dto.startedAt
        durationSeconds = dto.durationSeconds
        completed = dto.completed
        traditionRaw = dto.tradition.rawValue
        focusSessionID = dto.focusSessionID
        deletedAt = dto.deletedAt
    }

    static func make(from dto: StillnessSession) -> SDStillnessSession {
        SDStillnessSession(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            practiceTypeRaw: dto.practiceType.rawValue,
            practiceID: dto.practiceID,
            startedAt: dto.startedAt,
            durationSeconds: dto.durationSeconds,
            completed: dto.completed,
            traditionRaw: dto.tradition.rawValue,
            focusSessionID: dto.focusSessionID
        )
    }
}

extension SDReflection {
    func toDomain() -> Reflection {
        Reflection(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            day: day,
            morningIntention: morningIntention,
            eveningWentWell: eveningWentWell,
            eveningWasHard: eveningWasHard,
            gratitude: gratitude
        )
    }

    func apply(_ dto: Reflection) {
        day = dto.day
        morningIntention = dto.morningIntention
        eveningWentWell = dto.eveningWentWell
        eveningWasHard = dto.eveningWasHard
        gratitude = dto.gratitude
        deletedAt = dto.deletedAt
    }

    static func make(from dto: Reflection) -> SDReflection {
        SDReflection(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            day: dto.day,
            morningIntention: dto.morningIntention,
            eveningWentWell: dto.eveningWentWell,
            eveningWasHard: dto.eveningWasHard,
            gratitude: dto.gratitude
        )
    }
}

extension SDPractice {
    func toDomain() -> Practice {
        Practice(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            title: title,
            subtitle: subtitle,
            type: type,
            durationOptionsSeconds: durationOptionsSeconds,
            audioAssetName: audioAssetName,
            scriptText: scriptText,
            attribution: attribution,
            requiredLevel: requiredLevel,
            requiredCompletedSits: requiredCompletedSits,
            traditionTags: traditionTags,
            programID: programID,
            orderInProgram: orderInProgram
        )
    }

    func apply(_ dto: Practice) {
        title = dto.title
        subtitle = dto.subtitle
        typeRaw = dto.type.rawValue
        durationOptionsSeconds = dto.durationOptionsSeconds
        audioAssetName = dto.audioAssetName
        scriptText = dto.scriptText
        attribution = dto.attribution
        requiredLevel = dto.requiredLevel
        requiredCompletedSits = dto.requiredCompletedSits
        traditionTagsRaw = dto.traditionTags.map(\.rawValue)
        programID = dto.programID
        orderInProgram = dto.orderInProgram
        deletedAt = dto.deletedAt
    }

    static func make(from dto: Practice) -> SDPractice {
        SDPractice(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            title: dto.title,
            subtitle: dto.subtitle,
            typeRaw: dto.type.rawValue,
            durationOptionsSeconds: dto.durationOptionsSeconds,
            audioAssetName: dto.audioAssetName,
            scriptText: dto.scriptText,
            attribution: dto.attribution,
            requiredLevel: dto.requiredLevel,
            requiredCompletedSits: dto.requiredCompletedSits,
            traditionTagsRaw: dto.traditionTags.map(\.rawValue),
            programID: dto.programID,
            orderInProgram: dto.orderInProgram
        )
    }
}
