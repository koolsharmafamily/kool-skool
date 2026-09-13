import Foundation

/// A thing the user wants to get done.
///
/// Named `FocusTask` rather than `Task` because `Task` is Swift Concurrency's
/// type and shadowing it inside the module would break every `Task { ... }` in
/// the app.
struct FocusTask: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var title: String = ""
    var notes: String = ""

    /// The smallest physically startable action. Shown on the Today screen in
    /// place of the title when the task is large enough to stall on.
    var nextStep: String = ""

    var estimateMinutes: Int?
    /// Filled in from actual session time once the task is completed.
    var actualMinutes: Int?

    /// Last logged resistance from the pre-session ritual.
    var resistance: Rating?

    /// The day this task is one of the three musts for, at midnight local time.
    /// `nil` means it is not a must. Storing the day rather than a bare flag is
    /// what makes the rule of three reset on its own each morning.
    var mustForDate: Date?

    var completedAt: Date?

    /// Manual ordering within the inbox / list.
    var sortOrder: Int = 0

    var steps: [TaskStep] = []

    var isCompleted: Bool { completedAt != nil }

    /// Whether this task is a must for the given day.
    func isMust(on day: Date, using clock: any DateProvider) -> Bool {
        guard let mustForDate else { return false }
        return clock.isSameDay(mustForDate, day)
    }

    /// What the Today screen should show: the next tiny step when there is one,
    /// otherwise the title.
    var startableLabel: String {
        let trimmed = nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? title : trimmed
    }

    var orderedSteps: [TaskStep] {
        steps.sorted { $0.order < $1.order }
    }

    var completedStepCount: Int {
        steps.filter { $0.isDone && !$0.isDeleted }.count
    }
}

/// One ordered sub-step of a task.
struct TaskStep: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var taskID: UUID
    var title: String = ""
    var order: Int = 0
    var isDone: Bool = false
    var completedAt: Date?
}

/// Quick templates offered by the step splitter. Deliberately generic and
/// offline — the AI-assisted split is a later version and makes a network call,
/// which v1 does not.
enum StepTemplate: String, CaseIterable, Sendable, Identifiable {
    case writing
    case reading
    case revision
    case admin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .writing: "Write something"
        case .reading: "Read something"
        case .revision: "Revise for an exam"
        case .admin: "Get admin done"
        }
    }

    var steps: [String] {
        switch self {
        case .writing: ["Read the brief", "Outline", "Draft", "Edit"]
        case .reading: ["Skim headings", "Read closely", "Note the key points", "Summarise in your own words"]
        case .revision: ["Gather materials", "Make a question list", "Test yourself", "Mark the gaps"]
        case .admin: ["List everything", "Pick the smallest one", "Do it", "Do the next one"]
        }
    }
}
