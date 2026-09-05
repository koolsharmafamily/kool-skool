import Foundation
import SwiftData

extension KoolSkoolStore: SettingsRepository {

    /// One settings row, created with defaults on first read.
    func settings() throws -> AppSettings {
        if let existing = try settingsModel() {
            return existing.toDomain()
        }
        let stamp = now
        let model = SDAppSettings(createdAt: stamp, updatedAt: stamp)
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    @discardableResult
    func update(_ settings: AppSettings) throws -> AppSettings {
        let stamp = now

        if let existing = try settingsModel() {
            existing.apply(settings)
            existing.updatedAt = stamp
            try persist()
            return existing.toDomain()
        }

        let model = SDAppSettings(createdAt: stamp, updatedAt: stamp)
        model.apply(settings)
        modelContext.insert(model)
        try persist()
        return model.toDomain()
    }

    private func settingsModel() throws -> SDAppSettings? {
        try fetchFirst(
            SDAppSettings.self,
            predicate: #Predicate<SDAppSettings> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\SDAppSettings.createdAt, order: .forward)]
        )
    }
}
