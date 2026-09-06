import SwiftUI

/// Everything. Deliberately one tap away from Today and deliberately quieter
/// than it — this is the screen the rule of three exists to protect people from
/// having to look at.
struct TaskListView: View {
    let model: TaskListModel
    let onOpen: (FocusTask) -> Void

    @State private var isPresentingBrainDump = false

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    if let notice = model.notice {
                        noticeBanner(notice)
                    }

                    if model.isEmpty {
                        emptyState
                    } else {
                        section("Today", tasks: model.musts, isMustSection: true)
                        section("Inbox", tasks: model.inbox, isMustSection: false)
                        completedSection
                    }
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingBrainDump = true
                } label: {
                    Label("Brain dump", systemImage: "plus")
                }
            }
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
    }

    @ViewBuilder
    private func section(_ title: String, tasks: [FocusTask], isMustSection: Bool) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text(title)
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textSecondary)

                ForEach(tasks) { task in
                    TaskRow(
                        task: task,
                        isMustToday: isMustSection,
                        onToggleComplete: { Task { await model.toggleComplete(task) } },
                        onOpen: { onOpen(task) },
                        onToggleMust: { Task { await model.toggleMust(task) } },
                        onDelete: { Task { await model.delete(task) } }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        if !model.completed.isEmpty {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("Recently done")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textSecondary)

                ForEach(model.completed) { task in
                    TaskRow(
                        task: task,
                        isMustToday: false,
                        onToggleComplete: { Task { await model.toggleComplete(task) } },
                        onOpen: { onOpen(task) },
                        onToggleMust: { Task { await model.toggleMust(task) } },
                        onDelete: { Task { await model.delete(task) } }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("Nothing here yet")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
                Text("Tap the plus and empty your head into it. One line per thing. Sorting it out is optional and mostly unnecessary.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
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
}

/// One row. The star pins it to today; the circle finishes it; the rest opens it.
struct TaskRow: View {
    let task: FocusTask
    let isMustToday: Bool
    let onToggleComplete: () -> Void
    let onOpen: () -> Void
    let onToggleMust: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: KSSpacing.sm) {
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? KSColor.accent(.focusing) : KSColor.textTertiary)
                    .frame(width: KSSize.minimumTapTarget, height: KSSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Text(task.title)
                        .ksFont(KSFont.body)
                        .foregroundStyle(task.isCompleted ? KSColor.textTertiary : KSColor.textPrimary)
                        .strikethrough(task.isCompleted)
                        .multilineTextAlignment(.leading)

                    if let detail = subtitle {
                        Text(detail)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleMust) {
                Image(systemName: isMustToday ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isMustToday ? KSColor.accent(.breakTime) : KSColor.textTertiary)
                    .frame(width: KSSize.minimumTapTarget, height: KSSize.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMustToday ? "Remove from today" : "Add to today")
        }
        .padding(.horizontal, KSSpacing.sm)
        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    private var subtitle: String? {
        var parts: [String] = []
        if !task.nextStep.isEmpty { parts.append(task.nextStep) }

        let liveSteps = task.steps.filter { !$0.isDeleted }
        if !liveSteps.isEmpty {
            parts.append("\(task.completedStepCount)/\(liveSteps.count) steps")
        }
        if let estimate = task.estimateMinutes {
            parts.append("~\(estimate) min")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
