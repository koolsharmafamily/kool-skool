import Foundation

/// What the celebration screen needs to know about what just happened.
struct AwardOutcome: Sendable, Equatable {
    var xp: Int
    var coins: Int
    var bonus: BonusReward?
    var unlocked: Unlockable?

    var level: Int
    var didLevelUp: Bool
    var totalXP: Int
    var totalCoins: Int

    var streak: Int
    var didExtendStreak: Bool
    var isLongestStreak: Bool

    var hasAnythingToShow: Bool { xp > 0 || coins > 0 }
}

/// Turns a finished session into XP, coins, a streak, and occasionally a chest.
///
/// Every write goes through the repositories, so this knows nothing about
/// SwiftData and can be pointed at a networked backend unchanged.
@MainActor
final class RewardService {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider
    /// Injected so the one-in-five chest is deterministic in tests.
    private let rolls: @Sendable () -> RewardRolls

    init(
        repositories: any RepositoryProvider,
        clock: any DateProvider,
        rolls: @escaping @Sendable () -> RewardRolls = { RewardRolls.random() }
    ) {
        self.repositories = repositories
        self.clock = clock
        self.rolls = rolls
    }

    /// Seeds the catalogue and hands over the starter items. Safe to call every
    /// launch — reseeding never touches what is already owned.
    func prepareCatalogue() async throws {
        try await repositories.collection.seedIfNeeded(UnlockableCatalogue.all)

        for key in UnlockableCatalogue.starterKeys {
            guard var item = try await repositories.collection.unlockable(key: key), !item.isUnlocked else { continue }
            item.unlockedAt = clock.now
            try await repositories.collection.upsert(item)
        }
    }

    /// Recomputes the streak from history. Called at launch and after every
    /// session, and idempotent either way.
    @discardableResult
    func refreshStreak() async throws -> UserProgress {
        let progress = try await repositories.progress.progress()
        let since = clock.now.addingTimeInterval(-Double(StreakCalculator.maximumLookbackDays) * 86_400)
        let days = try await repositories.sessions.completedSessionDays(since: since)

        let outcome = StreakCalculator.evaluate(
            completedDays: days,
            today: clock.now,
            previousLongest: progress.longestStreak,
            clock: clock
        )

        return try await repositories.progress.update(progress.applying(outcome))
    }

    /// Applies everything a completed session earns.
    ///
    /// The base XP and coins always land. Only the chest is random, and the
    /// chest only ever adds.
    func award(for session: FocusSession) async throws -> AwardOutcome {
        let before = try await repositories.progress.progress()
        let reward = RewardCalculator.reward(for: session, rolls: rolls())

        var progress = before
        progress.xp += reward.xp
        progress.coins += reward.coins

        let levelAfter = UserProgress.level(forXP: progress.xp)
        let didLevelUp = levelAfter > before.level

        // Level unlocks are handed over before a cosmetic chest is resolved, so
        // a chest never gives something the level just granted anyway.
        if didLevelUp {
            try await unlockItems(upToLevel: levelAfter)
        }

        var unlocked: Unlockable?
        var finalReward = reward

        if reward.bonus == .cosmetic {
            if let prize = try await randomLockedCosmetic(level: levelAfter) {
                unlocked = try await unlock(prize)
            } else {
                // Nothing left to give, so the chest pays out in coins instead.
                // A chest that opens onto nothing is worse than no chest.
                let multiplier = RewardRules.coinMultipliers.first ?? 2
                let extra = reward.baseCoins * (multiplier - 1)
                progress.coins += extra
                finalReward = SessionReward(
                    xp: reward.xp,
                    baseCoins: reward.baseCoins,
                    coins: reward.baseCoins * multiplier,
                    bonus: .coinMultiplier(multiplier)
                )
            }
        }

        let saved = try await repositories.progress.update(progress)

        // Record what was paid on the session itself, so history stays auditable.
        var stamped = session
        stamped.xpAwarded = finalReward.xp
        stamped.coinsAwarded = finalReward.coins
        stamped.earnedBonus = finalReward.hasBonus
        try await repositories.sessions.upsert(stamped)

        let afterStreak = try await refreshStreak()

        return AwardOutcome(
            xp: finalReward.xp,
            coins: finalReward.coins,
            bonus: finalReward.bonus,
            unlocked: unlocked,
            level: afterStreak.level,
            didLevelUp: didLevelUp,
            totalXP: afterStreak.xp,
            totalCoins: afterStreak.coins,
            streak: afterStreak.currentStreak,
            didExtendStreak: afterStreak.currentStreak > before.currentStreak,
            isLongestStreak: afterStreak.currentStreak > 0 && afterStreak.currentStreak >= afterStreak.longestStreak
        )
    }

    /// Spends coins on a catalogue item.
    func purchase(_ item: Unlockable) async throws {
        guard !item.isUnlocked else { return }
        guard item.isPurchasable else {
            throw RepositoryError.invalidInput("\(item.title) cannot be bought.")
        }

        var progress = try await repositories.progress.progress()
        guard progress.coins >= item.coinCost else {
            throw RepositoryError.invalidInput("Not enough coins yet — \(item.coinCost - progress.coins) to go.")
        }

        progress.coins -= item.coinCost
        _ = try await repositories.progress.update(progress)
        _ = try await unlock(item)
    }

    // MARK: Internals

    @discardableResult
    private func unlock(_ item: Unlockable) async throws -> Unlockable {
        var updated = item
        updated.unlockedAt = clock.now
        return try await repositories.collection.upsert(updated)
    }

    private func unlockItems(upToLevel level: Int) async throws {
        let all = try await repositories.collection.unlockables()
        for item in all where !item.isUnlocked && item.isUnlockableByLevel(level) {
            try await unlock(item)
        }
    }

    /// A chest cosmetic is drawn from what is locked *and* not already promised
    /// by a level the user has reached, so it always feels like a shortcut
    /// rather than a duplicate.
    private func randomLockedCosmetic(level: Int) async throws -> Unlockable? {
        let candidates = try await repositories.collection.unlockables()
            .filter { !$0.isUnlocked && !$0.isUnlockableByLevel(level) }
        return candidates.randomElement()
    }
}
