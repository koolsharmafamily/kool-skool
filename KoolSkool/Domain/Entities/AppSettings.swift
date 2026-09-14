import Foundation

/// The single settings row.
///
/// Named `AppSettings` rather than `Settings` to avoid colliding with SwiftUI's
/// `Settings` scene type.
struct AppSettings: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    // MARK: Focus

    var defaultMode: SessionMode = .justStart
    var customWorkMinutes: Int = 30
    var customBreakMinutes: Int = 6
    var keepScreenAwakeDuringSession: Bool = true
    /// The local-notification backstop for a session that ends while the app is
    /// not on screen. Only ever fires if notifications are already allowed.
    var sessionEndAlertsEnabled: Bool = true

    // MARK: Time blindness

    /// Off by default. A pulse every N minutes is a helpful nudge for some
    /// people and an interruption for others.
    var timeChecksEnabled: Bool = false
    var timeCheckIntervalMinutes: Int = 10
    /// The depleting disc is primary; digits are secondary and toggleable.
    var showDigitalTimer: Bool = true
    /// Whether to auto-pad estimates using the learned calibration factor.
    var autoPadEstimates: Bool = false

    // MARK: Feedback

    var hapticsEnabled: Bool = true
    var soundsEnabled: Bool = true
    var soundscapeKey: String?

    // MARK: Company

    /// Replaces the intent field on the setup screen with a spoken-aloud pledge.
    /// Off by default — it is a nudge that works well for some people and reads
    /// as pressure to others.
    var commitmentCardEnabled: Bool = false
    /// Whether the companion appears on the session screen.
    var companionEnabled: Bool = true

    // MARK: Check-ins and medication

    /// Energy and mood before a session. Off by default: the setup screen is
    /// where people bounce, and the spec is explicit about not adding steps to it.
    var preSessionCheckIn: Bool = false
    /// One tap after a session. On by default — the completion screen is already
    /// a pause, a single tap is cheap, and it is what the energy curve is built on.
    var postSessionCheckIn: Bool = true
    /// Nothing about medication appears anywhere in the app until this is on.
    var medicationTrackingEnabled: Bool = false
    var medicationReminderEnabled: Bool = false
    /// Minutes after local midnight. 480 is 8:00.
    var medicationReminderMinutes: Int = 480

    // MARK: Accessibility

    /// Forces reduced motion even when the system setting is off. The system
    /// setting is always honoured; this can only add reduction, never remove it.
    var reduceMotionOverride: Bool = false

    // MARK: Stillness

    var tradition: Tradition = .secular
    /// Offer a practice automatically when a break starts.
    var offerBreakPractice: Bool = true
    var intervalBellsEnabled: Bool = false

    // MARK: Lifecycle

    /// The answer to onboarding's "when do you work best?". Nil means skipped.
    /// Insights holds it up against what the sessions show, once it can.
    var preferredWorkTime: TimeOfDay?
    var hasCompletedOnboarding: Bool = false

    func resolvedProfile(for mode: SessionMode) -> SessionModeProfile {
        mode.profile(customWorkMinutes: customWorkMinutes, customBreakMinutes: customBreakMinutes)
    }
}
