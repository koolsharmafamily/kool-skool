import Foundation

/// The extra that a chest can contain. Never a substitute for the base reward,
/// only ever an addition to it.
enum BonusReward: Sendable, Equatable, Hashable {
    case coinMultiplier(Int)
    /// The calculator only decides *that* a cosmetic dropped. Which one is a
    /// question about what the user already owns, so `RewardService` resolves it.
    case cosmetic
}

/// What one completed session is worth.
struct SessionReward: Sendable, Equatable {
    var xp: Int
    var baseCoins: Int
    var coins: Int
    var bonus: BonusReward?

    var hasBonus: Bool { bonus != nil }
    var bonusCoins: Int { coins - baseCoins }
}

/// The three random draws a reward needs, taken at the edge so the calculation
/// itself stays a pure function.
struct RewardRolls: Sendable, Equatable {
    /// Below `RewardRules.bonusChance`, a chest drops.
    var bonus: Double
    /// Chooses coins or cosmetic.
    var kind: Double
    /// Chooses which coin multiplier.
    var magnitude: Double

    init(bonus: Double, kind: Double = 0, magnitude: Double = 0) {
        self.bonus = bonus
        self.kind = kind
        self.magnitude = magnitude
    }

    static func random() -> RewardRolls {
        RewardRolls(
            bonus: Double.random(in: 0..<1),
            kind: Double.random(in: 0..<1),
            magnitude: Double.random(in: 0..<1)
        )
    }

    /// No chest. Handy in tests that care about the base reward only.
    static let noBonus = RewardRolls(bonus: 1)
}

enum RewardCalculator {

    /// Pure. Same session and same rolls always produce the same reward.
    ///
    /// A session that was not completed earns nothing — not as a penalty, just
    /// because there is nothing to pay out for. The 80% rule in `FocusRules`
    /// already means most honest early finishes count as completed.
    static func reward(for session: FocusSession, rolls: RewardRolls) -> SessionReward {
        guard session.wasCompleted else {
            return SessionReward(xp: 0, baseCoins: 0, coins: 0, bonus: nil)
        }

        let minutes = max(1, session.actualMinutes)

        let baseXP = max(RewardRules.minimumXP, minutes * RewardRules.xpPerMinute)
        let multiplier = resistanceMultiplier(session.resistanceAtStart)
        let xp = Int((Double(baseXP) * multiplier).rounded())

        let baseCoins = max(RewardRules.minimumCoins, minutes / RewardRules.minutesPerCoin)

        guard rolls.bonus < RewardRules.bonusChance else {
            return SessionReward(xp: xp, baseCoins: baseCoins, coins: baseCoins, bonus: nil)
        }

        if rolls.kind >= RewardRules.cosmeticShare {
            return SessionReward(xp: xp, baseCoins: baseCoins, coins: baseCoins, bonus: .cosmetic)
        }

        let multipliers = RewardRules.coinMultipliers
        let index = min(multipliers.count - 1, Int(rolls.magnitude * Double(multipliers.count)))
        let coinMultiplier = multipliers[max(0, index)]

        return SessionReward(
            xp: xp,
            baseCoins: baseCoins,
            coins: baseCoins * coinMultiplier,
            bonus: .coinMultiplier(coinMultiplier)
        )
    }

    /// 1.0 at resistance 1, 1.6 at resistance 5. Unrated sessions pay flat.
    static func resistanceMultiplier(_ rating: Rating?) -> Double {
        guard let rating else { return 1 }
        return 1 + Double(rating.rawValue - 1) * RewardRules.resistanceBonusPerStep
    }
}
