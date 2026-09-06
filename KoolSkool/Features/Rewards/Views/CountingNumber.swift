import SwiftUI

/// A number that counts up.
///
/// `Animatable` is what does the work: SwiftUI interpolates `value` across the
/// animation and re-renders at each step, so the digits roll rather than snap.
struct CountingNumber: View, Animatable {
    var value: Double
    var prefix: String = ""
    var suffix: String = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(prefix)\(Int(value.rounded()))\(suffix)")
            .monospacedDigit()
    }
}

/// Wraps `CountingNumber` with the roll-up already arranged, including the
/// Reduce Motion path where the final figure simply appears.
struct RollingNumber: View {
    let target: Int
    var prefix: String = ""
    var suffix: String = ""

    @Environment(\.ksReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        CountingNumber(value: shown, prefix: prefix, suffix: suffix)
            // Under Reduce Motion the final figure simply appears. A rolling
            // number is motion with no information in it.
            .animation(reduceMotion ? nil : .easeOut(duration: RewardRules.countUpDuration), value: shown)
            .onAppear { shown = Double(target) }
            .onChange(of: target) { _, newValue in shown = Double(newValue) }
            .accessibilityLabel("\(prefix)\(target)\(suffix)")
    }

    init(target: Int, prefix: String = "", suffix: String = "") {
        self.target = target
        self.prefix = prefix
        self.suffix = suffix
    }
}
