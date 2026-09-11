import SwiftUI

/// The home screen. Three things, and everything else one tap away.
///
/// The rule of three is the anti-overwhelm feature, so this screen renders the
/// musts and nothing that competes with them. The full list exists, but it is
/// deliberately quiet and behind a button.
struct TodayView: View {
    let model: TodayModel
    let progress: UserProgress
    let onStartTask: (FocusTask) -> Void
    let onJustStart: () -> Void
    let onChooseMode: () -> Void
    let onEditTask: (FocusTask) -> Void
    let onOpenAllTasks: () -> Void
    let onOpenCollection: () -> Void
    /// Nil unless the user has switched medication tracking on. Nothing about
    /// medication renders otherwise.
    var medication: MedicationModel?
    var onOpenMedication: () -> Void = {}

    @State private var isPresentingBrainDump = false
    @State private var isPresentingPicker = false

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    statusRow
                    heading
                    freezeNote

                    if let notice = model.notice {
                        noticeBanner(notice)
                    }

                    mustList
                    startSection
                    secondaryRow

                    if let medication {
                        MedicationRow(model: medication, onOpen: onOpenMedication)
                    }

                    if let error = model.error {
                        Text(error)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.accent(.overrun))
                    }
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $isPresentingBrainDump) {
            BrainDumpSheet(
                onCapture: { text in
                    isPresentingBrainDump = false
                    Task { await model.capture(text) }
                },
                onCancel: { isPresentingBrainDump = false }
            )
        }
        .sheet(isPresented: $isPresentingPicker) {
            MustPickerSheet(
                candidates: model.candidates,
                remainingSlots: model.remainingMustSlots,
                onPick: { task in
                    isPresentingPicker = false
                    Task { await model.addMust(task) }
                },
                onCreate: { text in
                    isPresentingPicker = false
                    Task { await model.captureAsMust(text) }
                },
                onCancel: { isPresentingPicker = false }
            )
        }
    }

    // MARK: Sections

    private var statusRow: some View {
        HStack(spacing: KSSpacing.xs) {
            KSTag(text: progress.streakLabel, systemImage: "flame.fill", state: .overrun)
            KSTag(text: "Level \(progress.level)", systemImage: "chart.line.uptrend.xyaxis")

            Button(action: onOpenCollection) {
                KSTag(text: "\(progress.coins)", systemImage: "circle.hexagongrid.fill", state: .breakTime)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(progress.coins) coins. Opens your collection.")

            Spacer()
        }
    }

    /// Only mentioned when it is actually load-bearing. Nobody needs to be told
    /// about a safety net they are not standing on.
    @ViewBuilder
    private var freezeNote: some View {
        if progress.currentStreak > 0 && progress.freezesUsedThisMonth > 0 {
            Text(freezeCopy)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
    }

    private var freezeCopy: String {
        let used = progress.freezesUsedThisMonth
        let left = progress.freezesRemaining
        let daysCovered = used == 1 ? "A missed day was" : "\(used) missed days were"
        let remaining = left == 1 ? "1 freeze left" : "\(left) freezes left"
        return "\(daysCovered) covered for you. \(remaining) this month."
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
            Text("Today")
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            Text(subtitle)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var mustList: some View {
        VStack(spacing: KSSpacing.sm) {
            ForEach(model.musts) { task in
                MustCard(
                    task: task,
                    onToggleComplete: { Task { await model.toggleComplete(task) } },
                    onStart: { onStartTask(task) },
                    onEdit: { onEditTask(task) },
                    onRemove: { Task { await model.removeMust(task) } }
                )
            }

            // One slot at a time. Three empty boxes on a fresh install looks
            // like three chores rather than an invitation.
            if model.remainingMustSlots > 0 {
                MustSlotCard { isPresentingPicker = true }
            }
        }
    }

    private var startSection: some View {
        VStack(spacing: KSSpacing.sm) {
            KSPrimaryButton(title: "Just start", systemImage: "bolt.fill", action: onJustStart)

            Text("Five minutes. Quit after if you want — it still counts.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            KSSecondaryButton(title: "Choose a mode", systemImage: "slider.horizontal.3", action: onChooseMode)
        }
    }

    private var secondaryRow: some View {
        HStack(spacing: KSSpacing.sm) {
            KSSecondaryButton(title: "Brain dump", systemImage: "tray.and.arrow.down") {
                isPresentingBrainDump = true
            }
            KSSecondaryButton(title: allTasksTitle, systemImage: "list.bullet", action: onOpenAllTasks)
        }
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

    // MARK: Copy

    private var subtitle: String {
        let open = model.openMusts.count
        let done = model.completedMusts.count

        if open == 0 && done == 0 {
            return "Nothing pinned yet. Pick up to three — or just start and work it out as you go."
        }
        if open == 0 {
            return done == 1 ? "That was the one. Anything else today is a bonus."
                             : "All \(done) done. Anything else today is a bonus."
        }
        if done > 0 {
            return "\(done) down, \(open) to go."
        }
        return open == 1 ? "One thing. That's it." : "\(open) things. That's it."
    }

    private var allTasksTitle: String {
        model.otherTaskCount == 0 ? "All tasks" : "All tasks (\(model.otherTaskCount))"
    }
}
