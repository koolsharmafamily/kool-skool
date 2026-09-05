import Foundation
import SwiftData

extension KoolSkoolStore: SessionRepository {

    func session(id: UUID) throws -> FocusSession? {
        try sessionModel(id: id)?.toDomain()
    }

    /// A session with no `endedAt` is still running, whatever the app did in
    /// between. This is the recovery path after a force quit or a restart: the
    /// store is asked, not an in-memory timer.
    func activeSession() throws -> FocusSession? {
        try fetchFirst(
            SDFocusSession.self,
            predicate: #Predicate<SDFocusSession> { $0.deletedAt == nil && $0.endedAt == nil },
            sortBy: [SortDescriptor(\SDFocusSession.startedAt, order: .reverse)]
        )?.toDomain()
    }

    func sessions(in range: Range<Date>) throws -> [FocusSession] {
        try sessionModels(in: range).map { $0.toDomain() }
    }

    func recentSessions(limit: Int) throws -> [FocusSession] {
        try fetchAll(
            SDFocusSession.self,
            predicate: #Predicate<SDFocusSession> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDFocusSession.startedAt, order: .reverse)],
            limit: max(0, limit)
        ).map { $0.toDomain() }
    }

    /// A day counts when it contains at least one completed session, of any
    /// length — a five-minute Just Start keeps a streak alive exactly as much as
    /// a 52-minute deep work block.
    ///
    /// A session belongs to the day it *started* on, so a block that runs
    /// through midnight credits the day the user actually sat down.
    func completedSessionDays(since: Date) throws -> [Date] {
        let lower = since
        let models = try fetchAll(
            SDFocusSession.self,
            predicate: #Predicate<SDFocusSession> {
                $0.deletedAt == nil && $0.wasCompleted && $0.startedAt >= lower
            },
            sortBy: [SortDescriptor(\SDFocusSession.startedAt, order: .reverse)]
        )
        return distinctDays(from: models.map(\.startedAt))
    }

    func completedSessionCount(in range: Range<Date>) throws -> Int {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDFocusSession.self,
            predicate: #Predicate<SDFocusSession> {
                $0.deletedAt == nil && $0.wasCompleted && $0.startedAt >= lower && $0.startedAt < upper
            }
        ).count
    }

    @discardableResult
    func upsert(_ session: FocusSession) throws -> FocusSession {
        let stamp = now

        if let existing = try sessionModel(id: session.id) {
            existing.apply(session)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDFocusSession.make(from: session)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDelete(sessionID: UUID) throws {
        guard let model = try sessionModel(id: sessionID) else {
            throw RepositoryError.notFound(entity: "session", id: sessionID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        try persist()
    }

    // MARK: Lookups

    private func sessionModel(id: UUID) throws -> SDFocusSession? {
        try fetchFirst(SDFocusSession.self, predicate: #Predicate<SDFocusSession> { $0.id == id })
    }

    private func sessionModels(in range: Range<Date>) throws -> [SDFocusSession] {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDFocusSession.self,
            predicate: #Predicate<SDFocusSession> {
                $0.deletedAt == nil && $0.startedAt >= lower && $0.startedAt < upper
            },
            sortBy: [SortDescriptor(\SDFocusSession.startedAt, order: .reverse)]
        )
    }
}

// MARK: - Check-ins

extension KoolSkoolStore: CheckInRepository {

    func checkIns(in range: Range<Date>) throws -> [CheckIn] {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDCheckIn.self,
            predicate: #Predicate<SDCheckIn> {
                $0.deletedAt == nil && $0.timestamp >= lower && $0.timestamp < upper
            },
            sortBy: [SortDescriptor(\SDCheckIn.timestamp, order: .reverse)]
        ).map { $0.toDomain() }
    }

    func checkIns(forSessionID sessionID: UUID) throws -> [CheckIn] {
        try fetchAll(
            SDCheckIn.self,
            predicate: #Predicate<SDCheckIn> { $0.deletedAt == nil && $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\SDCheckIn.timestamp, order: .forward)]
        ).map { $0.toDomain() }
    }

    @discardableResult
    func upsert(_ checkIn: CheckIn) throws -> CheckIn {
        let stamp = now

        if let existing = try fetchFirst(SDCheckIn.self, predicate: #Predicate<SDCheckIn> { $0.id == checkIn.id }) {
            existing.apply(checkIn)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDCheckIn.make(from: checkIn)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDelete(checkInID: UUID) throws {
        guard let model = try fetchFirst(SDCheckIn.self, predicate: #Predicate<SDCheckIn> { $0.id == checkInID }) else {
            throw RepositoryError.notFound(entity: "check-in", id: checkInID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        try persist()
    }
}

// MARK: - Medication

extension KoolSkoolStore: MedicationRepository {

    func logs(in range: Range<Date>) throws -> [MedicationLog] {
        let lower = range.lowerBound
        let upper = range.upperBound
        return try fetchAll(
            SDMedicationLog.self,
            predicate: #Predicate<SDMedicationLog> {
                $0.deletedAt == nil && $0.timestamp >= lower && $0.timestamp < upper
            },
            sortBy: [SortDescriptor(\SDMedicationLog.timestamp, order: .reverse)]
        ).map { $0.toDomain() }
    }

    func mostRecentLog() throws -> MedicationLog? {
        try fetchFirst(
            SDMedicationLog.self,
            predicate: #Predicate<SDMedicationLog> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDMedicationLog.timestamp, order: .reverse)]
        )?.toDomain()
    }

    @discardableResult
    func upsert(_ log: MedicationLog) throws -> MedicationLog {
        let stamp = now

        if let existing = try fetchFirst(SDMedicationLog.self, predicate: #Predicate<SDMedicationLog> { $0.id == log.id }) {
            existing.apply(log)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDMedicationLog.make(from: log)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    func softDelete(logID: UUID) throws {
        guard let model = try fetchFirst(SDMedicationLog.self, predicate: #Predicate<SDMedicationLog> { $0.id == logID }) else {
            throw RepositoryError.notFound(entity: "medication log", id: logID)
        }
        let stamp = now
        model.deletedAt = stamp
        model.updatedAt = stamp
        try persist()
    }
}
