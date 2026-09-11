import Foundation

/// Marks a record as health-adjacent.
///
/// The spec's privacy rule: mood, energy, and medication data stay in the local
/// store, are never sent to analytics, and — when cloud sync arrives — must be
/// opt-in *separately* from everything else.
///
/// There is no sync yet and no analytics ever, so today this is a label. It
/// exists so the future sync engine has one thing to check. A record that
/// conforms here is excluded by default, and including it takes its own
/// explicit consent, distinct from the consent to sync tasks and sessions.
///
/// Reflections are included too. The spec does not name them, but "what was
/// hard today" and a line of gratitude are journaling, and the conservative
/// default for journaling is the same one.
protocol HealthAdjacentRecord: SyncableRecord {}

extension CheckIn: HealthAdjacentRecord {}
extension MedicationLog: HealthAdjacentRecord {}
extension Reflection: HealthAdjacentRecord {}

enum DataSensitivity: Sendable, Equatable {
    case standard
    case healthAdjacent

    static func of(_ record: any SyncableRecord) -> DataSensitivity {
        record is any HealthAdjacentRecord ? .healthAdjacent : .standard
    }
}
