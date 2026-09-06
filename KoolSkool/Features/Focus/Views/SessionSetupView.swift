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
    @State private var resistance: Rating?
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
        _mode = State(initialValue: settings.defaultMode)
    }

    var body: some View {
        KSScreen(state: .ready) {
            VStack(alignment: .leading, spacing: KSSpacing.lg) {
                modeSection
                intentSection
                resistanceSection
                Spacer(minLength: 0)
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
            taskID: preselectedTask?.id
        )
    }

    private var startTitle: String {
        let minutes = Int(settings.resolvedProfile(for: mode).workDuration / 60)
        return mode.defaultProfile.countsUp ? "Start" : "Start \(minutes) minutes"
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
