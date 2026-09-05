import Foundation
import SwiftData

@Model
final class SDUserProgress {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var xp: Int = 0
    var coins: Int = 0

    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastSessionDay: Date?

    var freezesRemaining: Int = UserProgress.freezesPerMonth
    var freezesUsedThisMonth: Int = 0
    var freezeMonthAnchor: Date?

    var calmStreak: Int = 0
    var longestCalmStreak: Int = 0
    var lastSitDay: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        xp: Int = 0,
        coins: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastSessionDay: Date? = nil,
        freezesRemaining: Int = UserProgress.freezesPerMonth,
        freezesUsedThisMonth: Int = 0,
        freezeMonthAnchor: Date? = nil,
        calmStreak: Int = 0,
        longestCalmStreak: Int = 0,
        lastSitDay: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.xp = xp
        self.coins = coins
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastSessionDay = lastSessionDay
        self.freezesRemaining = freezesRemaining
        self.freezesUsedThisMonth = freezesUsedThisMonth
        self.freezeMonthAnchor = freezeMonthAnchor
        self.calmStreak = calmStreak
        self.longestCalmStreak = longestCalmStreak
        self.lastSitDay = lastSitDay
    }
}

@Model
final class SDUnlockable {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    /// Stable catalogue key, e.g. `theme.midnight`. This is the identity used
    /// when reseeding, so unlock state survives app updates.
    var key: String = ""
    var typeRaw: String = UnlockableType.theme.rawValue
    var title: String = ""
    var detail: String = ""
    var requiredLevel: Int = 0
    var coinCost: Int = 0
    var unlockedAt: Date?
    var isEquipped: Bool = false

    var type: UnlockableType {
        get { UnlockableType(rawValue: typeRaw) ?? .theme }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        key: String = "",
        typeRaw: String = UnlockableType.theme.rawValue,
        title: String = "",
        detail: String = "",
        requiredLevel: Int = 0,
        coinCost: Int = 0,
        unlockedAt: Date? = nil,
        isEquipped: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.key = key
        self.typeRaw = typeRaw
        self.title = title
        self.detail = detail
        self.requiredLevel = requiredLevel
        self.coinCost = coinCost
        self.unlockedAt = unlockedAt
        self.isEquipped = isEquipped
    }
}

// MARK: - Mapping

extension SDUserProgress {
    func toDomain() -> UserProgress {
        UserProgress(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            xp: xp,
            coins: coins,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastSessionDay: lastSessionDay,
            freezesRemaining: freezesRemaining,
            freezesUsedThisMonth: freezesUsedThisMonth,
            freezeMonthAnchor: freezeMonthAnchor,
            calmStreak: calmStreak,
            longestCalmStreak: longestCalmStreak,
            lastSitDay: lastSitDay
        )
    }

    func apply(_ dto: UserProgress) {
        xp = dto.xp
        coins = dto.coins
        currentStreak = dto.currentStreak
        longestStreak = dto.longestStreak
        lastSessionDay = dto.lastSessionDay
        freezesRemaining = dto.freezesRemaining
        freezesUsedThisMonth = dto.freezesUsedThisMonth
        freezeMonthAnchor = dto.freezeMonthAnchor
        calmStreak = dto.calmStreak
        longestCalmStreak = dto.longestCalmStreak
        lastSitDay = dto.lastSitDay
        deletedAt = dto.deletedAt
    }
}

extension SDUnlockable {
    func toDomain() -> Unlockable {
        Unlockable(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            key: key,
            type: type,
            title: title,
            detail: detail,
            requiredLevel: requiredLevel,
            coinCost: coinCost,
            unlockedAt: unlockedAt,
            isEquipped: isEquipped
        )
    }

    /// Applies only the fields the catalogue owns, leaving unlock state alone.
    /// Used when reseeding after an app update.
    func applyCatalogueFields(_ dto: Unlockable) {
        typeRaw = dto.type.rawValue
        title = dto.title
        detail = dto.detail
        requiredLevel = dto.requiredLevel
        coinCost = dto.coinCost
    }

    func apply(_ dto: Unlockable) {
        applyCatalogueFields(dto)
        key = dto.key
        unlockedAt = dto.unlockedAt
        isEquipped = dto.isEquipped
        deletedAt = dto.deletedAt
    }

    static func make(from dto: Unlockable) -> SDUnlockable {
        SDUnlockable(
            id: dto.id,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            deletedAt: dto.deletedAt,
            key: dto.key,
            typeRaw: dto.type.rawValue,
            title: dto.title,
            detail: dto.detail,
            requiredLevel: dto.requiredLevel,
            coinCost: dto.coinCost,
            unlockedAt: dto.unlockedAt,
            isEquipped: dto.isEquipped
        )
    }
}
