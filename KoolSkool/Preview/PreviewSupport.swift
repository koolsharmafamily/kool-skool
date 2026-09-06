#if DEBUG
import Foundation

extension AppEnvironment {
    /// An environment backed by the unavailable store. Instant to construct, so
    /// previews that only need chrome do not pay for a container.
    static func previewEmpty() -> AppEnvironment {
        AppEnvironment(
            repositories: UnavailableRepositoryProvider(reason: "Preview has no store."),
            clock: PreviewClock.fixed,
            haptics: NoOpHaptics(),
            idleGuard: NoOpScreenIdleGuard()
        )
    }
}

enum PreviewClock {
    /// A fixed instant so previews and snapshot comparisons never drift:
    /// 2026-03-14, 09:41 UTC.
    static var fixed: MutableDateProvider {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 14
        components.hour = 9
        components.minute = 41

        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC") ?? .gmt
        calendar.timeZone = utc

        let date = calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_773_480_060)
        return MutableDateProvider(now: date, calendar: calendar, timeZone: utc)
    }
}
#endif
