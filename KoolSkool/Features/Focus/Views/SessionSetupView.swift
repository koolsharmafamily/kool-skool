import SwiftUI

/// The pre-session ritual. Ten seconds, and this screen is where people bounce,
/// so it is one screen with no scrolling and no required fields.
///
/// Task selection arrives in Milestone 3 when tasks exist; the view already
/// accepts one and passes its id through to the session.
struct SessionSetupView: View {
    let settings: AppSettings
    var preselectedTask: FocusTask?
    let onStart: (SessionPlan) -> Void
    let onCancel: () -> Void

    @State private var mode: SessionMode
    @State private var intent: String = ""
    @State private var commitment: String = ""
    @State private var resistance: Rating?
    @State private var energy: Rating?
    @State private var mood: Rating?
    @FocusState private var intentFocused: Bool

    init(
        settings: AppSettings,
        preselectedTask: FocusTask? = nil,
        onStart: @escaping (SessionPlan) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.settings = settings
        self.preselectedTask = preselectedTask
        self.onStart = onStart
        self.onCancel = onCancel
        // A task already flagged as hard to start opens on Just Start, whatever
        // the default is.
        _mode = State(initialValue: TaskSuggestion.suggestedMode(for: preselectedTask, settings: settings))
    }

    var body: some View {
        KSScreen(state: .ready) {
            VStack(alignment: .leading, spacing: KSSpacing.md) {
                // Still one screen with no extra steps. It scrolls only when the
                // content outgrows it — at the largest text sizes — and Start
                // stays pinned below either way.
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        if let task = preselectedTask { taskCard(task) }
                        modeSection

                        // One or the other, never both — they ask nearly the same
                        // question and this screen has ten seconds before people bounce.
                        if settings.commitmentCardEnabled {
                            CommitmentField(
                                text: $commitment,
                                minutes: plannedMinutes,
                                isCountUp: mode.defaultProfile.countsUp
                            )
                        } else {
                            intentSection
                        }

                        resistanceSection

                        // Off by default. When on it is one compact block, never a
                        // separate step, and blank is a perfectly good answer.
                        if settings.preSessionCheckIn {
                            checkInSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                KSPrimaryButton(title: startTitle, systemImage: "play.fill") {
                    onStart(plan)
                }
            }
            .padding(.vertical, KSSpacing.lg)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
        .navigationTitle("Set up")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    /// The one task. Nothing else is on this screen, and nothing else will be on
    /// screen once the session starts.
    private func taskCard(_ task: FocusTask) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text("Working on")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                Text(task.startableLabel)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                if task.startableLabel != task.title {
                    Text(task.title)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            sectionLabel("Mode")

            ScrollView(.horizontal) {
                HStack(spacing: KSSpacing.xs) {
                    ForEach(SessionMode.pickerOrder) { option in
                        ModeChip(mode: option, isSelected: option == mode) {
                            KSHaptics.shared.fire(.selection)
                            mode = option
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)

            Text(mode.tagline)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)

            // Said out loud, so the app is never quietly deciding things.
            if let reason = TaskSuggestion.reason(for: preselectedTask, settings: settings) {
                Text(reason)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.accent(.breakTime))
            }
        }
    }

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            sectionLabel("What does done look like?")

            TextField("Optional", text: $intent, axis: .vertical)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
                .lineLimit(1...3)
                .focused($intentFocused)
                .submitLabel(.done)
                .padding(KSSpacing.sm)
                .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                        .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
                )
                .onSubmit { intentFocused = false }
        }
    }

    private var resistanceSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            sectionLabel("How much resistance?")

            HStack(spacing: KSSpacing.xs) {
                ForEach(Rating.all, id: \.rawValue) { value in
                    RatingPip(
                        value: value,
                        isSelected: resistance == value,
                        label: Self.resistanceLabel(value)
                    ) {
                        KSHaptics.shared.fire(.selection)
                        resistance = resistance == value ? nil : value
                    }
                }
            }

            Text(resistance.map { "\(Self.resistanceLabel($0)). High-resistance tasks pay out more when you finish them." }
                ?? "Skip it if you would rather not.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            KSRatingRow(title: "Energy", selection: $energy, isCompact: true)
            KSRatingRow(title: "Mood", selection: $mood, isCompact: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.label)
            .foregroundStyle(KSColor.textSecondary)
    }

    // MARK: Derived

    private var plan: SessionPlan {
        SessionPlan(
            mode: mode,
            plannedDuration: settings.resolvedProfile(for: mode).workDuration,
            intent: intent,
            resistance: resistance,
            taskID: preselectedTask?.id,
            commitment: commitment,
            energy: settings.preSessionCheckIn ? energy : nil,
            mood: settings.preSessionCheckIn ? mood : nil
        )
    }

    private var plannedMinutes: Int {
        Int(settings.resolvedProfile(for: mode).workDuration / 60)
    }

    private var startTitle: String {
        mode.defaultProfile.countsUp ? "Start" : "Start \(plannedMinutes) minutes"
    }

    static func resistanceLabel(_ rating: Rating) -> String {
        switch rating.rawValue {
        case 1: "Easy to start"
        case 2: "Slightly sticky"
        case 3: "Sticky"
        case 4: "Hard to start"
        default: "Been avoiding it"
        }
    }
}

private struct ModeChip: View {
    let mode: SessionMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.displayName)
                .ksFont(KSFont.label)
                .padding(.horizontal, KSSpacing.md)
                .frame(minHeight: KSSize.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
        .background(
            isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
            in: Capsule(style: .continuous)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(mode.tagline)
    }
}

private struct RatingPip: View {
    let value: Rating
    let isSelected: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value.rawValue)")
                .ksFont(KSFont.label)
                .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
        .background(
            isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
            in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Setup") {
    NavigationStack {
        SessionSetupView(settings: AppSettings(), onStart: { _ in }, onCancel: {})
    }
}
