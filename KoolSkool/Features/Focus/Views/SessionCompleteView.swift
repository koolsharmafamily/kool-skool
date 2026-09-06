import SwiftUI

/// The post-session screen.
///
/// Milestone 2 scope: say honestly what happened, and offer to keep going. The
/// energy check-in lands in Milestone 7, and XP, coins and the celebration
/// moment in Milestone 4 — the space they will occupy is left deliberately empty
/// rather than filled with a placeholder.
struct SessionCompleteView: View {
    let session: FocusSession
    let offersExtension: Bool
    let extensionMode: SessionMode
    let onContinue: (SessionMode) -> Void
    let onDone: () -> Void

    private var minutes: Int { session.actualMinutes }
    private var plannedMinutes: Int { Int(session.plannedDuration / 60) }

    var body: some View {
        KSScreen(state: session.wasCompleted ? .focusing : .ready) {
            VStack(alignment: .leading, spacing: KSSpacing.lg) {
                Spacer(minLength: KSSpacing.xl)

                headline
                if !session.intent.isEmpty { intentCard }

                Spacer(minLength: KSSpacing.md)
                actions
            }
            .padding(.vertical, KSSpacing.lg)
        }
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
        offersExtension: true,
        extensionMode: .classicPomodoro,
        onContinue: { _ in },
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
        offersExtension: false,
        extensionMode: .classicPomodoro,
        onContinue: { _ in },
        onDone: {}
    )
}
