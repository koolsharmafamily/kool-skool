import Foundation
import SwiftData

extension KoolSkoolStore: ProgressRepository {

    /// There is exactly one progress row. It is created on first read so no
    /// caller ever has to handle its absence.
    func progress() throws -> UserProgress {
        if let existing = try progressModel() {
            return existing.toDomain()
        }
        let stamp = now
        let model = SDUserProgress(createdAt: stamp, updatedAt: stamp)
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    @discardableResult
    func update(_ progress: UserProgress) throws -> UserProgress {
        let stamp = now

        if let existing = try progressModel() {
            existing.apply(progress)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDUserProgress(createdAt: stamp, updatedAt: stamp)
        model.apply(progress)
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    private func progressModel() throws -> SDUserProgress? {
        try fetchFirst(
            SDUserProgress.self,
            predicate: #Predicate<SDUserProgress> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDUserProgress.createdAt, order: .forward)]
        )
    }
}

// MARK: - Collection

extension KoolSkoolStore: CollectionRepository {

    func unlockables() throws -> [Unlockable] {
        try fetchAll(
            SDUnlockable.self,
            predicate: #Predicate<SDUnlockable> { $0.deletedAt == nil },
            sortBy: [
                SortDescriptor(\SDUnlockable.requiredLevel, order: .forward),
                SortDescriptor(\SDUnlockable.title, order: .forward),
            ]
        ).map { $0.toDomain() }
    }

    func unlockable(key: String) throws -> Unlockable? {
        try unlockableModel(key: key)?.toDomain()
    }

    @discardableResult
    func upsert(_ unlockable: Unlockable) throws -> Unlockable {
        let stamp = now

        if let existing = try unlockableModel(key: unlockable.key) {
            existing.apply(unlockable)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDUnlockable.make(from: unlockable)
        model.createdAt = stamp
        model.updatedAt = stamp
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    /// Reseeding refreshes catalogue metadata — title, cost, level gate — but
    /// never touches `unlockedAt` or `isEquipped`. An app update must not take
    /// away something the user already earned.
    func seedIfNeeded(_ catalogue: [Unlockable]) throws {
        let stamp = now

        for item in catalogue {
            if let existing = try unlockableModel(key: item.key) {
                existing.applyCatalogueFields(item)
                existing.updatedAt = stamp
            } else {
                let model = SDUnlockable.make(from: item)
                model.createdAt = stamp
                model.updatedAt = stamp
                modelContext.insert(model)
            }
        }

        try persist()
    }

    func equip(key: String) throws {
        guard let target = try unlockableModel(key: key) else {
            throw RepositoryError.invalidInput("No collectable with key \(key).")
        }
        guard target.unlockedAt != nil else {
            throw RepositoryError.invalidInput("\(target.title) is not unlocked yet.")
        }

        let stamp = now
        let typeRaw = target.typeRaw
        let siblings = try fetchAll(
            SDUnlockable.self,
            predicate: #Predicate<SDUnlockable> { $0.deletedAt == nil && $0.typeRaw == typeRaw }
        )

        for sibling in siblings where sibling.isEquipped {
            sibling.isEquipped = false
            sibling.updatedAt = stamp
        }

        target.isEquipped = true
        target.updatedAt = stamp
        try persist()
    }

    private func unlockableModel(key: String) throws -> SDUnlockable? {
        try fetchFirst(SDUnlockable.self, predicate: #Predicate<SDUnlockable> { $0.key == key })
    }
}
