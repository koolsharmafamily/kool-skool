import UIKit

/// The haptic vocabulary. Named for what happened, not for how it feels, so
/// the physical mapping can be tuned in one place.
enum KSHaptic: Sendable, CaseIterable {
    /// A button was pressed.
    case tap
    /// Something was selected from a set.
    case selection
    /// A session started.
    case start
    /// A session ended cleanly.
    case complete
    /// The optional time-check pulse. Deliberately the softest thing here.
    case timeCheck
    /// The planned end passed and the session is running over.
    case overrun
    /// A reward landed.
    case reward
    /// Something did not work.
    case failure
    /// Breath pacer, inhale phase.
    case breathIn
    /// Breath pacer, exhale phase.
    case breathOut
}

@MainActor
protocol HapticPerforming: AnyObject {
    var isEnabled: Bool { get set }
    /// Warms the generators before a burst — call it when a screen appears, not
    /// on every fire.
    func prepare()
    func fire(_ haptic: KSHaptic)
    /// The session-complete sequence. About a second, and interruptible.
    func celebrate() async
}

@MainActor
final class KSHaptics: HapticPerforming {
    static let shared = KSHaptics()

    /// Driven from `AppSettings.hapticsEnabled`.
    var isEnabled: Bool = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init() {}

    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        notification.prepare()
    }

    func fire(_ haptic: KSHaptic) {
        guard isEnabled else { return }

        switch haptic {
        case .tap:
            light.impactOccurred()
        case .selection:
            selectionGenerator.selectionChanged()
        case .start:
            medium.impactOccurred(intensity: 0.9)
        case .complete:
            notification.notificationOccurred(.success)
        case .timeCheck:
            soft.impactOccurred(intensity: 0.45)
        case .overrun:
            rigid.impactOccurred(intensity: 0.7)
        case .reward:
            heavy.impactOccurred(intensity: 0.8)
        case .failure:
            notification.notificationOccurred(.warning)
        case .breathIn:
            soft.impactOccurred(intensity: 0.5)
        case .breathOut:
            soft.impactOccurred(intensity: 0.3)
        }
    }

    /// Three rising beats then a success notification. Roughly a second, which
    /// is inside the 1.5s budget the celebration moment gets.
    ///
    /// Cancellation-aware, so tapping to skip the celebration stops the haptics
    /// with it.
    func celebrate() async {
        guard isEnabled else { return }

        let beats: [(generator: UIImpactFeedbackGenerator, intensity: CGFloat)] = [
            (light, 0.6), (medium, 0.8), (heavy, 1.0),
        ]

        for beat in beats {
            beat.generator.impactOccurred(intensity: beat.intensity)
            do {
                try await Task.sleep(for: .milliseconds(110))
            } catch {
                return
            }
        }

        notification.notificationOccurred(.success)
    }
}

/// Silences haptics in previews and tests.
@MainActor
final class NoOpHaptics: HapticPerforming {
    var isEnabled: Bool = false
    private(set) var fired: [KSHaptic] = []

    init() {}

    func prepare() {}

    func fire(_ haptic: KSHaptic) {
        fired.append(haptic)
    }

    func celebrate() async {
        fired.append(.reward)
    }
}
