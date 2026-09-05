import Foundation

enum RepositoryError: LocalizedError, Equatable {
    case notFound(entity: String, id: UUID)
    /// The rule of three is a hard cap, enforced at the persistence boundary so
    /// no code path can quietly exceed it.
    case mustLimitReached(limit: Int)
    case invalidInput(String)
    case storeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(entity, id):
            "No \(entity) with id \(id.uuidString)."
        case let .mustLimitReached(limit):
            "You already have \(limit) musts for today."
        case let .invalidInput(detail):
            detail
        case let .storeUnavailable(detail):
            "The local store is unavailable: \(detail)"
        }
    }
}
