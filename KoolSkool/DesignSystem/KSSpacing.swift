import CoreGraphics

/// A four-point scale. Feature code uses these names, never raw numbers.
enum KSSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let huge: CGFloat = 64

    /// Standard horizontal inset for screen content.
    static let screenMargin: CGFloat = 20
}

enum KSRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let pill: CGFloat = 999
}

enum KSStroke {
    static let hairline: CGFloat = 1
    static let medium: CGFloat = 2
    /// The depleting disc.
    static let disc: CGFloat = 18
}

enum KSSize {
    /// Apple's minimum is 44. This app goes bigger — the primary action should
    /// be hard to miss and hard to mis-tap.
    static let minimumTapTarget: CGFloat = 44
    static let primaryButtonHeight: CGFloat = 64
    static let secondaryButtonHeight: CGFloat = 52
}
