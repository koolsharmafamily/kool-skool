import Foundation
import Observation

/// First launch: four screens at most, then straight into a session.
///
/// The spec's target is "complete a session inside 90 seconds of install". A
/// five-minute Just Start cannot *finish* inside ninety seconds, so this reads
/// it as being *in* one — which the quickest path here reaches in four taps.
@MainActor
@Observable
final class OnboardingModel {

    enum Step: Int, CaseIterable, Sendable {
        case focus
        case rhythm
        case notifications
        case start
    }

    static let maximumSteps = 4

    // MARK: Dependencies

    private let repositories: any RepositoryProvider
    private let clock: any DateProvider
    private let applySettings: @MainActor (@escaping (inout AppSettings) -> Void) async -> Void
    private let requestNotifications: @MainActor () async -> NotificationStatus
    private let startSession: @MainActor (SessionPlan) async -> Void

    /// Fixed when onboarding begins. Once permission has been granted or
    /// refused the system will not show its prompt again, so the screen is left
    /// out — and recomputing the steps mid-flow would lose the user's place.
    private let asksAboutNotifications: Bool

    // MARK: State

    private(set) var step: Step = .focus
    var focusText = ""
    var preferredWorkTime: TimeOfDay?
    var tradition: Tradition
    private(set) var notificationStatus: NotificationStatus
    private(set) var isFinishing = false

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider,
        initialSettings: AppSettings,
        notificationStatus: NotificationStatus,
        applySettings: @escaping @MainActor (@escaping (inout AppSettings) -> Void) async -> Void,
        requestNotifications: @escaping @MainActor () async -> NotificationStatus,
        startSession: @escaping @MainActor (SessionPlan) async -> Void
    ) {
        self.repositories = repositories
        self.clock = clock
        self.applySettings = applySettings
        self.requestNotifications = requestNotifications
        self.startSession = startSession
        self.notificationStatus = notificationStatus
        asksAboutNotifications = notificationStatus == .notDetermined
        tradition = initialSettings.tradition
        preferredWorkTime = initialSettings.preferredWorkTime
    }

    // MARK: Derived

    var steps: [Step] {
        Step.allCases.filter { $0 != .notifications || asksAboutNotifications }
    }

    var stepCount: Int { steps.count }

    /// 1-based, for "step 2 of 4".
    var stepNumber: Int { (steps.firstIndex(of: step) ?? 0) + 1 }

    var canGoBack: Bool { step != steps.first }

    var trimmedFocus: String {
        focusText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Moving

    func advance() {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    func goBack() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// Asked here, with the reason on screen, and only because it was tapped.
    /// Either answer moves on — a refusal is a perfectly good answer.
    func allowNotifications() async {
        notificationStatus = await requestNotifications()
        advance()
    }

    /// The last screen's button.
    ///
    /// Order matters. The task is created first so the session can be on it,
    /// and the session starts *before* onboarding is marked done, so Today never
    /// flashes up for a frame in between.
    func finish(startingSession: Bool = true) async {
        guard !isFinishing else { return }
        isFinishing = true

        let focus = trimmedFocus
        var taskID: UUID?
        if !focus.isEmpty {
            // Failing to save the task must never cost someone their first session.
            if let created = try? await repositories.tasks.captureFromBrainDump(focus) {
                taskID = created.id
                _ = try? await repositories.tasks.setMust(taskID: created.id, day: clock.now)
            }
        }

        if startingSession {
            let justStart = SessionMode.justStart.defaultProfile
            await startSession(SessionPlan(mode: .justStart, plannedDuration: justStart.workDuration, taskID: taskID))
        }

        let time = preferredWorkTime
        let framing = tradition
        await applySettings { settings in
            settings.preferredWorkTime = time
            settings.tradition = framing
            settings.hasCompletedOnboarding = true
        }
    }
}
