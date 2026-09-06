import Foundation

/// The reward economy, in one place.
///
/// Gamification here is functional, not decorative, and it is designed so it
/// cannot become a source of shame: the base reward always lands, only the bonus
/// is random, and nothing is ever taken away.
enum RewardRules {

    // MARK: XP

    static let xpPerMinute = 2

    /// A five-minute Just Start is a real session and pays like one. If the
    /// smallest possible commitment paid nothing, the mode would be a lie.
    static let minimumXP = 10

    /// Each point of resistance above 1 adds this much to the payout.
    /// Rating 5 pays 1.6x — finishing something you have been avoiding for a
    /// week is worth more than finishing something easy.
    static let resistanceBonusPerStep = 0.15

    // MARK: Coins

    static let minutesPerCoin = 5
    static let minimumCoins = 1

    // MARK: Variable reward

    /// Roughly one completed session in five drops a chest.
    ///
    /// Intermittent reinforcement is the single most effective mechanic for this
    /// audience, which is exactly why it is fenced in: it only ever *adds*. The
    /// base XP and coins are never at risk.
    static let bonusChance = 0.2

    /// Below this the chest is coins; at or above it, a cosmetic.
    static let cosmeticShare = 0.5

    static let coinMultipliers = [2, 3]

    // MARK: Celebration

    /// Long enough to feel like something happened, short enough not to be in
    /// the way by the tenth session. Skippable by tap at any point.
    static let celebrationDuration: TimeInterval = 1.5
    static let countUpDuration: TimeInterval = 0.8
}
