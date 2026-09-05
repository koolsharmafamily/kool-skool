import Foundation
import Observation

/// The shape every view model in this app follows: `@MainActor`, `@Observable`,
/// holds a `RepositoryProvider`, exposes plain state, does its I/O in `async`
/// methods, and never mentions SwiftData.
@MainActor
@Observable
final class RootStatusModel {
    private let repositories: any RepositoryProvider

    private(set) var taskCount = 0
    private(set) var sessionCount = 0
    private(set) var sitCount = 0
    private(set) var error: String?

    init(repositories: any RepositoryProvider) {
        self.repositories = repositories
    }

    func load() async {
        do {
            async let tasks = repositories.tasks.tasks(includeCompleted: true)
            async let sessions = repositories.sessions.recentSessions(limit: 500)
            async let sits = repositories.stillness.recentSits(limit: 500)

            taskCount = try await tasks.count
            sessionCount = try await sessions.count
            sitCount = try await sits.count
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    #if DEBUG
    /// Writes one row through the repository so the persistence path can be
    /// exercised on device before any feature exists.
    func writeSampleTask(clock: any DateProvider) async {
        do {
            let stamp = clock.now.formatted(date: .omitted, time: .standard)
            try await repositories.tasks.captureFromBrainDump("Sample capture at \(stamp)")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
    #endif
}
