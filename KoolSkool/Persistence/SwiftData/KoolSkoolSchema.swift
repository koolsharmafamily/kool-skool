import Foundation
import SwiftData

enum KoolSkoolSchema {
    static let models: [any PersistentModel.Type] = [
        SDTask.self,
        SDTaskStep.self,
        SDFocusSession.self,
        SDCheckIn.self,
        SDMedicationLog.self,
        SDUserProgress.self,
        SDUnlockable.self,
        SDStillnessSession.self,
        SDReflection.self,
        SDPractice.self,
        SDAppSettings.self,
    ]

    static var schema: Schema { Schema(models) }

    /// v1 is local-only and explicitly opts out of CloudKit. The schema is
    /// nonetheless written to CloudKit's rules — no unique constraints, every
    /// property defaulted, every relationship optional — so turning sync on
    /// later is a configuration change rather than a migration.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "KoolSkool",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
