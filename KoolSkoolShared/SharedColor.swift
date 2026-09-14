import SwiftUI
import UIKit

// Compiled into both the app and the widget extension. Nothing in this folder
// may reference a type that lives only in the app target.

extension UIColor {
    /// `0xRRGGBB`.
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension KSEnergyState {
    /// The accent as a light/dark-aware colour, for the widget extension, which
    /// cannot see `KSColor`.
    var sharedAccent: Color {
        let state = self
        return Color(uiColor: UIColor { traits in
            UIColor(hex: state.accentHex(dark: traits.userInterfaceStyle == .dark))
        })
    }
}
