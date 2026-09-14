import SwiftUI

/// The screen a practice runs on.
///
/// This is where the design system deliberately steps down. Deep indigo, slow
/// curves, nothing that snaps, no reward chrome, and a timer that is present
/// without demanding to be read. Coming here from the focus screen should feel
/// like the volume dropped.
struct SitView: View {
    let run: StillnessRun
    let now: Date
    var breathTick: BreathTick?
    var cue: String?
    let tradition: Tradition
    let onEnd: () -> Void

    private var remaining: TimeInterval { run.remaining(asOf: now) }
    private var progress: Double { run.progress(asOf: now) }

    var body: some View {
        KSScreen(state: .stillness) {
            VStack(spacing: KSSpacing.lg) {
                header

                Spacer(minLength: KSSpacing.sm)
                centrepiece
                Spacer(minLength: KSSpacing.sm)

                footer
            }
            .padding(.vertical, KSSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: KSSpacing.xxs) {
            Text(run.title)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if run.isBreak {
                Text("Break")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var centrepiece: some View {
        if let breathTick, let practice = run.practice {
            VStack(spacing: KSSpacing.lg) {
                BreathPacer(tick: breathTick, shape: .forPractice(practice.type))
                StillnessTimerRing(progress: progress, remaining: remaining, isCompact: true)
            }
            // Sized before the spacers, so the pacer is as large as the screen
            // allows; it shrinks only when the text around it needs the room.
            .layoutPriority(1)
        } else {
            VStack(spacing: KSSpacing.xl) {
                StillnessTimerRing(progress: progress, remaining: remaining, isCompact: false)
                cueText
            }
        }
    }

    @ViewBuilder
    private var cueText: some View {
        if let cue {
            Text(cue)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
                .id(cue)
                .ksTransition(.opacity)
                .ksAnimation(KSAnimation.calm, value: cue)
                .accessibilityLabel(cue)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    private var footer: some View {
        VStack(spacing: KSSpacing.sm) {
            // No confirmation dialog, unlike the focus screen. Abandoning work
            // is worth a second thought; leaving a two-minute breath practice
            // is not, and a "are you sure?" here would be its own small nag.
            KSSecondaryButton(title: "End", systemImage: "stop.fill", action: onEnd)

            Text(StillnessCopy.wandering(tradition))
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A quiet ring and the time left.
///
/// Deliberately not the focus screen's `DepletingDisc`: that one is loud on
/// purpose, because noticing time passing is its whole job. Here the opposite
/// is wanted — the time should be available to anyone who looks for it and
/// invisible to anyone who does not.
struct StillnessTimerRing: View {
    let progress: Double
    let remaining: TimeInterval
    var isCompact: Bool = false

    @Environment(\.ksReduceMotion) private var reduceMotion

    private var diameter: CGFloat { isCompact ? 84 : 200 }
    private var lineWidth: CGFloat { isCompact ? 4 : 6 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(KSColor.track, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.001, 1 - min(max(progress, 0), 1)))
                .stroke(
                    KSColor.accent(.stillness),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .ksAnimation(KSAnimation.continuous, value: progress)

            if !isCompact {
                Text(Self.label(for: remaining))
                    .ksFont(KSFont.title)
                    .foregroundStyle(KSColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time left")
        .accessibilityValue(Self.spokenLabel(for: remaining))
        .opacity(reduceMotion ? 1 : 0.92)
    }

    static func label(for remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining).rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func spokenLabel(for remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining).rounded(.up))
        let minutes = total / 60
        let seconds = total % 60

        if minutes == 0 { return "\(seconds) second\(seconds == 1 ? "" : "s")" }
        if seconds == 0 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
    }
}

#Preview("Paced") {
    SitView(
        run: StillnessRun(
            practice: PracticeCatalogue.boxBreathing,
            plannedDuration: 180,
            startedAt: Date(timeIntervalSince1970: 0)
        ),
        now: Date(timeIntervalSince1970: 42),
        breathTick: BreathPattern.box.tick(atElapsed: 2),
        tradition: .secular,
        onEnd: {}
    )
}

#Preview("Cued") {
    SitView(
        run: StillnessRun(
            practice: PracticeCatalogue.bodyScan,
            plannedDuration: 180,
            startedAt: Date(timeIntervalSince1970: 0)
        ),
        now: Date(timeIntervalSince1970: 42),
        cue: PracticeCatalogue.bodyScan.script.cues.first,
        tradition: .zen,
        onEnd: {}
    )
}
