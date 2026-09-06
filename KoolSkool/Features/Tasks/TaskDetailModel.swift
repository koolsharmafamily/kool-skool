import Foundation
import Observation

/// One task, editable, plus its steps.
///
/// Holds a draft that the fields bind to and writes it back on explicit actions
/// and on leaving the screen. Nothing here debounces a keystroke into the store.
@MainActor
@Observable
final class TaskDetailModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    var draft: FocusTask
    private(set) var steps: [TaskStep] = []
    private(set) var error: String?
    private(set) var notice: String?
    private(set) var wasDeleted = false

    init(task: FocusTask, repositories: any RepositoryProvider, clock: any DateProvider) {
        self.draft = task
        self.repositories = repositories
        self.clock = clock
        self.steps = task.orderedSteps
    }

    // MARK: Derived

    var isMustToday: Bool { draft.isMust(on: clock.now, using: clock) }

    var completedStepCount: Int { steps.filter(\.isDone).count }

    var stepProgressLabel: String? {
        guard !steps.isEmpty else { return nil }
        return "\(completedStepCount) of \(steps.count) done"
    }

    /// The prompt shown above the next-step field. Phrased as a question about
    /// physical action, because "what is the next step" gets answered with
    /// another abstraction.
    var nextStepPrompt: String {
        "What is the smallest thing you could physically do first?"
    }

    // MARK: Loading

    func reload() async {
        do {
            guard let fresh = try await repositories.tasks.task(id: draft.id) else {
                wasDeleted = true
                return
            }
            draft = fresh
            steps = fresh.orderedSteps
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Writing

    /// Called on leaving the screen and after committing a text field.
    func save() async {
        await perform {
            try await repositories.tasks.upsert(draft)
        }
    }

    func addStep(_ title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await perform {
            let step = TaskStep(
                taskID: draft.id,
                title: trimmed,
                order: (steps.map(\.order).max() ?? -1) + 1
            )
            try await repositories.tasks.upsertStep(step)
        }
    }

    func toggleStep(_ step: TaskStep) async {
        await perform {
            var updated = step
            updated.isDone.toggle()
            updated.completedAt = updated.isDone ? clock.now : nil
            try await repositories.tasks.upsertStep(updated)
        }
    }

    func deleteStep(_ step: TaskStep) async {
        await perform {
            try await repositories.tasks.softDeleteStep(stepID: step.id)
        }
    }

    /// Quick templates. Deliberately offline — the AI-assisted split is a later
    /// version, and v1 makes no network calls.
    func applyTemplate(_ template: StepTemplate) async {
        await perform {
            try await repositories.tasks.replaceSteps(taskID: draft.id, titles: template.steps)
        }
        notice = "Replaced the steps with the \(template.displayName.lowercased()) template."
    }

    func setMustToday(_ isMust: Bool) async {
        await perform {
            try await repositories.tasks.setMust(taskID: draft.id, day: isMust ? clock.now : nil)
        }
    }

    func toggleComplete() async {
        await perform {
            if draft.isCompleted {
                try await repositories.tasks.reopen(taskID: draft.id)
            } else {
                try await repositories.tasks.complete(taskID: draft.id, at: clock.now, actualMinutes: nil)
            }
        }
    }

    func delete() async {
        do {
            try await repositories.tasks.softDelete(taskID: draft.id)
            wasDeleted = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func dismissNotice() { notice = nil }

    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
            notice = nil
            await reload()
        } catch let repositoryError as RepositoryError {
            if case let .mustLimitReached(limit) = repositoryError {
                notice = "\(limit) musts is the limit for today. Finish one or swap it out."
            } else {
                error = repositoryError.localizedDescription
            }
            await reload()
        } catch {
            self.error = error.localizedDescription
            await reload()
        }
    }
}
