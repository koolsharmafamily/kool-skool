import SwiftUI

/// Task editor and step splitter.
///
/// The next tiny step gets top billing — above the notes, above the steps —
/// because it is the field that decides whether the task ever gets started.
struct TaskDetailView: View {
    @Bindable var model: TaskDetailModel
    var calibration: EstimateCalibration = .unknown
    var autoPadsEstimates: Bool = false
    let onDeleted: () -> Void

    @State private var newStepTitle = ""
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .title3) private var stepIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .title2) private var addIconSize: CGFloat = 26

    private enum Field: Hashable {
        case title, nextStep, notes, newStep
    }

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    if let notice = model.notice {
                        noticeBanner(notice)
                    }

                    titleField
                    nextStepField
                    stepsSection
                    detailsSection
                    dangerZone
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.toggleComplete() }
                } label: {
                    Label(
                        model.draft.isCompleted ? "Reopen" : "Mark done",
                        systemImage: model.draft.isCompleted ? "arrow.uturn.left" : "checkmark"
                    )
                }
            }
        }
        .task { await model.reload() }
        .onDisappear { Task { await model.save() } }
        .onChange(of: model.wasDeleted) { _, deleted in
            if deleted { onDeleted() }
        }
    }

    // MARK: Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            fieldLabel("Task")

            TextField("What is it?", text: $model.draft.title, axis: .vertical)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .lineLimit(1...3)
                .focused($focusedField, equals: .title)
                .submitLabel(.done)
                .onSubmit(commit)
                .padding(KSSpacing.sm)
                .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
        }
    }

    private var nextStepField: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            fieldLabel("Next tiny step")

            TextField("Open the file. Write one sentence.", text: $model.draft.nextStep, axis: .vertical)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
                .lineLimit(1...3)
                .focused($focusedField, equals: .nextStep)
                .submitLabel(.done)
                .onSubmit(commit)
                .padding(KSSpacing.sm)
                .background(
                    KSColor.accentWash(.ready, opacity: 0.10),
                    in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                        .strokeBorder(KSColor.accent(.ready).opacity(0.35), lineWidth: KSStroke.hairline)
                )

            Text(model.nextStepPrompt)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
    }

    // MARK: Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            HStack {
                fieldLabel("Steps")
                Spacer()
                if let progress = model.stepProgressLabel {
                    Text(progress)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                }
            }

            ForEach(model.steps) { step in
                stepRow(step)
            }

            addStepField
            templateRow
        }
    }

    private func stepRow(_ step: TaskStep) -> some View {
        HStack(spacing: KSSpacing.sm) {
            Button {
                Task { await model.toggleStep(step) }
            } label: {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: stepIconSize, weight: .semibold))
                    .foregroundStyle(step.isDone ? KSColor.accent(.focusing) : KSColor.textTertiary)
                    .frame(width: max(KSSize.minimumTapTarget, stepIconSize + 24), height: max(KSSize.minimumTapTarget, stepIconSize + 24))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step.isDone ? "Mark step not done" : "Mark step done")

            Text(step.title)
                .ksFont(KSFont.body)
                .foregroundStyle(step.isDone ? KSColor.textTertiary : KSColor.textPrimary)
                .strikethrough(step.isDone)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await model.deleteStep(step) }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(KSColor.textTertiary)
                    .frame(width: KSSize.minimumTapTarget, height: KSSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete step")
        }
        .padding(.horizontal, KSSpacing.xs)
        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous))
    }

    private var addStepField: some View {
        HStack(spacing: KSSpacing.xs) {
            TextField("Add a step", text: $newStepTitle)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
                .focused($focusedField, equals: .newStep)
                .submitLabel(.next)
                .onSubmit(addStep)
                .padding(KSSpacing.sm)
                .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))

            Button(action: addStep) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: addIconSize))
                    .foregroundStyle(KSColor.accent(.ready))
            }
            .buttonStyle(.plain)
            .disabled(newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Add step")
        }
    }

    /// Offline templates. The AI-assisted split is a later version; v1 makes no
    /// network calls, and this row is the shape it would slot into.
    private var templateRow: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("Or start from a shape")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)

            ScrollView(.horizontal) {
                HStack(spacing: KSSpacing.xs) {
                    ForEach(StepTemplate.allCases) { template in
                        Button {
                            Task { await model.applyTemplate(template) }
                        } label: {
                            Text(template.displayName)
                                .ksFont(KSFont.label)
                                .padding(.horizontal, KSSpacing.md)
                                .frame(minHeight: KSSize.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(KSColor.textPrimary)
                        .background(KSColor.surfaceRaised, in: Capsule(style: .continuous))
                        .accessibilityHint("Replaces the steps with: \(template.steps.joined(separator: ", "))")
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            Toggle(isOn: mustBinding) {
                Text("One of today's three")
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
            }

            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                fieldLabel("Notes")
                TextField("Anything worth remembering", text: $model.draft.notes, axis: .vertical)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                    .lineLimit(2...6)
                    .focused($focusedField, equals: .notes)
                    .padding(KSSpacing.sm)
                    .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
            }

            estimateRow
        }
    }

    private var estimateRow: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            fieldLabel("Estimate")

            HStack(spacing: KSSpacing.xs) {
                ForEach(Self.estimateChoices, id: \.self) { minutes in
                    let stored = storedEstimate(for: minutes)
                    let isSelected = model.draft.estimateMinutes == stored

                    Button {
                        model.draft.estimateMinutes = isSelected ? nil : stored
                        Task { await model.save() }
                    } label: {
                        Text("\(minutes)m")
                            .ksFont(KSFont.label)
                            .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
                    .background(
                        isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                    )
                    .accessibilityLabel(estimateLabel(tapped: minutes, stored: stored))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }

            estimateFootnote
        }
    }

    /// What the buttons say — what you *think* it will take. What gets stored can
    /// differ, and when it does the footnote says so out loud.
    private static let estimateChoices = [15, 30, 60, 120]

    private func storedEstimate(for minutes: Int) -> Int {
        autoPadsEstimates ? EstimateCalibrator.padded(minutes, using: calibration) : minutes
    }

    @ViewBuilder
    private var estimateFootnote: some View {
        if autoPadsEstimates, calibration.isReliable, let short = calibration.shortLabel {
            Text("Padded to match your history — your estimates run \(short). Recorded as \(model.draft.estimateMinutes.map(String.init) ?? "—") min.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.accent(.breakTime))
        } else if let summary = calibration.summary {
            Text(summary)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        } else {
            Text("Rough is fine. After \(EstimateCalibrator.minimumSamples) finished tasks the app can tell you how far off these usually run.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
    }

    private func estimateLabel(tapped: Int, stored: Int) -> String {
        stored == tapped
            ? "\(tapped) minutes"
            : "\(tapped) minutes, recorded as \(stored)"
    }

    private var dangerZone: some View {
        KSSecondaryButton(title: "Delete task", systemImage: "trash", role: .destructive) {
            Task { await model.delete() }
        }
    }

    // MARK: Bits

    private var mustBinding: Binding<Bool> {
        Binding(
            get: { model.isMustToday },
            set: { newValue in Task { await model.setMustToday(newValue) } }
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.label)
            .foregroundStyle(KSColor.textSecondary)
    }

    private func noticeBanner(_ notice: String) -> some View {
        KSCard {
            HStack(alignment: .top, spacing: KSSpacing.xs) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(KSColor.accent(.breakTime))
                Text(notice)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textPrimary)
                Spacer(minLength: 0)
                Button("OK") { model.dismissNotice() }
                    .ksFont(KSFont.label)
            }
        }
    }

    private func addStep() {
        let title = newStepTitle
        newStepTitle = ""
        Task { await model.addStep(title) }
    }

    private func commit() {
        focusedField = nil
        Task { await model.save() }
    }
}
