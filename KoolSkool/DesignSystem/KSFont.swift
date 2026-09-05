import SwiftUI

/// An aggressive type scale. The timer is enormous on purpose, and nothing in
/// the app is smaller than 15pt.
///
/// Sizes are given as a base plus a Dynamic Type text style to scale against, so
/// the scale stays aggressive *and* respects the user's size setting. Use the
/// `.ksFont(_:)` modifier rather than `Font` directly — the modifier is what
/// applies the scaling.
enum KSFont {
    struct Style {
        var size: CGFloat
        var weight: Font.Weight
        var design: Font.Design
        /// The Dynamic Type style this scales in step with.
        var relativeTo: Font.TextStyle
        var monospacedDigits: Bool = false

        func withSize(_ newSize: CGFloat) -> Style {
            var copy = self
            copy.size = newSize
            return copy
        }
    }

    /// The session timer. Nothing else in the app uses this.
    static let display = Style(size: 76, weight: .black, design: .rounded, relativeTo: .largeTitle, monospacedDigits: true)
    /// Secondary big numbers — XP counts, streak counts during celebration.
    static let displaySmall = Style(size: 52, weight: .heavy, design: .rounded, relativeTo: .largeTitle, monospacedDigits: true)

    static let title = Style(size: 34, weight: .bold, design: .rounded, relativeTo: .title)
    static let headline = Style(size: 22, weight: .semibold, design: .rounded, relativeTo: .title3)
    static let body = Style(size: 17, weight: .regular, design: .default, relativeTo: .body)
    static let bodyEmphasis = Style(size: 17, weight: .semibold, design: .default, relativeTo: .body)
    /// The floor. Nothing goes below this.
    static let caption = Style(size: 15, weight: .medium, design: .default, relativeTo: .subheadline)
    static let label = Style(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline)
}

extension View {
    func ksFont(_ style: KSFont.Style) -> some View {
        modifier(KSScaledFontModifier(style: style))
    }
}

/// Applies a `KSFont.Style` scaled for the current Dynamic Type size.
///
/// `@ScaledMetric` is what does the work: it grows the base size in step with
/// the chosen text style, so a 76pt timer stays proportionally huge rather than
/// staying literally 76pt.
private struct KSScaledFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let style: KSFont.Style

    init(style: KSFont.Style) {
        self.style = style
        _scaledSize = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        let base = Font.system(size: scaledSize, weight: style.weight, design: style.design)
        return content.font(style.monospacedDigits ? base.monospacedDigit() : base)
    }
}
