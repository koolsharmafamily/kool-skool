import Foundation
import SwiftData

extension KoolSkoolStore: StillnessRepository {

    func practices() throws -> [Practice] {
        try fetchAll(
            SDPractice.self,
            predicate: #Predicate<SDPractice> { $0.deletedAt == nil },
            sortBy: [
                SortDescriptor(\SDPractice.requiredCompletedSits, order: .forward),
                SortDescriptor(\SDPractice.title, order: .forward),
            ]
        ).map { $0.toDomain() }
    }

    func practice(id: UUID) throws -> Practice? {
        try practiceModel(id: id)?.toDomain()
    }

    /// The bundled catalogue uses stable UUIDs, so reseeding after an app update
    /// refreshes copy and durations in place rather than duplicating rows.
    func seedPracticesIfNeeded(_ practices: [Practice]) throws {
        let stamp = now

        for practice in practices {
            if let existing = try practiceModel(id: practice.id) {
                existing.apply(practice)
                existing.updatedAt = stamp
            } else {
                let model = SDPractice.make(from: practice)
                model.createdAt = stamp
                model.updatedAt = stamp
                modelContext.insert(model)
            }
        }

        try persist()
    }

    func sits(in range: Range<Date>) throws -> [StillnessSession] {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDStillnessSession.self,
            predicate: #Predicate<SDStillnessSession> {
                $0.deletedAt == nil && $0.startedAt >= lower && $0.startedAt < upper
            },
            sortBy: [SortDescriptor(\SDStillnessSession.startedAt, order: .reverse)]
        ).map { $0.toDomain() }
    }

    func recentSits(limit: Int) throws -> [StillnessSession] {
        try fetchAll(
            SDStillnessSession.self,
            predicate: #Predicate<SDStillnessSession> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDStillnessSession.startedAt, order: .reverse)],
            limit: max(0, limit)
        ).map { $0.toDomain() }
    }

    /// Gates open awareness, which unlocks after twenty completed sits.
    func completedSitCount() throws -> Int {
        try fetchAll(
            SDStillnessSession.self,
            predicate: #Predicate<SDStillnessSession> { $0.deletedAt == nil && $0.completed }
        ).count
    }

    func completedSitDays(since: Date) throws -> [Date] {
        let lower = since
        let models = try fetchAll(
            SDStillnessSession.self,
            predicate: #Predicate<SDStillnessSession> {
                $0.deletedAt == nil && $0.completed && $0.startedAt >= lower
            },
            sortBy: [SortDescriptor(\SDStillnessSession.startedAt, order: .reverse)]
        )
        return distinctDays(from: models.map(\.startedAt))
    }

    @discardableResult
    func upsert(_ sit: StillnessSession) throws -> StillnessSession {
        let stamp = now

        if let existing = try fetchFirst(SDStillnessSession.self, predicate: #Predicate<SDStillnessSession> { $0.id == sit.id }) {
            existing.apply(sit)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDStillnessSession.make(from: sit)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDelete(sitID: UUID) throws {
        guard let model = try fetchFirst(SDStillnessSession.self, predicate: #Predicate<SDStillnessSession> { $0.id == sitID }) else {
            throw RepositoryError.notFound(entity: "sit", id: sitID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        try persist()
    }

    private func practiceModel(id: UUID) throws -> SDPractice? {
        try fetchFirst(SDPractice.self, predicate: #Predicate<SDPractice> { $0.id == id })
    }
}

// MARK: - Reflections

extension KoolSkoolStore: ReflectionRepository {

    func reflection(on day: Date) throws -> Reflection? {
        try reflectionModel(on: day)?.toDomain()
    }

    func reflections(in range: Range<Date>) throws -> [Reflection] {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDReflection.self,
            predicate: #Predicate<SDReflection> {
                $0.deletedAt == nil && $0.day >= lower && $0.day < upper
            },
            sortBy: [SortDescriptor(\SDReflection.day, order: .reverse)]
        ).map { $0.toDomain() }
    }

    /// One reflection per day. Matching is by day rather than by id, so the
    /// morning intention and the evening close land in the same row even though
    /// they are written hours apart from different screens.
    @discardableResult
    func upsert(_ reflection: Reflection) throws -> Reflection {
        let stamp = now
        let normalizedDay = startOfDay(reflection.day)

        if let existing = try reflectionModel(on: normalizedDay) {
            existing.apply(reflection)
            existing.day = normalizedDay
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDReflection.make(from: reflection)
        model.day = normalizedDay
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    private func reflectionModel(on day: Date) throws -> SDReflection? {
        let range = dayRange(containing: day)
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchFirst(
            SDReflection.self,
            predicate: #Predicate<SDReflection> {
                $0.deletedAt == nil && $0.day >= lower && $0.day < upper
            },
            sortBy: [SortDescriptor(\SDReflection.day, order: .forward)]
        )
    }
}
