import SwiftUI

/// Switches between the three states of the focus flow, owns the scene-phase
/// wiring the engine depends on, and hosts the task navigation.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var todayModel: TodayModel?
    @State private var taskListModel: TaskListModel?
    @State private var collectionModel: CollectionModel?
    @State private var insightsModel: InsightsModel?
    @State private var onboardingModel: OnboardingModel?
    @State private var path: [TaskRoute] = []
    @State private var setupTask: SetupRequest?

    private var engine: FocusEngine { app.focusEngine }
    private var stillness: StillnessModel { app.stillness }

    var body: some View {
        content
            .ksAnimation(KSAnimation.gentle, value: engine.status)
            // Slower on the way into stillness than anywhere else in the app.
            // The contrast between the two layers is meant to be felt.
            .ksAnimation(KSAnimation.calm, value: stillness.isRunning)
            .ksAnimation(KSAnimation.gentle, value: app.settings.hasCompletedOnboarding)
            .sheet(item: $setupTask) { request in
                setupSheet(for: request)
            }
            .task {
                // The running session is recovered in `AppEnvironment.bootstrap()`.
                await makeModelsIfNeeded()
                makeOnboardingModelIfNeeded()
            }
            .onChange(of: app.isReady) { _, _ in
                makeOnboardingModelIfNeeded()
            }
            .onChange(of: app.settings.hasCompletedOnboarding) { _, completed in
                // Onboarding may have just pinned the first must.
                if completed { Task { await refreshAll() } }
            }
            .onChange(of: scenePhase) { _, phase in
                Task { await engine.scenePhaseChanged(to: phase) }
                Task { await stillness.scenePhaseChanged(to: phase) }
                // Permission can change in iOS Settings while the app is away.
                if phase == .active { Task { await app.refreshNotificationStatus() } }
            }
            .onChange(of: engine.status) { _, status in
                // A session started from Siri or a widget must not open behind
                // a sheet that was left up.
                if status == .running {
                    setupTask = nil
                }
                // Coming back from a session, Today may be stale — a task could
                // have been marked done on the completion screen.
                if status == .idle { Task { await refreshAll() } }
                Task { await app.refreshWidgets() }
            }
            .onChange(of: app.externalChangeCount) { _, _ in
                Task { await refreshAll() }
            }
            .onOpenURL { url in
                handle(url)
            }
            .onChange(of: stillness.isRunning) { _, isRunning in
                // A finished sit moves the calm streak, which Today shows.
                if !isRunning { Task { await app.refreshProgress() } }
            }
    }

    /// The stillness layer sits in front of everything when it is active: a sit
    /// is a whole-screen thing, and a break offer is the next decision after a
    /// session whether or not the rest of the app has anything to say.
    @ViewBuilder
    private var content: some View {
        if let run = stillness.run {
            SitView(
                run: run,
                now: stillness.now,
                breathTick: stillness.breathTick,
                cue: stillness.currentCue,
                tradition: app.settings.tradition,
                onEnd: { Task { await stillness.end(reachedEnd: false) } }
            )
            .ksTransition(.opacity)
        } else if let finished = stillness.lastFinished {
            SitClosingView(
                sit: finished,
                practice: stillness.practices.first { $0.id == finished.practiceID },
                calmStreak: stillness.calmStreak,
                onDone: { stillness.dismissClosing() }
            )
            .ksTransition(.opacity)
        } else if let offer = stillness.breakOffer {
            BreakOfferView(
                offer: offer,
                entries: stillness.libraryEntries(level: app.progress.level),
                tradition: app.settings.tradition,
                onStart: { practice, duration in
                    stillness.start(practice: practice, duration: duration, focusSessionID: offer.focusSessionID, isBreak: true)
                },
                onPlainTimer: { duration in
                    stillness.startPlainBreak(duration: duration, focusSessionID: offer.focusSessionID)
                },
                onSkip: { stillness.dismissBreakOffer() }
            )
            .ksTransition(.opacity)
        } else {
            focusContent
        }
    }

    @ViewBuilder
    private var focusContent: some View {
        if engine.status == .running, let snapshot = engine.snapshot {
            ActiveSessionView(
                snapshot: snapshot,
                taskTitle: engine.linkedTask?.startableLabel,
                intention: app.reflection.morningIntention,
                showsDigits: app.settings.showDigitalTimer,
                showsCompanion: app.settings.companionEnabled,
                bodyDoubling: app.bodyDoubling
            ) {
                Task { await engine.endEarly() }
            }
            .ksTransition(.opacity)
        } else if engine.status == .finished, let finished = engine.finishedSession {
            SessionCompleteView(
                session: finished,
                linkedTask: engine.linkedTask,
                award: engine.lastAward,
                onCheckIn: app.settings.postSessionCheckIn
                    ? { quality in Task { await engine.recordPostCheckIn(quality: quality) } }
                    : nil,
                offersExtension: engine.offersExtension,
                extensionMode: .classicPomodoro,
                onContinue: { mode in Task { await engine.continueSession(as: mode) } },
                onMarkTaskDone: { Task { await engine.markLinkedTaskComplete() } },
                onDone: {
                    // The break offer is the next screen, not a button on this
                    // one — the completion screen already has a job.
                    stillness.offerBreak(after: finished, settings: app.settings)
                    engine.dismissCompletion()
                }
            )
            .ksTransition(.opacity)
        } else {
            homeOrOnboarding
        }
    }

    /// First launch goes to onboarding; every launch after goes to Today.
    @ViewBuilder
    private var homeOrOnboarding: some View {
        if !app.isReady && app.lastError == nil {
            // Launch is still reading settings. Drawing Today now would flash it
            // at someone who is about to see onboarding instead.
            KSScreen(state: .ready) {
                EmptyView()
            }
        } else if !app.settings.hasCompletedOnboarding, let onboardingModel {
            OnboardingView(model: onboardingModel)
                .ksTransition(.opacity)
        } else {
            homeStack
        }
    }

    // MARK: Home

    @ViewBuilder
    private var homeStack: some View {
        NavigationStack(path: $path) {
            Group {
                if let todayModel {
                    TodayView(
                        model: todayModel,
                        progress: app.progress,
                        onStartTask: { task in setupTask = SetupRequest(task: task) },
                        onJustStart: startJustStart,
                        onChooseMode: { setupTask = SetupRequest(task: nil) },
                        onEditTask: { task in path.append(.detail(task)) },
                        onOpenAllTasks: { path.append(.list) },
                        onOpenCollection: { path.append(.collection) },
                        medication: app.settings.medicationTrackingEnabled ? app.medication : nil,
                        onOpenMedication: { path.append(.medication) },
                        intention: app.reflection.morningIntention,
                        calmStreak: app.progress.calmStreak,
                        onOpenReflection: { path.append(.reflection) },
                        onOpenStillness: { path.append(.stillness) }
                    )
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TaskRoute.self) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        path.append(.insights)
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    // Reviewing aid only, and only in debug builds.
                    if Self.showsDesignSystemShortcut {
                        Button {
                            path.append(.gallery)
                        } label: {
                            Label("Design system", systemImage: "paintpalette")
                        }
                    }
                }
            }
        }
    }

    private static var showsDesignSystemShortcut: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    @ViewBuilder
    private func destination(for route: TaskRoute) -> some View {
        switch route {
        case .list:
            if let taskListModel {
                TaskListView(model: taskListModel) { task in
                    path.append(.detail(task))
                }
                .task { await taskListModel.load() }
            }

        case let .detail(task):
            TaskDetailScreen(
                task: task,
                repositories: app.repositories,
                clock: app.clock,
                calibration: app.calibration,
                autoPadsEstimates: app.settings.autoPadEstimates,
                onDeleted: { if !path.isEmpty { path.removeLast() } }
            )
            .onDisappear { Task { await refreshAll() } }

        case .collection:
            if let collectionModel {
                CollectionView(model: collectionModel)
                    .onDisappear { Task { await refreshAll() } }
            }

        case .insights:
            if let insightsModel {
                InsightsView(
                    model: insightsModel,
                    includesMedication: app.settings.medicationTrackingEnabled,
                    preferredWorkTime: app.settings.preferredWorkTime
                )
            }

        case .stillness:
            PracticeLibraryView(
                entries: stillness.libraryEntries(level: app.progress.level),
                tradition: app.settings.tradition,
                calmStreak: stillness.calmStreak,
                completedSits: stillness.completedSits,
                onStart: { practice, duration in
                    // The path is left alone. A sit replaces the whole screen
                    // while it runs, and finishing one puts the library back
                    // exactly where it was.
                    stillness.start(practice: practice, duration: duration)
                },
                onOpenReflection: { path.append(.reflection) },
                onChangeTradition: { tradition in
                    Task { await app.updateSettings { $0.tradition = tradition } }
                }
            )
            .task { await stillness.load() }

        case .reflection:
            ReflectionView(model: app.reflection, tradition: app.settings.tradition)

        case .medication:
            MedicationView(
                model: app.medication,
                settings: app.settings,
                onChangeSettings: { mutate in Task { await app.updateSettings(mutate) } }
            )
            .onDisappear { Task { await app.medication.load() } }

        case .settings:
            SettingsView(
                settings: app.settings,
                notificationStatus: app.notificationStatus,
                onOpen: { section in path.append(.settingsSection(section)) }
            )

        case let .settingsSection(section):
            if section == .data {
                DataExportScreen(repositories: app.repositories, clock: app.clock)
            } else {
                SettingsSectionView(
                    section: section,
                    settings: app.settings,
                    calibration: app.calibration,
                    notificationStatus: app.notificationStatus,
                    onChange: { mutate in Task { await app.updateSettings(mutate) } },
                    onRequestNotifications: { Task { await app.requestNotifications() } },
                    onOpenMedication: { path.append(.medication) }
                )
            }

        case .gallery:
            DesignSystemGallery()
        }
    }

    // MARK: Session setup

    private func setupSheet(for request: SetupRequest) -> some View {
        NavigationStack {
            SessionSetupView(
                settings: app.settings,
                preselectedTask: request.task,
                onStart: { plan in
                    setupTask = nil
                    Task { await engine.start(plan) }
                },
                onCancel: { setupTask = nil }
            )
        }
    }

    private func startJustStart() {
        let plan = SessionPlan.make(mode: .justStart, settings: app.settings)
        Task { await engine.start(plan) }
    }

    // MARK: Deep links

    /// Widget and Live Activity taps.
    ///
    /// A widget tap can cold-launch the app, so starting goes through the intent
    /// router, which waits until launch has recovered any session that was
    /// already running rather than starting a second one over it.
    private func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }

        switch link {
        case .justStart:
            Task { _ = await IntentRouter.shared.startSession(mode: .justStart) }
        case .today:
            path.removeAll()
        case .session:
            break
        }
    }

    // MARK: Models

    private func makeModelsIfNeeded() async {
        if todayModel == nil {
            todayModel = TodayModel(repositories: app.repositories, clock: app.clock)
        }
        if taskListModel == nil {
            taskListModel = TaskListModel(repositories: app.repositories, clock: app.clock)
        }
        if collectionModel == nil {
            collectionModel = CollectionModel(repositories: app.repositories, rewards: app.rewards)
        }
        if insightsModel == nil {
            insightsModel = InsightsModel(repositories: app.repositories, clock: app.clock)
        }
        await refreshAll()
    }

    /// Built only once launch has read the settings, so it starts from the
    /// user's real notification status rather than a guess.
    private func makeOnboardingModelIfNeeded() {
        guard app.isReady, !app.settings.hasCompletedOnboarding, onboardingModel == nil else { return }

        onboardingModel = OnboardingModel(
            repositories: app.repositories,
            clock: app.clock,
            initialSettings: app.settings,
            notificationStatus: app.notificationStatus,
            applySettings: { mutate in await app.updateSettings(mutate) },
            requestNotifications: {
                await app.requestNotifications()
                return app.notificationStatus
            },
            startSession: { plan in await engine.start(plan) }
        )
    }

    private func refreshAll() async {
        await todayModel?.load()
        await taskListModel?.load()
        await app.refreshProgress()
        await app.refreshCalibration()
        await app.reflection.load()
        if app.settings.medicationTrackingEnabled {
            await app.medication.load()
        }
        await app.refreshWidgets()
    }
}

/// Owns one `TaskDetailModel` for the life of one pushed screen.
///
/// `navigationDestination` re-runs its builder on every render, so constructing
/// the model inline there would throw away in-progress edits.
private struct TaskDetailScreen: View {
    @State private var model: TaskDetailModel
    private let calibration: EstimateCalibration
    private let autoPadsEstimates: Bool
    private let onDeleted: () -> Void

    init(
        task: FocusTask,
        repositories: any RepositoryProvider,
        clock: any DateProvider,
        calibration: EstimateCalibration,
        autoPadsEstimates: Bool,
        onDeleted: @escaping () -> Void
    ) {
        _model = State(initialValue: TaskDetailModel(task: task, repositories: repositories, clock: clock))
        self.calibration = calibration
        self.autoPadsEstimates = autoPadsEstimates
        self.onDeleted = onDeleted
    }

    var body: some View {
        TaskDetailView(
            model: model,
            calibration: calibration,
            autoPadsEstimates: autoPadsEstimates,
            onDeleted: onDeleted
        )
    }
}

/// Navigation targets reachable from Today.
enum TaskRoute: Hashable {
    case list
    case detail(FocusTask)
    case collection
    case insights
    case medication
    case stillness
    case reflection
    case settings
    case settingsSection(SettingsSection)
    case gallery
}

/// Wraps the optional task so `.sheet(item:)` can drive setup for both the
/// "work on this" and "choose a mode" paths.
private struct SetupRequest: Identifiable {
    let id = UUID()
    let task: FocusTask?
}

// `#Preview` bodies are compiled in Release too, so anything referencing a
// DEBUG-only helper has to be guarded.
#if DEBUG
#Preview {
    RootView()
        .environment(AppEnvironment.previewEmpty())
}
#endif
