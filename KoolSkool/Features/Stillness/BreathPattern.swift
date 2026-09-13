import Foundation

/// One phase of a breath cycle.
///
/// `topUp` is the second, shorter inhale of the physiological sigh. It is its
/// own phase rather than a longer inhale because the whole point of the sigh is
/// the two-part intake, and the pacer has to show the catch between them.
enum BreathPhase: String, Sendable, Equatable, CaseIterable {
    case inhale
    case topUp
    case holdFull
    case exhale
    case holdEmpty

    /// The one word on screen. Imperative, because it is an instruction being
    /// followed in real time, not a label being read.
    var instruction: String {
        switch self {
        case .inhale: "Breathe in"
        case .topUp: "A little more"
        case .holdFull: "Hold"
        case .exhale: "Breathe out"
        case .holdEmpty: "Hold"
        }
    }

    /// Which haptic marks the *start* of this phase. The two holds get the
    /// softest pulse in the vocabulary: enough to mark the boundary with the
    /// screen face-down, not enough to feel like an alert.
    var haptic: KSHaptic {
        switch self {
        case .inhale, .topUp: .breathIn
        case .exhale: .breathOut
        case .holdFull, .holdEmpty: .timeCheck
        }
    }
}

/// One step of a pattern: how long it lasts and how full the lungs are at the
/// end of it.
struct BreathStep: Sendable, Equatable {
    var phase: BreathPhase
    var duration: TimeInterval
    /// Fullness, 0...1, at the *end* of this step. The start is wherever the
    /// previous step left off, so a pattern cannot describe a discontinuity.
    var endFullness: Double
}

/// What the pacer is showing at one instant.
struct BreathTick: Sendable, Equatable {
    var phase: BreathPhase
    var stepIndex: Int
    var cycleIndex: Int
    /// 0...1 through the current step.
    var progressInStep: Double
    /// 0...1 lung fullness right now. The scale of the shape on screen.
    var fullness: Double
    /// Where the shape is heading, and how long it has to get there. The view
    /// animates to this rather than following `fullness` frame by frame, so the
    /// motion stays smooth however coarsely the model ticks.
    var targetFullness: Double
    var stepDuration: TimeInterval
    /// Counts down within the step, 1-based, the way a person counts along.
    var countInStep: Int

    /// Unique per step occurrence, so a view can notice "the phase changed"
    /// without tracking two fields.
    var stepKey: Int { cycleIndex * 100 + stepIndex }
}

/// The timing of a paced breath practice.
///
/// Pure value type with no clock of its own: everything is derived from elapsed
/// seconds, so the pacer cannot drift and every phase boundary is testable
/// without waiting for one.
struct BreathPattern: Sendable, Equatable {
    var steps: [BreathStep]

    var cycleDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.duration }
    }

    /// Fullness at the start of a cycle — where the last step of the previous
    /// cycle left it.
    var startFullness: Double { steps.last?.endFullness ?? 0 }

    // MARK: The two patterns that ship

    /// 4-4-4-4. The one everybody has heard of, and the one that works when
    /// counting is exactly as much as a scattered brain can hold.
    static let box = BreathPattern(steps: [
        BreathStep(phase: .inhale, duration: 4, endFullness: 1),
        BreathStep(phase: .holdFull, duration: 4, endFullness: 1),
        BreathStep(phase: .exhale, duration: 4, endFullness: 0),
        BreathStep(phase: .holdEmpty, duration: 4, endFullness: 0),
    ])

    /// Two inhales through the nose, then a long exhale through the mouth.
    ///
    /// The second inhale is short and lands on top of the first. The exhale is
    /// deliberately about twice the length of both together — the long out-breath
    /// is the part that does the work.
    static let physiologicalSigh = BreathPattern(steps: [
        BreathStep(phase: .inhale, duration: 2.0, endFullness: 0.75),
        BreathStep(phase: .topUp, duration: 1.0, endFullness: 1.0),
        BreathStep(phase: .exhale, duration: 5.0, endFullness: 0),
        BreathStep(phase: .holdEmpty, duration: 1.0, endFullness: 0),
    ])

    /// The pattern a practice paces to, or nil if it is not a breath practice.
    static func forPractice(_ type: PracticeType) -> BreathPattern? {
        switch type {
        case .boxBreathing: box
        case .physiologicalSigh: physiologicalSigh
        case .bodyScan, .walking, .soundAnchor, .movement, .openAwareness: nil
        }
    }

    // MARK: Derivation

    /// Where the pacer is at `elapsed` seconds in.
    ///
    /// Derived from the total elapsed time on every call rather than advanced
    /// step by step. A tick that never fires, or twenty of them missed while the
    /// app was backgrounded, changes nothing about the answer.
    func tick(atElapsed elapsed: TimeInterval) -> BreathTick {
        guard cycleDuration > 0, let first = steps.first else {
            return BreathTick(
                phase: .inhale,
                stepIndex: 0,
                cycleIndex: 0,
                progressInStep: 0,
                fullness: 0,
                targetFullness: 0,
                stepDuration: 0,
                countInStep: 1
            )
        }

        let clamped = max(0, elapsed)
        let cycleIndex = Int(clamped / cycleDuration)
        var offset = clamped.truncatingRemainder(dividingBy: cycleDuration)

        var index = 0
        var step = first
        var previousFullness = startFullness

        for (position, candidate) in steps.enumerated() {
            if offset < candidate.duration || position == steps.count - 1 {
                index = position
                step = candidate
                break
            }
            offset -= candidate.duration
            previousFullness = candidate.endFullness
        }

        let progress = step.duration > 0 ? min(max(offset / step.duration, 0), 1) : 1
        let fullness = previousFullness + (step.endFullness - previousFullness) * progress

        // Counting up the way a person does: the first second of a four-second
        // inhale is "one", not "zero".
        let count = min(Int(offset) + 1, max(1, Int(step.duration.rounded(.up))))

        return BreathTick(
            phase: step.phase,
            stepIndex: index,
            cycleIndex: cycleIndex,
            progressInStep: progress,
            fullness: fullness,
            targetFullness: step.endFullness,
            stepDuration: step.duration,
            countInStep: count
        )
    }
}
