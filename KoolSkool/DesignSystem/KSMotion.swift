import SwiftUI

private struct KSReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

private struct KSEnergyStateKey: EnvironmentKey {
    static let defaultValue = KSEnergyState.ready
}

extension EnvironmentValues {
    /// The in-app Reduce Motion switch, fed from `AppSettings`.
    ///
    /// This can only *add* reduction. The system setting is always honoured;
    /// nothing in the app can switch motion back on for someone who asked the OS
    /// to take it away.
    var ksReduceMotionOverride: Bool {
        get { self[KSReduceMotionOverrideKey.self] }
        set { self[KSReduceMotionOverrideKey.self] = newValue }
    }

    /// The single answer every animation should consult.
    var ksReduceMotion: Bool {
        accessibilityReduceMotion || ksReduceMotionOverride
    }

    /// Which energy state the current screen is in. Components read this so
    /// they colour themselves without being told.
    var ksEnergyState: KSEnergyState {
        get { self[KSEnergyStateKey.self] }
        set { self[KSEnergyStateKey.self] = newValue }
    }
}

extension View {
    func ksEnergyState(_ state: KSEnergyState) -> some View {
        environment(\.ksEnergyState, state)
    }

    func ksReduceMotionOverride(_ enabled: Bool) -> some View {
        environment(\.ksReduceMotionOverride, enabled)
    }
}
