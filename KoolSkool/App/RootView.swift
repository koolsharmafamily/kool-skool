import SwiftUI

/// Switches between the three states of the focus flow, owns the scene-phase
/// wiring the engine depends on, and hosts the task navigation.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var todayModel: TodayModel?
    @State private var taskListModel: TaskListModel?
    @State private var path: [TaskRoute] = []
    @State private var setupTask: SetupRequest?

    private var engine: FocusEngine { app.focusEngine }

    var body: some View {
        content
            .ksAnimation(KSAnimation.gentle, value: engine.status)
            .sheet(item: $setupTask) { request in
                setupSheet(for: request)
            }
            .task {
                await engine.restore()
                await makeModelsIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                Task { await engine.scenePhaseChanged(to: phase) }
            }
            .onChange(of: engine.status) { _, status in
                // Coming back from a session, Today may be stale — a task could
                // have been marked done on the completion screen.
                if status == .idle { Task { await refreshAll() } }
            }
    }

    @ViewBuilder
    private var content: some View {
        if engine.status == .running, let snapshot = engine.snapshot {
            ActiveSessionView(snapshot: snapshot, taskTitle: engine.linkedTask?.startableLabel) {
                Task { await engine.endEarly() }
            }
            .ksTransition(.opacity)
        } else if engine.status == .finished, let finished = engine.finishedSession {
            SessionCompleteView(
                session: finished,
                linkedTask: engine.linkedTask,
                offersExtension: engine.offersExtension,
                extensionMode: .classicPomodoro,
                onContinue: { mode in Task { await engine.continueSession(as: mode) } },
                onMarkTaskDone: { Task { await engine.markLinkedTaskComplete() } },
                onDone: { engine.dismissCompletion() }
            )
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
                        onOpenAllTasks: { path.append(.list) }
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
                ToolbarItem(placement: .topBarTrailing) {
                    // Reviewing aid only. Settings, in Milestone 10, is where a
                    // real entry point for this would live if it ships at all.
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
                onDeleted: { if !path.isEmpty { path.removeLast() } }
            )
            .onDisappear { Task { await refreshAll() } }

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

    // MARK: Models

    private func makeModelsIfNeeded() async {
        if todayModel == nil {
            todayModel = TodayModel(repositories: app.repositories, clock: app.clock)
        }
        if taskListModel == nil {
            taskListModel = TaskListModel(repositories: app.repositories, clock: app.clock)
        }
        await refreshAll()
    }

    private func refreshAll() async {
        await todayModel?.load()
        await taskListModel?.load()
        await app.refreshProgress()
    }
}

/// Owns one `TaskDetailModel` for the life of one pushed screen.
///
/// `navigationDestination` re-runs its builder on every render, so constructing
/// the model inline there would throw away in-progress edits.
private struct TaskDetailScreen: View {
    @State private var model: TaskDetailModel
    private let onDeleted: () -> Void

    init(
        task: FocusTask,
        repositories: any RepositoryProvider,
        clock: any DateProvider,
        onDeleted: @escaping () -> Void
    ) {
        _model = State(initialValue: TaskDetailModel(task: task, repositories: repositories, clock: clock))
        self.onDeleted = onDeleted
    }

    var body: some View {
        TaskDetailView(model: model, onDeleted: onDeleted)
    }
}

/// Navigation targets reachable from Today.
enum TaskRoute: Hashable {
    case list
    case detail(FocusTask)
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
