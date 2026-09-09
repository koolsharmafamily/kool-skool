import SwiftUI

/// The post-session screen.
///
/// Says honestly what happened, pays out, and offers to keep going. The
/// celebration plays over the top on arrival and gets out of the way after a
/// second and a half, or sooner if tapped.
///
/// The energy check-in lands in Milestone 7; that space is left empty rather
/// than filled with a placeholder.
struct SessionCompleteView: View {
    let session: FocusSession
    var linkedTask: FocusTask?
    var award: AwardOutcome?
    let offersExtension: Bool
    let extensionMode: SessionMode
    let onContinue: (SessionMode) -> Void
    let onMarkTaskDone: () -> Void
    let onDone: () -> Void

    @State private var hasCelebrated = false

    private var minutes: Int { session.actualMinutes }
    private var plannedMinutes: Int { Int(session.plannedDuration / 60) }

    var body: some View {
        KSScreen(state: session.wasCompleted ? .focusing : .ready) {
            VStack(alignment: .leading, spacing: KSSpacing.lg) {
                Spacer(minLength: KSSpacing.xl)

                headline
                if let award, award.hasAnythingToShow { RewardSummary(award: award) }

                // The commitment replaces the intent when it was used, so only
                // one of these ever appears.
                if !session.commitment.isEmpty {
                    CommitmentRecap(
                        commitment: session.commitment,
                        minutes: minutes,
                        kept: session.wasCompleted
                    )
                } else if !session.intent.isEmpty {
                    intentCard
                }
                if let task = linkedTask { taskCard(task) }

                Spacer(minLength: KSSpacing.md)
                actions
            }
            .padding(.vertical, KSSpacing.lg)
        }
        .overlay {
            if let award, !hasCelebrated, award.hasAnythingToShow {
                CelebrationOverlay(award: award) { hasCelebrated = true }
                    .ksTransition(.opacity)
            }
        }
        .ksAnimation(KSAnimation.snappy, value: hasCelebrated)
    }

    // MARK: Pieces

    private var headline: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text(title)
                .ksFont(KSFont.title)
                .foregroundStyle(KSColor.textPrimary)

            Text(detail)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// The intent, shown back. Half the value of writing one down is reading it
    /// again at the end and finding out whether it happened.
    private var intentCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text("You set out to")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
                Text(session.intent)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
            }
        }
    }

    /// "Did you finish it?" — kept small and optional. It is a question, not a
    /// demand, and saying no costs nothing.
    ///
    /// Answering yes credits the session's real duration to the task, which is
    /// what the estimate calibration reads.
    private func taskCard(_ task: FocusTask) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text(task.title)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)

                if task.isCompleted {
                    Label("Marked done", systemImage: "checkmark.circle.fill")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.accent(.focusing))

                    // Arithmetic, not a verdict. Being wrong about how long
                    // something takes is the condition, not a failing.
                    if let delta = EstimateDelta(task: task) {
                        Text(delta.summary)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                    }
                } else {
                    HStack(spacing: KSSpacing.sm) {
                        Text("Finished it?")
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                        Spacer(minLength: 0)
                        Button("Mark done", action: onMarkTaskDone)
                            .ksFont(KSFont.label)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: KSSpacing.sm) {
            if offersExtension {
                KSPrimaryButton(title: "Keep going", systemImage: "arrow.right") {
                    onContinue(extensionMode)
                }
                Text("Rolls straight into \(extensionMode.displayName). Or stop here — that was the deal.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                KSSecondaryButton(title: "Done for now", action: onDone)
            } else {
                KSPrimaryButton(title: "Done", systemImage: "checkmark") {
                    onDone()
                }
            }
        }
    }

    // MARK: Copy

    /// Plain and factual. Nothing here congratulates the user for a session they
    /// abandoned, and nothing scolds them for one either.
    private var title: String {
        switch session.endReason {
        case .reachedPlannedEnd, .finishedWhileAway:
            return "Done."
        case .cappedAfterHeartbeat:
            return "That one was left running."
        case .endedByUser, .none:
            return session.wasCompleted ? "Done." : "Stopped."
        }
    }

    private var detail: String {
        let spent = "\(minutes) minute\(minutes == 1 ? "" : "s")"

        switch session.endReason {
        case .finishedWhileAway:
            return "\(spent). It finished while you were away, so it is counted from when it actually ended."

        case .cappedAfterHeartbeat:
            return "Closed at \(spent), the last point the app knew you were there. It is recorded but not counted."

        case .reachedPlannedEnd:
            return "\(spent) of focus."

        case .endedByUser, .none:
            if session.mode.defaultProfile.countsUp {
                return "\(spent) of focus. Stopping is how this mode finishes."
            }
            if session.wasCompleted {
                return "\(spent) of \(plannedMinutes). Far enough in that it counts."
            }
            return "\(spent) of \(plannedMinutes). Nothing lost — start again whenever you want."
        }
    }
}

#Preview("Complete — Just Start") {
    var session = FocusSession()
    session.mode = .justStart
    session.startedAt = Date().addingTimeInterval(-5 * 60)
    session.endedAt = Date()
    session.plannedDuration = 5 * 60
    session.wasCompleted = true
    session.endReason = .reachedPlannedEnd
    session.intent = "Just open the file"

    return SessionCompleteView(
        session: session,
        award: nil,
        offersExtension: true,
        extensionMode: .classicPomodoro,
        onContinue: { _ in },
        onMarkTaskDone: {},
        onDone: {}
    )
}

#Preview("Complete — stopped early") {
    var session = FocusSession()
    session.mode = .classicPomodoro
    session.startedAt = Date().addingTimeInterval(-6 * 60)
    session.endedAt = Date()
    session.plannedDuration = 25 * 60
    session.wasCompleted = false
    session.endReason = .endedByUser

    return SessionCompleteView(
        session: session,
        award: nil,
        offersExtension: false,
        extensionMode: .classicPomodoro,
        onContinue: { _ in },
        onMarkTaskDone: {},
        onDone: {}
    )
}
