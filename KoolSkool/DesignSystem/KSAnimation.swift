import SwiftUI
import UIKit

/// Motion is for progress, celebration, and state transitions. Never for
/// decoration, and never on an idle screen.
enum KSAnimation {
    /// State changes, button presses, sheet content.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.74)
    /// Rewards and celebration. The only place overshoot is welcome.
    static let bouncy = Animation.spring(response: 0.46, dampingFraction: 0.62)
    /// Larger layout moves.
    static let gentle = Animation.spring(response: 0.60, dampingFraction: 0.90)
    /// The stillness layer. Slow, even, no bounce.
    static let calm = Animation.easeInOut(duration: 1.2)
    /// The depleting disc and ambient colour shift. Linear, because it is
    /// representing real elapsed time and should not ease.
    static let continuous = Animation.linear(duration: 1.0)

    /// What every animation degrades to under Reduce Motion: a crossfade short
    /// enough to read as instant, long enough not to flicker.
    static let crossfade = Animation.easeInOut(duration: 0.15)

    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? crossfade : animation
    }
}

extension View {
    /// Animates `value` changes with a Reduce Motion aware version of `animation`.
    ///
    /// Prefer this over `.animation(_:value:)` everywhere — it is the single
    /// place the accessibility swap happens.
    func ksAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(KSAnimationModifier(animation: animation, value: value))
    }

    /// Applies a transition that collapses to a crossfade under Reduce Motion.
    func ksTransition(_ transition: AnyTransition) -> some View {
        modifier(KSTransitionModifier(transition: transition))
    }
}

private struct KSAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.ksReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(KSAnimation.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

private struct KSTransitionModifier: ViewModifier {
    @Environment(\.ksReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

/// Imperative counterpart to `.ksAnimation(_:value:)`, for callbacks that are
/// not driven by a value change.
@MainActor
func withKSAnimation<Result>(
    _ animation: Animation,
    overrideReduceMotion: Bool = false,
    _ body: () throws -> Result
) rethrows -> Result {
    let reduce = UIAccessibility.isReduceMotionEnabled || overrideReduceMotion
    return try withAnimation(KSAnimation.resolved(animation, reduceMotion: reduce), body)
}
