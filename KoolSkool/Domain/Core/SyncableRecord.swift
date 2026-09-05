import Foundation

/// Every persisted entity in Kool Skool carries the same four fields so that a
/// cloud backend can be dropped in later without a migration:
///
/// - `id` is client-generated, stable, and safe to use as a remote primary key.
/// - `createdAt` / `updatedAt` give last-writer-wins conflict resolution.
/// - `deletedAt` is a soft delete. Nothing is ever hard-deleted by the app, so a
///   deletion can propagate to other devices instead of silently reappearing.
///
/// Repositories filter out soft-deleted rows by default. Only a future sync
/// engine or an explicit purge should ever see them.
protocol SyncableRecord: Sendable, Identifiable, Hashable {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

extension SyncableRecord {
    var isDeleted: Bool { deletedAt != nil }
}

/// The mutable half of `SyncableRecord`, stamped on write.
struct SyncMetadata: Sendable, Hashable, Codable {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(id: UUID = UUID(), createdAt: Date = .now, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
