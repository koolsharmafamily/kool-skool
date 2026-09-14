import SwiftUI

/// One of the three things today.
///
/// Two targets, both obvious: the circle finishes it, the text starts a session
/// on it. No hidden gestures — a long press that nobody discovers is the same as
/// a feature that does not exist.
struct MustCard: View {
    let task: FocusTask
    let onToggleComplete: () -> Void
    let onStart: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 26

    private var showsTitleSeparately: Bool {
        task.startableLabel != task.title
    }

    /// Never below the 44pt minimum, and bigger when the icon grows with text.
    private var tapSide: CGFloat { max(KSSize.minimumTapTarget, iconSize + 18) }

    var body: some View {
        KSCard {
            HStack(alignment: .top, spacing: KSSpacing.sm) {
                checkbox

                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Button(action: onStart) {
                        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                            Text(task.startableLabel)
                                .ksFont(KSFont.headline)
                                .foregroundStyle(task.isCompleted ? KSColor.textTertiary : KSColor.textPrimary)
                                .strikethrough(task.isCompleted)
                                .multilineTextAlignment(.leading)

                            if showsTitleSeparately {
                                Text(task.title)
                                    .ksFont(KSFont.caption)
                                    .foregroundStyle(KSColor.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(task.isCompleted ? "Already done" : "Starts a session on this")
                    // The context menu's actions, where VoiceOver can find them.
                    .accessibilityActions {
                        Button("Edit", action: onEdit)
                        Button("Not today", action: onRemove)
                    }

                    if TaskSuggestion.needsSmallerFirstStep(task) {
                        Button(action: onEdit) { nudge }
                            .buttonStyle(.plain)
                            .accessibilityHint("Add the smallest first step")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Not today", systemImage: "arrow.uturn.left", action: onRemove)
        }
    }

    private var checkbox: some View {
        Button(action: onToggleComplete) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(task.isCompleted ? KSColor.accent(.focusing) : KSColor.textTertiary)
                .frame(width: tapSide, height: tapSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? "Mark not done" : "Mark done")
    }

    /// Only shown for tasks that actually look daunting. Prompting for a smaller
    /// step on "buy milk" is noise, and noise is why people stop reading prompts.
    private var nudge: some View {
        Label("No first step yet", systemImage: "scissors")
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.accent(.breakTime))
            .padding(.top, KSSpacing.xxs)
    }
}

/// The dashed placeholder for a slot nobody has filled.
struct MustSlotCard: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 26

    var body: some View {
        Button(action: action) {
            HStack(spacing: KSSpacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: iconSize, weight: .semibold))
                Text("Pick something")
                    .ksFont(KSFont.headline)
                Spacer()
            }
            .foregroundStyle(KSColor.textTertiary)
            .padding(KSSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KSRadius.lg, style: .continuous)
                    .strokeBorder(
                        KSColor.hairline,
                        style: StrokeStyle(lineWidth: KSStroke.medium, dash: [6, 5])
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a must for today")
    }
}

#Preview("Must cards") {
    var task = FocusTask()
    task.title = "Draft the essay"
    task.nextStep = "Open the outline file"
    task.estimateMinutes = 90

    var plain = FocusTask()
    plain.title = "Email the supervisor"

    return VStack(spacing: KSSpacing.sm) {
        MustCard(task: task, onToggleComplete: {}, onStart: {}, onEdit: {}, onRemove: {})
        MustCard(task: plain, onToggleComplete: {}, onStart: {}, onEdit: {}, onRemove: {})
        MustSlotCard {}
    }
    .padding(KSSpacing.screenMargin)
    .frame(maxHeight: .infinity)
    .background(KSColor.canvas)
}
