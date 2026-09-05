import Foundation
import SwiftData

/// Wires the single `KoolSkoolStore` actor up as every repository.
///
/// When a networked backend arrives, the change is one new provider here plus
/// its implementations. No view, view model, or domain type moves.
struct SwiftDataRepositoryProvider: RepositoryProvider {
    let store: KoolSkoolStore

    init(container: ModelContainer) {
        store = KoolSkoolStore(modelContainer: container)
    }

    init(store: KoolSkoolStore) {
        self.store = store
    }

    var tasks: any TaskRepository { store }
    var sessions: any SessionRepository { store }
    var checkIns: any CheckInRepository { store }
    var medication: any MedicationRepository { store }
    var progress: any ProgressRepository { store }
    var collection: any CollectionRepository { store }
    var stillness: any StillnessRepository { store }
    var reflections: any ReflectionRepository { store }
    var settings: any SettingsRepository { store }
}

extension SwiftDataRepositoryProvider {
    /// Convenience for tests and previews: a fresh in-memory stack.
    ///
    /// `async` so the injected clock is guaranteed to be in place before the
    /// provider is handed back — a detached set would race the first read.
    static func inMemory(clock: (any DateProvider)? = nil) async throws -> SwiftDataRepositoryProvider {
        let container = try KoolSkoolSchema.makeContainer(inMemory: true)
        let provider = SwiftDataRepositoryProvider(container: container)
        if let clock {
            await provider.store.setClock(clock)
        }
        return provider
    }
}
