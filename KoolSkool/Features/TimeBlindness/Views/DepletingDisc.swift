import SwiftUI

/// A filled circle that visibly drains.
///
/// This is the primary timer, not decoration around one. Digits require reading
/// and then arithmetic — "17:42, and I started at 3, so…" — which is exactly the
/// step that goes missing. A wedge that is obviously two-thirds gone needs
/// neither.
struct DiscWedge: Shape {
    /// 1 at the start, 0 at the planned end.
    var remaining: Double

    var animatableData: Double {
        get { remaining }
        set { remaining = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clamped = min(max(remaining, 0), 1)

        guard clamped > 0 else { return path }

        guard clamped < 1 else {
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            return path
        }

        // Drains clockwise from twelve o'clock, the direction every clock face
        // has already taught everyone to read.
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct DepletingDisc: View {
    let snapshot: SessionSnapshot
    var showsDigits: Bool = true

    @Environment(\.ksReduceMotion) private var reduceMotion

    private var tint: Color {
        KSColor.blend(from: .focusing, to: .overrun, progress: snapshot.ambientProgress)
    }

    /// Count-up sessions have nothing to drain toward, so the disc fills through
    /// each minute instead — still moving, still readable, implying no deadline.
    private var remaining: Double {
        guard !snapshot.countsUp else {
            return snapshot.elapsed.truncatingRemainder(dividingBy: 60) / 60
        }
        return 1 - snapshot.progress
    }

    var body: some View {
        VStack(spacing: KSSpacing.md) {
            disc
            if showsDigits { digits }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.spokenTime)
        .accessibilityValue(snapshot.mode.displayName)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var disc: some View {
        ZStack {
            Circle()
                .fill(KSColor.track)

            DiscWedge(remaining: remaining)
                .fill(tint)
                .ksAnimation(KSAnimation.continuous, value: remaining)

            // A hairline keeps the shape legible when the wedge is nearly gone.
            Circle()
                .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)

            if snapshot.isOverrun {
                Text("over")
                    .ksFont(KSFont.title)
                    .foregroundStyle(KSColor.onAccent(.overrun))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Secondary and optional. Big, because this app does not do small type, but
    /// clearly beneath the disc rather than beside it.
    private var digits: some View {
        VStack(spacing: KSSpacing.xxs) {
            Text(snapshot.formattedTime)
                .ksFont(KSFont.displaySmall)
                .foregroundStyle(KSColor.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if snapshot.countsUp {
                Text("counting up")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }
}

#Preview("Disc") {
    let start = Date().addingTimeInterval(-9 * 60)
    var session = FocusSession()
    session.mode = .classicPomodoro
    session.startedAt = start
    session.plannedDuration = 25 * 60

    return VStack(spacing: KSSpacing.xl) {
        DepletingDisc(snapshot: SessionSnapshot(session: session, now: Date()))
            .frame(maxWidth: 280)
        DepletingDisc(snapshot: SessionSnapshot(session: session, now: Date()), showsDigits: false)
            .frame(maxWidth: 140)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KSColor.canvas)
}
