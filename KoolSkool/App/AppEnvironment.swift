import Foundation
import Observation

/// The composition root. Everything the app depends on is constructed here and
/// handed down through the SwiftUI environment — no singletons reached for from
/// inside features, and no `ModelContext` anywhere near a view.
@MainActor
@Observable
final class AppEnvironment {
    let repositories: any RepositoryProvider
    let clock: any DateProvider
    let haptics: any HapticPerforming

    /// Long-lived, because it has to keep ticking across view churn and be the
    /// one place that knows whether a session is running.
    let focusEngine: FocusEngine
    let rewards: RewardService

    /// Cached copies of the two singleton rows, so screens can read them
    /// synchronously. Writes go through this object and refresh the cache.
    private(set) var settings = AppSettings()
    private(set) var progress = UserProgress()
    /// How far the user's own time estimates run. Cached so the estimate picker
    /// and the completion screen can read it without a fetch.
    private(set) var calibration = EstimateCalibration.unknown

    private(set) var isReady = false
    /// Set when the persistent store could not be opened and the app fell back
    /// to memory. Surfaced to the user rather than swallowed.
    private(set) var storeWarning: String?
    private(set) var lastError: String?

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider = SystemDateProvider(),
        haptics: any HapticPerforming = KSHaptics.shared,
        alerts: any SessionAlertScheduling = NoOpSessionAlertScheduler(),
        idleGuard: any ScreenIdleGuarding = ScreenIdleGuard(),
        rolls: @escaping @Sendable () -> RewardRolls = { RewardRolls.random() },
        storeWarning: String? = nil
    ) {
        self.repositories = repositories
        self.clock = clock
        self.haptics = haptics
        self.storeWarning = storeWarning

        let rewards = RewardService(repositories: repositories, clock: clock, rolls: rolls)
        self.rewards = rewards
        focusEngine = FocusEngine(
            repositories: repositories,
            clock: clock,
            haptics: haptics,
            alerts: alerts,
            idleGuard: idleGuard,
            rewards: rewards
        )
    }

    /// Loads the singleton rows. Safe to call more than once.
    func bootstrap() async {
        do {
            settings = try await repositories.settings.settings()
            haptics.isEnabled = settings.hapticsEnabled
            haptics.prepare()
            focusEngine.apply(settings: settings)

            try await rewards.prepareCatalogue()
            // Recomputed at launch so a streak that survived on freezes, or one
            // that quietly lapsed, is right before the Today screen draws it.
            progress = try await rewards.refreshStreak()
            await refreshCalibration()

            isReady = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isReady = false
        }
    }

    func refreshProgress() async {
        do {
            progress = try await repositories.progress.progress()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Recomputed from finished tasks rather than accumulated, so a deleted or
    /// reopened task is reflected immediately.
    func refreshCalibration() async {
        do {
            let tasks = try await repositories.tasks.tasks(includeCompleted: true)
            calibration = EstimateCalibrator.calibrate(tasks)
        } catch {
            calibration = .unknown
        }
    }

    /// Mutate-and-persist for settings. Keeps the cached copy and the store in
    /// step without every caller remembering to do both.
    func updateSettings(_ mutate: (inout AppSettings) -> Void) async {
        var draft = settings
        mutate(&draft)
        do {
            settings = try await repositories.settings.update(draft)
            haptics.isEnabled = settings.hapticsEnabled
            focusEngine.apply(settings: settings)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

extension AppEnvironment {
    /// Builds the live stack, falling back to an in-memory store if the on-disk
    /// one cannot be opened.
    ///
    /// A corrupt store should not be a crash on launch. The app comes up, the
    /// user is told their history could not be loaded, and the session they
    /// start still works.
    static func live() -> AppEnvironment {
        do {
            let container = try KoolSkoolSchema.makeContainer()
            return AppEnvironment(repositories: SwiftDataRepositoryProvider(container: container))
        } catch {
            let fallbackWarning = """
            Your saved data could not be opened, so this session is running in memory only. \
            Nothing you do now will be kept.
            """

            if let memoryContainer = try? KoolSkoolSchema.makeContainer(inMemory: true) {
                return AppEnvironment(
                    repositories: SwiftDataRepositoryProvider(container: memoryContainer),
                    storeWarning: fallbackWarning
                )
            }

            // Both stores failed. There is nothing left to fall back to, so the
            // app runs with an unusable repository and says so plainly.
            return AppEnvironment(
                repositories: UnavailableRepositoryProvider(),
                storeWarning: "Storage is unavailable on this device. \(error.localizedDescription)"
            )
        }
    }
}
