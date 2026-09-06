import SwiftUI

/// The session timer.
///
/// Milestone 2 scope: a correct, readable ring that drains. The full time
/// blindness treatment — a filled disc rather than a ring, the ambient
/// background migration, the optional pulse, and making the digits secondary and
/// toggleable — arrives in Milestone 5. The colour interpolation is already
/// wired here because it costs nothing and it is the single clearest signal that
/// time is running out.
struct SessionTimerRing: View {
    let snapshot: SessionSnapshot

    @Environment(\.ksReduceMotion) private var reduceMotion

    private var strokeColor: Color {
        KSColor.blend(from: .focusing, to: .overrun, progress: snapshot.ambientProgress)
    }

    /// The ring drains: full at the start, empty at the planned end.
    /// Count-up sessions have no end to drain toward, so the ring stays whole.
    private var trimEnd: CGFloat {
        snapshot.countsUp ? 1 : CGFloat(1 - snapshot.progress)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(KSColor.track, style: StrokeStyle(lineWidth: KSStroke.disc, lineCap: .round))

            Circle()
                .trim(from: 0, to: trimEnd)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: KSStroke.disc, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .ksAnimation(KSAnimation.continuous, value: trimEnd)

            digits
        }
        .padding(KSStroke.disc / 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.spokenTime)
        .accessibilityValue(snapshot.mode.displayName)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var digits: some View {
        VStack(spacing: KSSpacing.xxs) {
            Text(snapshot.formattedTime)
                .ksFont(KSFont.display)
                .foregroundStyle(KSColor.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if snapshot.isOverrun {
                Text("over")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.accent(.overrun))
            } else if snapshot.countsUp {
                Text("counting up")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
        .padding(.horizontal, KSSpacing.lg)
    }
}

#Preview("Ring") {
    let start = Date().addingTimeInterval(-900)
    var session = FocusSession()
    session.mode = .classicPomodoro
    session.startedAt = start
    session.plannedDuration = 25 * 60

    return VStack(spacing: KSSpacing.xl) {
        SessionTimerRing(snapshot: SessionSnapshot(session: session, now: Date()))
            .frame(width: 280, height: 280)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KSColor.canvas)
}
