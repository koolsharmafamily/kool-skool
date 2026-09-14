import SwiftUI

/// The focus screen. One job, one escape hatch, nothing else rendered.
///
/// Other tasks are not merely de-emphasised here — they are not on screen at
/// all, which is the point of the mode.
///
/// Two things are doing the time-blindness work: the disc, which drains without
/// needing to be read, and the background, which warms continuously toward the
/// overrun accent. Neither asks for attention; both are there when it wanders.
struct ActiveSessionView: View {
    let snapshot: SessionSnapshot
    var taskTitle: String?
    /// The morning intention, shown back during the session — but only when the
    /// session has no intent of its own. Three lines of text above the disc is
    /// three lines of text nobody reads.
    var intention: String?
    var showsDigits: Bool = true
    var showsCompanion: Bool = true
    var bodyDoubling: BodyDoublingController?
    let onEndEarly: () -> Void

    @State private var isConfirmingEnd = false

    var body: some View {
        ZStack {
            AmbientBackground(progress: snapshot.ambientProgress)

            VStack(spacing: KSSpacing.lg) {
                header
                Spacer(minLength: KSSpacing.sm)

                DepletingDisc(snapshot: snapshot, showsDigits: showsDigits)
                    .frame(maxWidth: 320)
                    // Sized before the spacers, so the disc is as big as the
                    // screen allows and shrinks only when text needs the room —
                    // never the other way round.
                    .layoutPriority(1)

                Spacer(minLength: KSSpacing.sm)
                footer
            }
            .padding(.horizontal, KSSpacing.screenMargin)
            .padding(.vertical, KSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ksEnergyState(snapshot.energyState)
        .tint(KSColor.accent(snapshot.energyState))
        .confirmationDialog(
            "End this session?",
            isPresented: $isConfirmingEnd,
            titleVisibility: .visible
        ) {
            Button("End now", role: .destructive, action: onEndEarly)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(endMessage)
        }
    }

    // MARK: Pieces

    /// Task and intent stay pinned at the top for the whole session — the two
    /// things worth re-reading when attention drifts.
    private var header: some View {
        VStack(spacing: KSSpacing.xs) {
            KSTag(text: snapshot.mode.displayName, systemImage: "timer", state: snapshot.energyState)

            if let taskTitle, !taskTitle.isEmpty {
                Text(taskTitle)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Primary text, not a quieter grey: by the end of a session the
            // ambient wash at the top of the screen is warm enough that the
            // quieter greys drop below 4.5:1. Size keeps the hierarchy instead.
            if !snapshot.session.intent.isEmpty {
                Text(snapshot.session.intent)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let intention, !intention.isEmpty {
                Text(intention)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: KSSpacing.sm) {
            company

            KSSecondaryButton(title: "End early", systemImage: "stop.fill") {
                isConfirmingEnd = true
            }

            Text(reassurance)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The company. Ambient by design — a companion that moves constantly is a
    /// pet demanding attention, which is the opposite of what this is for.
    @ViewBuilder
    private var company: some View {
        if let bodyDoubling {
            VStack(spacing: KSSpacing.xs) {
                if showsCompanion, let coworker = bodyDoubling.coworkers.first {
                    CompanionView(coworker: coworker, milestoneCount: bodyDoubling.milestoneCount)
                }

                SoundscapeControl(controller: bodyDoubling)
            }
        }
    }

    /// Honest about what ending now means, without making it a punishment.
    private var endMessage: String {
        if snapshot.countsUp {
            return "Stopping is how a Flowmodoro session finishes. It counts."
        }

        if snapshot.progress >= FocusRules.completionThreshold {
            return "You are far enough in that this still counts as done."
        }
        return "Nothing is lost and your streak is fine. The session just gets recorded as it happened."
    }

    private var reassurance: String {
        snapshot.countsUp
            ? "Stop whenever the flow stops."
            : "Ending early costs you nothing."
    }
}

#Preview("Active — mid session") {
    var session = FocusSession()
    session.mode = .classicPomodoro
    session.startedAt = Date().addingTimeInterval(-8 * 60)
    session.plannedDuration = 25 * 60
    session.intent = "One clean pass over chapter two"

    return ActiveSessionView(
        snapshot: SessionSnapshot(session: session, now: Date()),
        taskTitle: "Read chapter two",
        onEndEarly: {}
    )
}

#Preview("Active — nearly over, no digits") {
    var session = FocusSession()
    session.mode = .justStart
    session.startedAt = Date().addingTimeInterval(-4.5 * 60)
    session.plannedDuration = 5 * 60
    session.intent = "Just open the file"

    return ActiveSessionView(
        snapshot: SessionSnapshot(session: session, now: Date()),
        taskTitle: nil,
        showsDigits: false,
        onEndEarly: {}
    )
}
