import Foundation
import Observation

/// Backs the full task list — the "everything else" that Today deliberately
/// keeps one tap away.
@MainActor
@Observable
final class TaskListModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    private(set) var open: [FocusTask] = []
    private(set) var completed: [FocusTask] = []
    private(set) var error: String?
    private(set) var notice: String?

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        self.repositories = repositories
        self.clock = clock
    }

    var isEmpty: Bool { open.isEmpty && completed.isEmpty }

    var musts: [FocusTask] {
        open.filter { $0.isMust(on: clock.now, using: clock) }
    }

    var inbox: [FocusTask] {
        open.filter { !$0.isMust(on: clock.now, using: clock) }
    }

    func load() async {
        do {
            let all = try await repositories.tasks.tasks(includeCompleted: true)
            open = all.filter { !$0.isCompleted }
            // Recently finished only. An endless done list is its own kind of
            // overwhelm.
            completed = all
                .filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(20)
                .map { $0 }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func capture(_ text: String) async {
        await perform {
            for line in TodayModel.splitCapture(text) {
                try await repositories.tasks.captureFromBrainDump(line)
            }
        }
    }

    func toggleMust(_ task: FocusTask) async {
        let isMust = task.isMust(on: clock.now, using: clock)
        await perform {
            try await repositories.tasks.setMust(taskID: task.id, day: isMust ? nil : clock.now)
        }
    }

    func toggleComplete(_ task: FocusTask) async {
        await perform {
            if task.isCompleted {
                try await repositories.tasks.reopen(taskID: task.id)
            } else {
                try await repositories.tasks.complete(taskID: task.id, at: clock.now, actualMinutes: nil)
            }
        }
    }

    func delete(_ task: FocusTask) async {
        await perform {
            try await repositories.tasks.softDelete(taskID: task.id)
        }
    }

    func dismissNotice() { notice = nil }

    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
            notice = nil
            await load()
        } catch let repositoryError as RepositoryError {
            if case let .mustLimitReached(limit) = repositoryError {
                notice = "\(limit) musts is the limit for today. Finish one or swap it out."
            } else {
                error = repositoryError.localizedDescription
            }
            await load()
        } catch {
            self.error = error.localizedDescription
            await load()
        }
    }
}
