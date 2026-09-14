import Foundation

/// Where Siri, Shortcuts and the Action button reach the running app.
///
/// The one deliberate singleton in the codebase, and it is only touched by
/// entry points — the intents and the app's launch — never by features. An
/// intent can arrive before the app has finished starting, so a start request
/// waits here until the environment is attached rather than racing the
/// recovery of a session that is already running.
@MainActor
final class IntentRouter {
    static let shared = IntentRouter()

    enum StartOutcome: Equatable, Sendable {
        case started
        case alreadyRunning
        case sitInProgress
        /// Arrived before launch finished; starts as soon as it has.
        case queued
    }

    private weak var environment: AppEnvironment?
    private(set) var pendingStart: SessionMode?
    private let fallbackRepositories: @MainActor () async throws -> any RepositoryProvider

    init(
        fallbackRepositories: @escaping @MainActor () async throws -> any RepositoryProvider = {
            SwiftDataRepositoryProvider(container: try SharedStore.container.get())
        }
    ) {
        self.fallbackRepositories = fallbackRepositories
    }

    /// Called once launch has recovered any running session.
    func attach(_ environment: AppEnvironment) async {
        self.environment = environment
        if let mode = pendingStart {
            pendingStart = nil
            _ = await startSession(mode: mode)
        }
    }

    /// Starts straight away with no setup screen. Asking questions between
    /// "start a session" and the session starting is the friction this app
    /// exists to remove.
    func startSession(mode: SessionMode) async -> StartOutcome {
        guard let environment else {
            pendingStart = mode
            return .queued
        }
        guard !environment.stillness.isRunning else { return .sitInProgress }
        guard environment.focusEngine.status != .running else { return .alreadyRunning }

        await environment.focusEngine.start(SessionPlan.make(mode: mode, settings: environment.settings))
        return .started
    }

    /// Each line becomes its own task, exactly as the in-app brain dump does.
    /// Works whether or not the app is open.
    func capture(_ text: String) async throws -> Int {
        let lines = TodayModel.splitCapture(text)
        guard !lines.isEmpty else { return 0 }

        let repositories: any RepositoryProvider
        if let environment {
            repositories = environment.repositories
        } else {
            repositories = try await fallbackRepositories()
        }

        for line in lines {
            try await repositories.tasks.captureFromBrainDump(line)
        }

        environment?.noteExternalChange()
        return lines.count
    }
}
