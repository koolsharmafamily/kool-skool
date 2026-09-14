import SwiftUI

/// The expanding and contracting form that paces a breath practice.
///
/// The whole point is that it replaces counting. Following a shape that grows
/// while you breathe in costs nothing; holding "four… three… two…" in working
/// memory is exactly the thing that is hard, and exactly the thing that makes
/// people give up on breath practices.
///
/// ## How the motion is driven
///
/// Not frame by frame from `tick.fullness`. When the phase changes, the view
/// animates to `tick.targetFullness` over the step's own duration. So the shape
/// moves smoothly however coarsely the model ticks, and a step that starts late
/// still ends on time.
///
/// ## Under Reduce Motion
///
/// The shape does not move at all. The instruction word and the count carry the
/// pacing instead, alongside a bar that fills through the phase. Someone who has
/// asked the system for less motion should not be handed a pulsing circle.
struct BreathPacer: View {
    let tick: BreathTick
    var shape: BreathShapeStyle = .circle

    @Environment(\.ksReduceMotion) private var reduceMotion

    @State private var fullness: Double = 0

    /// The largest the form is drawn. It shrinks to fit when a small screen or
    /// a large text size leaves less room, rather than pushing text off screen.
    private let maximumDiameter: CGFloat = 260
    /// The form never collapses to nothing. An empty chest is still a chest.
    private let minimumScale: Double = 0.34

    private var scale: Double {
        minimumScale + (1 - minimumScale) * fullness
    }

    var body: some View {
        ZStack {
            form
                .stroke(KSColor.accentWash(.stillness, opacity: 0.35), lineWidth: KSStroke.medium)

            if !reduceMotion {
                form
                    .fill(KSColor.accentWash(.stillness, opacity: 0.30))
                    .scaleEffect(scale)

                form
                    .stroke(KSColor.accent(.stillness), lineWidth: KSStroke.medium)
                    .scaleEffect(scale)
            }

            instruction
        }
        .frame(maxWidth: maximumDiameter, maxHeight: maximumDiameter)
        .aspectRatio(1, contentMode: .fit)
        .onAppear { fullness = tick.fullness }
        .onChange(of: tick.stepKey) { _, _ in advance() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tick.phase.instruction)
        .accessibilityValue(accessibilityCount)
    }

    // MARK: Pieces

    /// One shape type for both forms — a rounded rectangle with a corner radius
    /// of half its side is a circle, which saves erasing two shape types to a
    /// common one for no gain.
    private var form: RoundedRectangle {
        switch shape {
        // A radius of at least half the side is a circle at any size the form
        // shrinks to; SwiftUI clamps it.
        case .circle: RoundedRectangle(cornerRadius: maximumDiameter / 2, style: .circular)
        case .roundedSquare: RoundedRectangle(cornerRadius: 56, style: .continuous)
        }
    }

    private var instruction: some View {
        VStack(spacing: KSSpacing.xs) {
            Text(tick.phase.instruction)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .multilineTextAlignment(.center)

            Text("\(tick.countInStep)")
                .ksFont(KSFont.displaySmall)
                .foregroundStyle(KSColor.accent(.stillness))
                // Rolling digits are motion too; under Reduce Motion they just change.
                .contentTransition(reduceMotion ? .identity : .numericText())

            if reduceMotion {
                phaseBar
            }
        }
        .accessibilityHidden(true)
    }

    /// The stand-in for the moving shape. Fills across the phase, so there is
    /// still something showing how much of it is left.
    private var phaseBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(KSColor.track)
                Capsule()
                    .fill(KSColor.accent(.stillness))
                    .frame(width: geometry.size.width * tick.progressInStep)
            }
        }
        .frame(width: 120, height: 6)
    }

    private var accessibilityCount: String {
        let total = max(1, Int(tick.stepDuration.rounded()))
        return "\(tick.countInStep) of \(total)"
    }

    // MARK: Motion

    private func advance() {
        guard !reduceMotion else {
            fullness = tick.fullness
            return
        }

        // Linear, and exactly as long as the step: the shape has to arrive at
        // the same moment the breath does, or it stops being a pacer.
        withAnimation(.linear(duration: tick.stepDuration)) {
            fullness = tick.targetFullness
        }
    }
}

/// Which form the pacer draws.
///
/// Box breathing gets a rounded square because the shape names the practice,
/// which is one less thing to explain.
enum BreathShapeStyle: Sendable, Equatable {
    case circle
    case roundedSquare

    static func forPractice(_ type: PracticeType) -> BreathShapeStyle {
        type == .boxBreathing ? .roundedSquare : .circle
    }
}

#Preview("Breathing in") {
    KSScreen(state: .stillness) {
        BreathPacer(
            tick: BreathPattern.box.tick(atElapsed: 2),
            shape: .roundedSquare
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
