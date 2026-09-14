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
    let bodyDoubling: BodyDoublingController
    /// Owned here rather than by a screen, because the Today row and the full
    /// log have to agree about whether today is logged.
    let medication: MedicationModel
    /// Long-lived for the same reason the focus engine is: a sit has to keep
    /// running while the view hierarchy churns around it.
    let stillness: StillnessModel
    /// Owned here because Today shows the morning line and the reflection
    /// screen edits it, and they have to agree.
    let reflection: ReflectionModel

    /// Cached copies of the two singleton rows, so screens can read them
    /// synchronously. Writes go through this object and refresh the cache.
    private(set) var settings = AppSettings()
    private(set) var progress = UserProgress()
    /// How far the user's own time estimates run. Cached so the estimate picker
    /// and the completion screen can read it without a fetch.
    private(set) var calibration = EstimateCalibration.unknown

    private(set) var isReady = false
    /// Read from the system, never assumed. Settings shows the truth.
    private(set) var notificationStatus: NotificationStatus = .notDetermined
    /// Bumped when something outside the app's screens — a brain dump from Siri
    /// — changes data, so whatever is open can refresh.
    private(set) var externalChangeCount = 0

    private let widgets: any WidgetSnapshotPublishing
    /// The last picture handed to the widgets. Widget reloads are budgeted by
    /// the system, so an unchanged picture is not sent twice.
    @ObservationIgnored private var lastWidgetSnapshot: WidgetSnapshot?
    /// Set when the persistent store could not be opened and the app fell back
    /// to memory. Surfaced to the user rather than swallowed.
    private(set) var storeWarning: String?
    private(set) var lastError: String?

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider = SystemDateProvider(),
        haptics: any HapticPerforming = KSHaptics.shared,
        alerts: any SessionAlertScheduling = LocalSessionAlertScheduler(),
        idleGuard: any ScreenIdleGuarding = ScreenIdleGuard(),
        rolls: @escaping @Sendable () -> RewardRolls = { RewardRolls.random() },
        reminders: any MedicationReminderScheduling = LocalMedicationReminderScheduler(),
        practices: any PracticeProvider = BundledPracticeProvider(),
        liveActivities: any SessionLiveActivityManaging = ActivityKitLiveActivityManager(),
        widgets: any WidgetSnapshotPublishing = AppGroupWidgetPublisher(),
        storeWarning: String? = nil
    ) {
        self.widgets = widgets
        self.repositories = repositories
        self.clock = clock
        self.haptics = haptics
        self.storeWarning = storeWarning
        medication = MedicationModel(repositories: repositories, clock: clock, reminders: reminders)

        let rewards = RewardService(repositories: repositories, clock: clock, rolls: rolls)
        self.rewards = rewards

        let bodyDoubling = BodyDoublingController(repositories: repositories)
        self.bodyDoubling = bodyDoubling

        stillness = StillnessModel(
            repositories: repositories,
            clock: clock,
            haptics: haptics,
            provider: practices,
            bodyDoubling: bodyDoubling
        )
        reflection = ReflectionModel(repositories: repositories, clock: clock)

        focusEngine = FocusEngine(
            repositories: repositories,
            clock: clock,
            haptics: haptics,
            alerts: alerts,
            idleGuard: idleGuard,
            rewards: rewards,
            bodyDoubling: bodyDoubling,
            liveActivity: liveActivities
        )
    }

    /// Loads the singleton rows. Safe to call more than once.
    func bootstrap() async {
        do {
            settings = try await repositories.settings.settings()
            haptics.isEnabled = settings.hapticsEnabled
            haptics.prepare()
            focusEngine.apply(settings: settings)
            stillness.apply(settings: settings)

            // Recovered here rather than by a screen, and before anything else
            // that can fail. An App Intent arriving mid-launch waits for this, so
            // it can never start a second session over one that is still running.
            await focusEngine.restore()

            try await rewards.prepareCatalogue()
            await bodyDoubling.refreshCatalogue()
            // Seeds the bundled practices and recomputes the calm streak, which
            // like the focus streak is derived rather than stored.
            await stillness.load()
            await reflection.load()
            // Recomputed at launch so a streak that survived on freezes, or one
            // that quietly lapsed, is right before the Today screen draws it.
            progress = try await rewards.refreshStreak()
            await refreshCalibration()

            // Re-arms the reminder in case a reinstall or a cleared notification
            // centre dropped it. Never prompts — permission is only ever asked
            // for when someone switches the reminder on.
            await medication.restoreReminder(settings: settings)
            if settings.medicationTrackingEnabled {
                await medication.load()
            }

            await refreshNotificationStatus()
            await refreshWidgets()

            isReady = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isReady = false
        }
    }

    // MARK: System surfaces

    /// Rebuilds what the widgets show. Reads progress from the store rather than
    /// the cache, because it is called the moment a session ends — before the
    /// cache has caught up with the reward that was just paid.
    func refreshWidgets() async {
        guard let latest = try? await repositories.progress.progress() else { return }
        let musts = (try? await repositories.tasks.musts(on: clock.now)) ?? []

        let snapshot = WidgetSnapshot.make(progress: latest, musts: musts, session: focusEngine.session, clock: clock)
        guard !snapshot.hasSameContent(as: lastWidgetSnapshot) else { return }

        lastWidgetSnapshot = snapshot
        await widgets.publish(snapshot)
    }

    func refreshNotificationStatus() async {
        notificationStatus = await NotificationAuthorization.status()
    }

    /// Asked from Settings, in answer to a tap on "Allow notifications".
    func requestNotifications() async {
        _ = await NotificationAuthorization.request()
        await refreshNotificationStatus()
    }

    func noteExternalChange() {
        externalChangeCount += 1
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
            let wasTracking = settings.medicationTrackingEnabled
            settings = try await repositories.settings.update(draft)
            haptics.isEnabled = settings.hapticsEnabled
            focusEngine.apply(settings: settings)
            stillness.apply(settings: settings)

            // Switching tracking off has to take the reminder with it. Hiding
            // the UI while a notification keeps arriving every morning would be
            // the worst of both.
            if wasTracking && !settings.medicationTrackingEnabled {
                var disarmed = settings
                disarmed.medicationReminderEnabled = false
                settings = try await repositories.settings.update(disarmed)
                await medication.restoreReminder(settings: settings)
            }

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
            let container = try SharedStore.container.get()
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
