import Foundation

/// Everything the session UI needs, derived from a session and an instant.
///
/// Holds no state of its own and does no arithmetic on stored counters — give it
/// a session and a `now` and it tells you where things stand. That is what makes
/// the whole display trivially testable and immune to drift.
struct SessionSnapshot: Equatable, Sendable {
    let session: FocusSession
    let now: Date

    init(session: FocusSession, now: Date) {
        self.session = session
        self.now = now
    }

    var mode: SessionMode { session.mode }

    /// Flowmodoro counts up and has no planned end.
    var countsUp: Bool { session.mode.defaultProfile.countsUp || session.plannedDuration <= 0 }

    var elapsed: TimeInterval { session.elapsed(asOf: now) }

    /// Nil for count-up sessions. Goes negative on an overrun.
    var remaining: TimeInterval? {
        countsUp ? nil : session.remaining(asOf: now)
    }

    /// 0...1 for the depleting disc. Count-up sessions have nothing to deplete
    /// toward, so they report zero and the ring fills rather than drains.
    var progress: Double { session.progress(asOf: now) }

    var hasReachedPlannedEnd: Bool { session.hasReachedPlannedEnd(asOf: now) }

    /// True only when the planned end has passed and the session is somehow
    /// still running — which in practice means it was restored from a period
    /// when the app was not watching.
    var isOverrun: Bool { hasReachedPlannedEnd && session.isRunning }

    /// The interval the big digits show: time left when counting down, time
    /// spent when counting up. Never negative.
    var displayInterval: TimeInterval {
        guard let remaining else { return elapsed }
        return max(0, remaining)
    }

    var energyState: KSEnergyState {
        isOverrun ? .overrun : .focusing
    }

    /// How far to migrate the background from `focusing` toward `overrun`.
    ///
    /// Count-up sessions never migrate — there is no deadline to approach, and
    /// implying one would defeat the point of the mode.
    var ambientProgress: Double {
        countsUp ? 0 : progress
    }

    // MARK: Formatting

    /// `25:00`, or `1:05:00` once past an hour.
    var formattedTime: String {
        Self.format(displayInterval)
    }

    /// What VoiceOver reads. Spelled out, because "25:00" is announced as a
    /// time of day otherwise.
    var spokenTime: String {
        let phrase = Self.spoken(displayInterval)
        if countsUp {
            return "\(phrase) elapsed"
        }
        return displayInterval > 0 ? "\(phrase) remaining" : "Time is up"
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func spoken(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        // Only mention seconds when they are the whole story, otherwise the
        // announcement changes every second and becomes unusable.
        if hours == 0 && minutes == 0 { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }

        return parts.isEmpty ? "no time" : parts.joined(separator: " ")
    }
}
