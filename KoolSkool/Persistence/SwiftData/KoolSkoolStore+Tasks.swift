import Foundation
import SwiftData

extension KoolSkoolStore: TaskRepository {

    // MARK: Reads

    func tasks(includeCompleted: Bool) throws -> [FocusTask] {
        let predicate: Predicate<SDTask> = includeCompleted
            ? #Predicate<SDTask> { $0.deletedAt == nil }
            : #Predicate<SDTask> { $0.deletedAt == nil && $0.completedAt == nil }

        return try fetchAll(
            SDTask.self,
            predicate: predicate,
            sortBy: [
                SortDescriptor(\SDTask.sortOrder, order: .forward),
                SortDescriptor(\SDTask.createdAt, order: .reverse),
            ]
        ).map { $0.toDomain() }
    }

    func task(id: UUID) throws -> FocusTask? {
        try taskModel(id: id)?.toDomain()
    }

    /// Includes musts that have already been completed, so the Today screen can
    /// show them ticked off rather than making them vanish.
    func musts(on day: Date) throws -> [FocusTask] {
        try mustModels(on: day).map { $0.toDomain() }
    }

    // MARK: Writes

    @discardableResult
    func upsert(_ task: FocusTask) throws -> FocusTask {
        let stamp = now

        if let existing = try taskModel(id: task.id) {
            existing.apply(task)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDTask.make(from: task)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    @discardableResult
    func captureFromBrainDump(_ text: String) throws -> FocusTask {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RepositoryError.invalidInput("Nothing to capture.")
        }

        // Fresh captures land at the top of the inbox. Capture first, organise
        // never — nothing else about this task is asked for.
        let topmost = try fetchFirst(
            SDTask.self,
            predicate: #Predicate<SDTask> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDTask.sortOrder, order: .forward)]
        )

        let stamp = now
        let model = SDTask(
            createdAt: stamp,
            updatedAt: stamp,
            title: trimmed,
            sortOrder: (topmost?.sortOrder ?? 0) - 1
        )
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDelete(taskID: UUID) throws {
        guard let model = try taskModel(id: taskID) else {
            throw RepositoryError.notFound(entity: "task", id: taskID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        for step in model.steps ?? [] where step.deletedAt == nil {
            step.deletedAt = stamp
            step.updatedAt = stamp
        }
        try persist()
    }

    func complete(taskID: UUID, at date: Date, actualMinutes: Int?) throws {
        guard let model = try taskModel(id: taskID) else {
            throw RepositoryError.notFound(entity: "task", id: taskID)
        }
        model.completedAt = date
        if let actualMinutes {
            // Accumulate: a task completed across several sessions should end up
            // with the total, which is what estimate calibration needs.
            model.actualMinutes = (model.actualMinutes ?? 0) + actualMinutes
        }
        model.updatedAt = now
        try persist()
    }

    func reopen(taskID: UUID) throws {
        guard let model = try taskModel(id: taskID) else {
            throw RepositoryError.notFound(entity: "task", id: taskID)
        }
        model.completedAt = nil
        model.updatedAt = now
        try persist()
    }

    func setMust(taskID: UUID, day: Date?) throws {
        guard let model = try taskModel(id: taskID) else {
            throw RepositoryError.notFound(entity: "task", id: taskID)
        }

        guard let day else {
            model.mustForDate = nil
            model.updatedAt = now
            try persist()
            return
        }

        let normalized = startOfDay(day)

        // Only open musts count toward the cap. Finishing one frees a slot —
        // the point of the rule is never to face more than three at once, not
        // to ration how much you are allowed to do.
        let openMusts = try mustModels(on: normalized)
            .filter { $0.id != taskID && $0.completedAt == nil }

        guard openMusts.count < TaskRules.mustLimit else {
            throw RepositoryError.mustLimitReached(limit: TaskRules.mustLimit)
        }

        model.mustForDate = normalized
        model.updatedAt = now
        try persist()
    }

    // MARK: Steps

    @discardableResult
    func upsertStep(_ step: TaskStep) throws -> TaskStep {
        let stamp = now

        if let existing = try stepModel(id: step.id) {
            existing.apply(step)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        guard let parent = try taskModel(id: step.taskID) else {
            throw RepositoryError.notFound(entity: "task", id: step.taskID)
        }

        let model = SDTaskStep.make(from: step, task: parent)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDeleteStep(stepID: UUID) throws {
        guard let model = try stepModel(id: stepID) else {
            throw RepositoryError.notFound(entity: "step", id: stepID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        try persist()
    }

    func replaceSteps(taskID: UUID, titles: [String]) throws {
        guard let parent = try taskModel(id: taskID) else {
            throw RepositoryError.notFound(entity: "task", id: taskID)
        }

        let stamp = now

        for existing in parent.steps ?? [] where existing.deletedAt == nil {
            existing.deletedAt = stamp
            existing.updatedAt = stamp
        }

        for (index, title) in titles.enumerated() {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let step = SDTaskStep(
                createdAt: stamp,
                updatedAt: stamp,
                title: trimmed,
                order: index,
                task: parent
            )
            modelContext.insert(step)
        }

        parent.updatedAt = stamp
        try persist()
    }

    // MARK: Model lookups

    private func taskModel(id: UUID) throws -> SDTask? {
        try fetchFirst(SDTask.self, predicate: #Predicate<SDTask> { $0.id == id })
    }

    private func stepModel(id: UUID) throws -> SDTaskStep? {
        try fetchFirst(SDTaskStep.self, predicate: #Predicate<SDTaskStep> { $0.id == id })
    }

    /// Tasks flagged as a must for the local day containing `day`.
    ///
    /// The day window is applied in Swift rather than in the predicate. Ranged
    /// comparison against an optional `Date` inside `#Predicate` needs either a
    /// force unwrap or nil-coalescing, and a task carrying a must flag is a
    /// handful of rows — three a day — so filtering in memory costs nothing and
    /// removes a whole class of predicate bugs.
    private func mustModels(on day: Date) throws -> [SDTask] {
        let range = dayRange(containing: day)
        let flagged = try fetchAll(
            SDTask.self,
            predicate: #Predicate<SDTask> { $0.deletedAt == nil && $0.mustForDate != nil },
            sortBy: [SortDescriptor(\SDTask.sortOrder, order: .forward)]
        )
        return flagged.filter { model in
            guard let mustDate = model.mustForDate else { return false }
            return range.contains(mustDate)
        }
    }
}
