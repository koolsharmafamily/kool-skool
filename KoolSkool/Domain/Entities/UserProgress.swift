import Foundation

/// The single row tracking XP, coins, and both streaks.
///
/// There is exactly one of these. `ProgressRepository` creates it on first read.
struct UserProgress: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    var xp: Int = 0
    var coins: Int = 0

    // MARK: Focus streak

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    /// Midnight of the last day with at least one completed session.
    var lastSessionDay: Date?

    // MARK: Streak freezes

    /// Two per calendar month, applied automatically and retroactively.
    var freezesRemaining: Int = UserProgress.freezesPerMonth
    var freezesUsedThisMonth: Int = 0
    /// Midnight of the first day of the month the freeze budget belongs to.
    var freezeMonthAnchor: Date?

    // MARK: Calm streak

    /// Counted separately from the focus streak, never punitive, never reset
    /// with any drama. Missing days simply do not appear.
    var calmStreak: Int = 0
    var longestCalmStreak: Int = 0
    var lastSitDay: Date?

    // MARK: Constants

    static let freezesPerMonth = 2

    /// XP required to *reach* a given level. Level 1 is the start.
    ///
    /// Quadratic-ish so early levels arrive fast — the first three should land
    /// within the first couple of sessions — and later ones pace out.
    static func xpRequired(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = level - 1
        return 50 * n * (n + 1) / 2
    }

    /// Level implied by an XP total.
    static func level(forXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp {
            level += 1
        }
        return level
    }

    var level: Int { Self.level(forXP: xp) }

    var xpIntoCurrentLevel: Int { xp - Self.xpRequired(forLevel: level) }

    var xpNeededForNextLevel: Int {
        Self.xpRequired(forLevel: level + 1) - Self.xpRequired(forLevel: level)
    }

    /// 0...1 progress toward the next level.
    var levelProgress: Double {
        let needed = xpNeededForNextLevel
        guard needed > 0 else { return 0 }
        return min(max(Double(xpIntoCurrentLevel) / Double(needed), 0), 1)
    }
}

/// A cosmetic the user can unlock by level or buy with coins.
struct Unlockable: SyncableRecord, Codable {
    var id: UUID = UUID()
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var deletedAt: Date?

    /// Stable identifier for the asset this row unlocks, e.g. `theme.midnight`.
    var key: String = ""
    var type: UnlockableType = .theme
    var title: String = ""
    var detail: String = ""

    /// Zero means no level gate.
    var requiredLevel: Int = 0
    /// Zero means it cannot be bought, only unlocked by level.
    var coinCost: Int = 0

    var unlockedAt: Date?
    var isEquipped: Bool = false

    var isUnlocked: Bool { unlockedAt != nil }
}
