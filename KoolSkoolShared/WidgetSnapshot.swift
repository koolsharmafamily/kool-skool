import Foundation

/// Everything a widget is allowed to know, written by the app.
///
/// The widget never opens the database. It reads this one small value, which
/// keeps the store single-writer and — more importantly — means the list of what
/// can reach a home screen or Lock Screen is exactly the fields below. Nothing
/// health-adjacent is here, and a test pins the key list so adding a field is a
/// deliberate decision.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = WidgetSnapshot.currentVersion
    var generatedAt: Date
    /// Local midnight of the day the musts belong to.
    var day: Date
    var streak: Int
    var level: Int
    var musts: [Must]
    var session: Session?

    struct Must: Codable, Equatable, Sendable {
        var title: String
        var isDone: Bool
    }

    struct Session: Codable, Equatable, Sendable {
        var startedAt: Date
        /// Nil for a count-up session.
        var plannedEnd: Date?
        var modeName: String
    }

    enum SessionState: Equatable, Sendable {
        case idle
        case running(Session)
        /// The planned end passed while the app was not open to close it.
        case timeUp(Session)
    }

    func sessionState(asOf now: Date) -> SessionState {
        guard let session else { return .idle }
        if let end = session.plannedEnd, now >= end {
            return .timeUp(session)
        }
        return .running(session)
    }

    /// Yesterday's musts are not today's. A snapshot the app has not refreshed
    /// since midnight shows none rather than a stale list.
    func musts(asOf now: Date, calendar: Calendar) -> [Must] {
        calendar.isDate(day, inSameDayAs: now) ? musts : []
    }

    /// Same wording as `UserProgress.streakLabel`. A test holds them together.
    var streakLabel: String {
        streak == 0 ? "Fresh start" : "Day \(streak)"
    }

    /// Everything except `generatedAt`, so republishing an unchanged picture —
    /// which spends widget reload budget — can be skipped.
    func hasSameContent(as other: WidgetSnapshot?) -> Bool {
        guard var other else { return false }
        other.generatedAt = generatedAt
        return other == self
    }
}

/// Where the snapshot lives: the shared App Group, when there is one.
enum WidgetSnapshotStore {
    static let appGroup = "group.com.koolskool.app"
    static let key = "widget.snapshot.v1"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// False until the App Group entitlement is added. Without it both sides
    /// still run; the widget simply never sees what the app wrote, and shows its
    /// launcher instead.
    static var isSharingAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }

    static func write(_ snapshot: WidgetSnapshot, to defaults: UserDefaults?) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func read(from defaults: UserDefaults?) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return nil }
        // A snapshot from a future app version is ignored rather than misread.
        return snapshot.version == WidgetSnapshot.currentVersion ? snapshot : nil
    }
}
