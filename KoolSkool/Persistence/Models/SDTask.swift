import Foundation
import SwiftData

// Conventions for every `SD*` model in this folder:
//
// 1. No `@Attribute(.unique)`. Unique constraints are incompatible with
//    CloudKit, and v1 should not close that door. Uniqueness of `id` is
//    guaranteed by the repositories instead.
// 2. Every stored property has a default value and every relationship is
//    optional, for the same reason.
// 3. Enums are stored as their raw `String` and exposed through a computed
//    property. SwiftData predicates against stored enums are unreliable;
//    predicates against strings are not.
// 4. These types never leave the persistence layer. Repositories map them to
//    the `Sendable` structs in `Domain/Entities`.

@Model
final class SDTask {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var title: String = ""
    var notes: String = ""
    var nextStep: String = ""

    var estimateMinutes: Int?
    var actualMinutes: Int?
    var resistanceRaw: Int?

    var mustForDate: Date?
    var completedAt: Date?
    var sortOrder: Int = 0

    /// Steps are a true composition: they have no meaning without their task,
    /// so this is a real relationship with a cascade. Every other association in
    /// the schema is a plain `UUID` foreign key, which travels better over a
    /// future sync boundary.
    @Relationship(deleteRule: .cascade, inverse: \SDTaskStep.task)
    var steps: [SDTaskStep]? = []

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        title: String = "",
        notes: String = "",
        nextStep: String = "",
        estimateMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        resistanceRaw: Int? = nil,
        mustForDate: Date? = nil,
        completedAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.title = title
        self.notes = notes
        self.nextStep = nextStep
        self.estimateMinutes = estimateMinutes
        self.actualMinutes = actualMinutes
        self.resistanceRaw = resistanceRaw
        self.mustForDate = mustForDate
        self.completedAt = completedAt
        self.sortOrder = sortOrder
        self.steps = []
    }
}

@Model
final class SDTaskStep {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var title: String = ""
    var order: Int = 0
    var isDone: Bool = false
    var completedAt: Date?

    var task: SDTask?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        title: String = "",
        order: Int = 0,
        isDone: Bool = false,
        completedAt: Date? = nil,
        task: SDTask? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.title = title
        self.order = order
        self.isDone = isDone
        self.completedAt = completedAt
        self.task = task
    }
}

// MARK: - Mapping

extension SDTask {
    func toDomain() -> FocusTask {
        FocusTask(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            title: title,
            notes: notes,
            nextStep: nextStep,
            estimateMinutes: estimateMinutes,
            actualMinutes: actualMinutes,
            resistance: resistanceRaw.map { Rating(clamping: $0) },
            mustForDate: mustForDate,
            completedAt: completedAt,
            sortOrder: sortOrder,
            steps: (steps ?? [])
                .filter { $0.deletedAt == nil }
                .sorted { $0.order < $1.order }
                .map { $0.toDomain() }
        )
    }

    /// Copies the mutable fields across. `id` and `createdAt` are immutable
    /// after insert; `steps` are managed through the step methods so a stale
    /// snapshot cannot wipe them.
    func apply(_ dto: FocusTask) {
        title = dto.title
        notes = dto.notes
        nextStep = dto.nextStep
        estimateMinutes = dto.estimateMinutes
        actualMinutes = dto.actualMinutes
        resistanceRaw = dto.resistance?.rawValue
        mustForDate = dto.mustForDate
        completedAt = dto.completedAt
        sortOrder = dto.sortOrder
        deletedAt = dto.deletedAt
    }

    static func make(from dto: FocusTask) -> SDTask {
        SDTask(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            title: dto.title,
            notes: dto.notes,
            nextStep: dto.nextStep,
            estimateMinutes: dto.estimateMinutes,
            actualMinutes: dto.actualMinutes,
            resistanceRaw: dto.resistance?.rawValue,
            mustForDate: dto.mustForDate,
            completedAt: dto.completedAt,
            sortOrder: dto.sortOrder
        )
    }
}

extension SDTaskStep {
    func toDomain() -> TaskStep {
        TaskStep(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            taskID: task?.id ?? UUID(),
            title: title,
            order: order,
            isDone: isDone,
            completedAt: completedAt
        )
    }

    func apply(_ dto: TaskStep) {
        title = dto.title
        order = dto.order
        isDone = dto.isDone
        completedAt = dto.completedAt
        deletedAt = dto.deletedAt
    }

    static func make(from dto: TaskStep, task: SDTask?) -> SDTaskStep {
        SDTaskStep(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            title: dto.title,
            order: dto.order,
            isDone: dto.isDone,
            completedAt: dto.completedAt,
            task: task
        )
    }
}
