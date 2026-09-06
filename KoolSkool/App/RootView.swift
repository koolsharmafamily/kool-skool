import SwiftUI

/// Switches between the three states of the focus flow and owns the scene-phase
/// wiring the engine depends on.
///
/// The home branch is still a placeholder — the real Today screen, with three
/// musts and the next tiny step, arrives in Milestone 3.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPresentingSetup = false
    @State private var statusModel: RootStatusModel?

    private var engine: FocusEngine { app.focusEngine }

    var body: some View {
        content
            .ksAnimation(KSAnimation.gentle, value: engine.status)
            .sheet(isPresented: $isPresentingSetup) { setupSheet }
            .task { await engine.restore() }
            .onChange(of: scenePhase) { _, phase in
                Task { await engine.scenePhaseChanged(to: phase) }
            }
    }

    @ViewBuilder
    private var content: some View {
        if engine.status == .running, let snapshot = engine.snapshot {
            ActiveSessionView(snapshot: snapshot, taskTitle: nil) {
                Task { await engine.endEarly() }
            }
            .ksTransition(.opacity)
        } else if engine.status == .finished, let finished = engine.finishedSession {
            SessionCompleteView(
                session: finished,
                offersExtension: engine.offersExtension,
                extensionMode: .classicPomodoro,
                onContinue: { mode in Task { await engine.continueSession(as: mode) } },
                onDone: { engine.dismissCompletion() }
            )
            .ksTransition(.opacity)
        } else {
            home
        }
    }

    private var setupSheet: some View {
        NavigationStack {
            SessionSetupView(
                settings: app.settings,
                onStart: { plan in
                    isPresentingSetup = false
                    Task { await engine.start(plan) }
                },
                onCancel: { isPresentingSetup = false }
            )
        }
    }

    // MARK: Home

    private var home: some View {
        NavigationStack {
            KSScreen(state: .ready) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        header
                        startCard

                        if let warning = app.storeWarning {
                            warningCard(warning)
                        }

                        progressCard

                        if let statusModel {
                            StoreCheckCard(model: statusModel, clock: app.clock)
                        }

                        galleryCard
                    }
                    .padding(.vertical, KSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            let model = statusModel ?? RootStatusModel(repositories: app.repositories)
            statusModel = model
            await model.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
            Text("Kool Skool")
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            Text("Milestone 2 — the focus engine. The Today screen lands next.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Just Start gets the primary button and asks nothing at all — no mode, no
    /// intent, no rating. Every question here is another chance to bounce, and
    /// the whole pitch of the mode is that starting costs nothing.
    private var startCard: some View {
        VStack(spacing: KSSpacing.sm) {
            KSPrimaryButton(title: "Just start", systemImage: "bolt.fill") {
                let plan = SessionPlan.make(mode: .justStart, settings: app.settings)
                Task { await engine.start(plan) }
            }

            Text("Five minutes. Quit after if you want — it still counts.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            KSSecondaryButton(title: "Choose a mode", systemImage: "slider.horizontal.3") {
                isPresentingSetup = true
            }
        }
    }

    private func warningCard(_ warning: String) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                KSTag(text: "Storage", systemImage: "exclamationmark.triangle.fill", state: .overrun)
                Text(warning)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
            }
        }
    }

    private var progressCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Progress")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                HStack(spacing: KSSpacing.xs) {
                    KSTag(text: "Level \(app.progress.level)", systemImage: "chart.line.uptrend.xyaxis")
                    KSTag(text: "\(app.progress.coins) coins", systemImage: "circle.hexagongrid.fill", state: .breakTime)
                    KSTag(text: "Day \(app.progress.currentStreak)", systemImage: "flame.fill", state: .overrun)
                }

                Text("XP and streaks start moving in Milestone 4.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var galleryCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Design system")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    HStack(spacing: KSSpacing.xs) {
                        Image(systemName: "paintpalette.fill")
                        Text("Open the gallery")
                    }
                    .ksFont(KSFont.label)
                    .frame(maxWidth: .infinity, minHeight: KSSize.secondaryButtonHeight)
                }
                .buttonStyle(KSSecondaryButtonStyle(state: .ready))
            }
        }
    }
}

/// The repository round-trip check. Reads counts through the protocols, exactly
/// the way a real feature does.
private struct StoreCheckCard: View {
    let model: RootStatusModel
    let clock: any DateProvider

    var body: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Store")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                if let error = model.error {
                    Text(error)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.accent(.overrun))
                } else {
                    Text("\(model.taskCount) tasks, \(model.sessionCount) sessions, \(model.sitCount) sits.")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                #if DEBUG
                KSSecondaryButton(title: "Write a sample row", systemImage: "plus") {
                    Task { await model.writeSampleTask(clock: clock) }
                }
                #endif
            }
        }
    }
}

// `#Preview` bodies are compiled in Release too, so anything referencing a
// DEBUG-only helper has to be guarded.
#if DEBUG
#Preview {
    RootView()
        .environment(AppEnvironment.previewEmpty())
}
#endif
