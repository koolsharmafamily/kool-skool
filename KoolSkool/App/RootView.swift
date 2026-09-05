import SwiftUI

/// Milestone 1 placeholder.
///
/// This is not a feature screen. It exists to prove the stack end to end — the
/// container opens, the repositories answer, the design system renders — and it
/// gets replaced by the Today screen in Milestone 3.
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var model: RootStatusModel?

    var body: some View {
        NavigationStack {
            KSScreen(state: .ready) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        header

                        if let warning = appEnvironment.storeWarning {
                            warningCard(warning)
                        }

                        progressCard

                        if let model {
                            StoreCheckCard(model: model, clock: appEnvironment.clock)
                        }

                        navigationCard
                    }
                    .padding(.vertical, KSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            let model = model ?? RootStatusModel(repositories: appEnvironment.repositories)
            self.model = model
            await model.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
            Text("Kool Skool")
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            Text("Milestone 1 — skeleton, design system, models, repositories.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
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
                    KSTag(text: "Level \(appEnvironment.progress.level)", systemImage: "chart.line.uptrend.xyaxis")
                    KSTag(text: "\(appEnvironment.progress.coins) coins", systemImage: "circle.hexagongrid.fill", state: .breakTime)
                    KSTag(text: "Day \(appEnvironment.progress.currentStreak)", systemImage: "flame.fill", state: .overrun)
                }

                Text("\(appEnvironment.progress.xpIntoCurrentLevel) / \(appEnvironment.progress.xpNeededForNextLevel) XP to level \(appEnvironment.progress.level + 1)")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var navigationCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Design system")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Text("Every colour, type size, and component in one place. Check it in both appearances and at the largest Dynamic Type size.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

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
/// the way a real feature will.
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
