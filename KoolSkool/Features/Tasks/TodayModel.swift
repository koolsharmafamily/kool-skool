import Foundation
import Observation

/// Backs the Today screen.
///
/// Holds the three musts and nothing else that competes with them. The full list
/// is loaded too, but only so the picker has something to offer and the "all
/// tasks" count is honest.
@MainActor
@Observable
final class TodayModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    private(set) var musts: [FocusTask] = []
    private(set) var allOpenTasks: [FocusTask] = []
    private(set) var error: String?
    /// Non-blocking message, e.g. the rule-of-three cap. Phrased as information,
    /// never as a failure.
    private(set) var notice: String?
    private(set) var hasLoaded = false

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        self.repositories = repositories
        self.clock = clock
    }

    // MARK: Derived

    var openMusts: [FocusTask] { musts.filter { !$0.isCompleted } }
    var completedMusts: [FocusTask] { musts.filter(\.isCompleted) }

    /// How many more musts today can take. Only open ones count against the cap.
    var remainingMustSlots: Int {
        max(0, TaskRules.mustLimit - openMusts.count)
    }

    /// Tasks eligible to become a must: open, and not already one for today.
    var candidates: [FocusTask] {
        let mustIDs = Set(musts.map(\.id))
        return allOpenTasks.filter { !mustIDs.contains($0.id) }
    }

    var otherTaskCount: Int { candidates.count }

    // MARK: Loading

    func load() async {
        do {
            async let mustsTask = repositories.tasks.musts(on: clock.now)
            async let openTask = repositories.tasks.tasks(includeCompleted: false)

            musts = try await mustsTask
            allOpenTasks = try await openTask
            error = nil
            hasLoaded = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Actions

    func capture(_ text: String) async {
        await perform {
            for line in Self.splitCapture(text) {
                try await repositories.tasks.captureFromBrainDump(line)
            }
        }
    }

    func addMust(_ task: FocusTask) async {
        await perform {
            try await repositories.tasks.setMust(taskID: task.id, day: clock.now)
        }
    }

    /// Create something new and pin it in one step.
    ///
    /// If the cap refuses it the task still exists — it just lands in the inbox
    /// instead of on Today, which is better than losing what was typed.
    func captureAsMust(_ text: String) async {
        await perform {
            let created = try await repositories.tasks.captureFromBrainDump(text)
            try await repositories.tasks.setMust(taskID: created.id, day: clock.now)
        }
    }

    func removeMust(_ task: FocusTask) async {
        await perform {
            try await repositories.tasks.setMust(taskID: task.id, day: nil)
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

    func setNextStep(_ step: String, for task: FocusTask) async {
        await perform {
            var draft = task
            draft.nextStep = step.trimmingCharacters(in: .whitespacesAndNewlines)
            try await repositories.tasks.upsert(draft)
        }
    }

    func dismissNotice() { notice = nil }

    // MARK: Plumbing

    /// Runs a mutation, turns the rule-of-three cap into a message rather than
    /// an error, and reloads.
    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
            notice = nil
            await load()
        } catch let repositoryError as RepositoryError {
            if case let .mustLimitReached(limit) = repositoryError {
                notice = "\(limit) is the limit for today. Finish one or swap it out."
            } else {
                error = repositoryError.localizedDescription
            }
            await load()
        } catch {
            self.error = error.localizedDescription
            await load()
        }
    }

    /// A brain dump is a list by nature, so each line becomes its own task.
    /// Merging them would only create sorting work later, which is exactly the
    /// work this feature exists to avoid.
    static func splitCapture(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
