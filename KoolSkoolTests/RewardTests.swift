import Foundation
import Testing
@testable import KoolSkool

@Suite("Reward calculation")
struct RewardCalculatorTests {

    private func session(minutes: Int, resistance: Int? = nil, completed: Bool = true) -> FocusSession {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = start
        session.endedAt = start.addingTimeInterval(Double(minutes) * 60)
        session.plannedDuration = Double(minutes) * 60
        session.wasCompleted = completed
        session.resistanceAtStart = resistance.map { Rating(clamping: $0) }
        return session
    }

    @Test("XP scales with duration")
    func xpScalesWithDuration() {
        #expect(RewardCalculator.reward(for: session(minutes: 25), rolls: .noBonus).xp == 50)
        #expect(RewardCalculator.reward(for: session(minutes: 52), rolls: .noBonus).xp == 104)
    }

    @Test("A five-minute Just Start pays a real amount")
    func minimumXPFloor() {
        // If the smallest possible commitment paid nothing, the mode would be
        // a lie.
        let reward = RewardCalculator.reward(for: session(minutes: 5), rolls: .noBonus)
        #expect(reward.xp == RewardRules.minimumXP)
        #expect(reward.coins >= RewardRules.minimumCoins)
    }

    @Test("Resistance raises the payout")
    func resistanceMultiplier() {
        let easy = RewardCalculator.reward(for: session(minutes: 25, resistance: 1), rolls: .noBonus)
        let hard = RewardCalculator.reward(for: session(minutes: 25, resistance: 5), rolls: .noBonus)
        let unrated = RewardCalculator.reward(for: session(minutes: 25), rolls: .noBonus)

        #expect(easy.xp == 50)
        #expect(unrated.xp == 50)
        #expect(hard.xp == 80)
        #expect(hard.xp > easy.xp)
    }

    @Test("The multiplier runs 1.0 to 1.6")
    func multiplierRange() {
        #expect(RewardCalculator.resistanceMultiplier(nil) == 1)
        #expect(RewardCalculator.resistanceMultiplier(Rating(clamping: 1)) == 1)
        #expect(abs(RewardCalculator.resistanceMultiplier(Rating(clamping: 5)) - 1.6) < 0.0001)
    }

    @Test("Coins track five-minute blocks")
    func coinMaths() {
        #expect(RewardCalculator.reward(for: session(minutes: 5), rolls: .noBonus).coins == 1)
        #expect(RewardCalculator.reward(for: session(minutes: 25), rolls: .noBonus).coins == 5)
        #expect(RewardCalculator.reward(for: session(minutes: 52), rolls: .noBonus).coins == 10)
    }

    @Test("An unfinished session earns nothing")
    func noRewardForUnfinished() {
        let reward = RewardCalculator.reward(for: session(minutes: 12, completed: false), rolls: RewardRolls(bonus: 0))
        #expect(reward.xp == 0)
        #expect(reward.coins == 0)
        #expect(reward.bonus == nil)
    }

    // MARK: The chest

    @Test("No chest above the threshold")
    func noBonusAboveThreshold() {
        let reward = RewardCalculator.reward(for: session(minutes: 25), rolls: RewardRolls(bonus: 0.9))
        #expect(reward.bonus == nil)
        #expect(reward.coins == reward.baseCoins)
    }

    @Test("A chest below the threshold multiplies coins")
    func coinChest() {
        let reward = RewardCalculator.reward(
            for: session(minutes: 25),
            rolls: RewardRolls(bonus: 0.05, kind: 0.1, magnitude: 0.1)
        )
        #expect(reward.bonus == .coinMultiplier(2))
        #expect(reward.baseCoins == 5)
        #expect(reward.coins == 10)
    }

    @Test("The top of the magnitude range gives the bigger multiplier")
    func biggerMultiplier() {
        let reward = RewardCalculator.reward(
            for: session(minutes: 25),
            rolls: RewardRolls(bonus: 0.05, kind: 0.1, magnitude: 0.99)
        )
        #expect(reward.bonus == .coinMultiplier(3))
        #expect(reward.coins == 15)
    }

    @Test("A cosmetic chest leaves the coins alone")
    func cosmeticChest() {
        let reward = RewardCalculator.reward(
            for: session(minutes: 25),
            rolls: RewardRolls(bonus: 0.05, kind: 0.9)
        )
        #expect(reward.bonus == .cosmetic)
        #expect(reward.coins == reward.baseCoins)
    }

    @Test("The base reward always lands, whatever the chest does")
    func baseAlwaysLands() {
        // Intermittent reinforcement is fenced in: the chest can only ever add.
        for bonus in stride(from: 0.0, through: 0.95, by: 0.05) {
            for kind in [0.1, 0.9] {
                let reward = RewardCalculator.reward(
                    for: session(minutes: 25, resistance: 3),
                    rolls: RewardRolls(bonus: bonus, kind: kind, magnitude: 0.5)
                )
                #expect(reward.xp == 65)
                #expect(reward.coins >= reward.baseCoins)
                #expect(reward.baseCoins == 5)
            }
        }
    }

    @Test("The chest is rare, not constant")
    func bonusFrequency() {
        var chests = 0
        let samples = 1000
        for index in 0..<samples {
            let roll = Double(index) / Double(samples)
            let reward = RewardCalculator.reward(for: session(minutes: 25), rolls: RewardRolls(bonus: roll, kind: 0.1))
            if reward.hasBonus { chests += 1 }
        }
        // Roughly one in five, by construction.
        #expect(abs(Double(chests) / Double(samples) - RewardRules.bonusChance) < 0.01)
    }
}

@MainActor
@Suite("Reward service")
struct RewardServiceTests {

    struct Stack {
        let service: RewardService
        let provider: SwiftDataRepositoryProvider
        let clock: MutableDateProvider
    }

    private func makeStack(rolls: RewardRolls = .noBonus) async throws -> Stack {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let service = RewardService(repositories: provider, clock: clock, rolls: { rolls })
        return Stack(service: service, provider: provider, clock: clock)
    }

    private func completedSession(minutes: Int, at date: Date, resistance: Int? = nil) -> FocusSession {
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.startedAt = date
        session.endedAt = date.addingTimeInterval(Double(minutes) * 60)
        session.plannedDuration = Double(minutes) * 60
        session.wasCompleted = true
        session.endReason = .reachedPlannedEnd
        session.resistanceAtStart = resistance.map { Rating(clamping: $0) }
        return session
    }

    @Test("Seeding hands over the starter items and nothing else")
    func catalogueSeeding() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()

        let items = try await stack.provider.collection.unlockables()
        #expect(items.count == UnlockableCatalogue.all.count)

        let owned = items.filter(\.isUnlocked)
        #expect(owned.count == UnlockableCatalogue.starterKeys.count)
        #expect(owned.allSatisfy { $0.requiredLevel <= 1 && $0.coinCost == 0 })
    }

    @Test("Seeding twice does not duplicate or revoke")
    func reseedIsSafe() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()
        try await stack.service.prepareCatalogue()

        let items = try await stack.provider.collection.unlockables()
        #expect(items.count == UnlockableCatalogue.all.count)
        #expect(items.filter(\.isUnlocked).count == UnlockableCatalogue.starterKeys.count)
    }

    @Test("Awarding a session moves XP, coins, and the streak together")
    func awardUpdatesEverything() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()

        let session = try await stack.provider.sessions.upsert(
            completedSession(minutes: 25, at: stack.clock.now)
        )
        let outcome = try await stack.service.award(for: session)

        #expect(outcome.xp == 50)
        #expect(outcome.coins == 5)
        #expect(outcome.totalXP == 50)
        #expect(outcome.streak == 1)
        #expect(outcome.didExtendStreak)

        let progress = try await stack.provider.progress.progress()
        #expect(progress.xp == 50)
        #expect(progress.coins == 5)
        #expect(progress.currentStreak == 1)
    }

    @Test("The payout is written onto the session for the record")
    func sessionRecordsItsPayout() async throws {
        let stack = try await makeStack()
        let session = try await stack.provider.sessions.upsert(
            completedSession(minutes: 25, at: stack.clock.now)
        )
        _ = try await stack.service.award(for: session)

        let stored = try #require(await stack.provider.sessions.session(id: session.id))
        #expect(stored.xpAwarded == 50)
        #expect(stored.coinsAwarded == 5)
        #expect(stored.earnedBonus == false)
    }

    @Test("Levelling up hands over everything that level unlocks")
    func levelUpUnlocks() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()

        // 150 XP reaches level 3, which the Acid theme is gated on.
        let session = try await stack.provider.sessions.upsert(
            completedSession(minutes: 75, at: stack.clock.now)
        )
        let outcome = try await stack.service.award(for: session)

        #expect(outcome.didLevelUp)
        #expect(outcome.level >= 3)

        let acid = try #require(await stack.provider.collection.unlockable(key: "theme.acid"))
        #expect(acid.isUnlocked)

        // Something gated higher up stays locked.
        let paper = try #require(await stack.provider.collection.unlockable(key: "theme.paper"))
        #expect(paper.isUnlocked == false)
    }

    @Test("A cosmetic chest actually hands something over")
    func cosmeticChestUnlocks() async throws {
        let stack = try await makeStack(rolls: RewardRolls(bonus: 0.01, kind: 0.9))
        try await stack.service.prepareCatalogue()

        let session = try await stack.provider.sessions.upsert(
            completedSession(minutes: 25, at: stack.clock.now)
        )
        let outcome = try await stack.service.award(for: session)

        #expect(outcome.bonus == .cosmetic)
        let unlocked = try #require(outcome.unlocked)
        #expect(unlocked.isUnlocked)
    }

    @Test("An unfinished session pays nothing and touches nothing")
    func unfinishedSessionPaysNothing() async throws {
        let stack = try await makeStack()

        var session = completedSession(minutes: 6, at: stack.clock.now)
        session.wasCompleted = false
        session.endReason = .endedByUser
        let stored = try await stack.provider.sessions.upsert(session)

        let outcome = try await stack.service.award(for: stored)
        #expect(outcome.xp == 0)
        #expect(outcome.coins == 0)
        #expect(outcome.streak == 0)

        let progress = try await stack.provider.progress.progress()
        #expect(progress.xp == 0)
    }

    @Test("Buying something spends the coins")
    func purchaseSpendsCoins() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()

        var progress = try await stack.provider.progress.progress()
        progress.coins = 200
        _ = try await stack.provider.progress.update(progress)

        let ember = try #require(await stack.provider.collection.unlockable(key: "theme.ember"))
        try await stack.service.purchase(ember)

        let after = try await stack.provider.progress.progress()
        #expect(after.coins == 50)

        let owned = try #require(await stack.provider.collection.unlockable(key: "theme.ember"))
        #expect(owned.isUnlocked)
    }

    @Test("Buying without enough coins is refused and costs nothing")
    func purchaseRefusedWhenShort() async throws {
        let stack = try await makeStack()
        try await stack.service.prepareCatalogue()

        let ember = try #require(await stack.provider.collection.unlockable(key: "theme.ember"))

        await #expect(throws: RepositoryError.self) {
            try await stack.service.purchase(ember)
        }

        let progress = try await stack.provider.progress.progress()
        #expect(progress.coins == 0)

        let stillLocked = try #require(await stack.provider.collection.unlockable(key: "theme.ember"))
        #expect(stillLocked.isUnlocked == false)
    }

    @Test("Refreshing the streak is safe to run repeatedly")
    func refreshStreakIsIdempotent() async throws {
        let stack = try await makeStack()

        for offset in [0, 1, 2] {
            let day = stack.clock.now.addingTimeInterval(-Double(offset) * 86_400)
            _ = try await stack.provider.sessions.upsert(completedSession(minutes: 25, at: day))
        }

        let first = try await stack.service.refreshStreak()
        let second = try await stack.service.refreshStreak()

        #expect(first.currentStreak == 3)
        #expect(second.currentStreak == 3)
        #expect(second.longestStreak == 3)
    }

    @Test("A streak the freezes rescued shows up in progress")
    func freezesReachProgress() async throws {
        let stack = try await makeStack()

        // Active today and three days ago, so two days need covering.
        for offset in [0, 3] {
            let day = stack.clock.now.addingTimeInterval(-Double(offset) * 86_400)
            _ = try await stack.provider.sessions.upsert(completedSession(minutes: 25, at: day))
        }

        let progress = try await stack.service.refreshStreak()
        #expect(progress.currentStreak == 2)
        #expect(progress.freezesUsedThisMonth == 2)
        #expect(progress.freezesRemaining == 0)
    }
}
