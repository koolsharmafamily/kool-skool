import Foundation

/// The things XP and coins buy.
///
/// Two currencies so the reward is a choice rather than a schedule: levels hand
/// you things on their own, coins let you pick which one arrives sooner.
///
/// Keys are frozen — they are how a row is matched on reseed, which is what
/// stops an app update from revoking something already earned. Ids are stable
/// UUIDs for the same reason.
enum UnlockableCatalogue {

    static let all: [Unlockable] = themes + companions + soundscapes + timerStyles

    /// Given free on first launch so nothing starts empty.
    static var starterKeys: [String] {
        all.filter { $0.requiredLevel <= 1 && $0.coinCost == 0 }.map(\.key)
    }

    // MARK: Themes

    static let themes: [Unlockable] = [
        make("11111111-0000-0000-0000-000000000001", "theme.midnight", .theme, "Midnight", "The default. Deep, dark, high contrast.", level: 1),
        make("11111111-0000-0000-0000-000000000002", "theme.acid", .theme, "Acid", "Turn the green up.", level: 3),
        make("11111111-0000-0000-0000-000000000003", "theme.ember", .theme, "Ember", "Warm and low-light.", coins: 150),
        make("11111111-0000-0000-0000-000000000004", "theme.paper", .theme, "Paper", "Light mode, done properly.", level: 8),
    ]

    // MARK: Companions

    static let companions: [Unlockable] = [
        make("22222222-0000-0000-0000-000000000001", "companion.lamp", .companionSkin, "Desk Lamp", "Quietly on while you work.", level: 1),
        make("22222222-0000-0000-0000-000000000002", "companion.owl", .companionSkin, "Owl", "Awake at the same hours you are.", level: 2),
        make("22222222-0000-0000-0000-000000000003", "companion.cat", .companionSkin, "Cat", "Supervising, mostly.", coins: 120),
        make("22222222-0000-0000-0000-000000000004", "companion.plant", .companionSkin, "Plant", "Grows a little each session.", level: 6),
    ]

    // MARK: Soundscapes

    static let soundscapes: [Unlockable] = [
        make("33333333-0000-0000-0000-000000000001", "sound.rain", .soundscape, "Rain", "Steady, no thunder.", level: 1),
        make("33333333-0000-0000-0000-000000000002", "sound.cafe", .soundscape, "Café", "Other people, working.", coins: 100),
        make("33333333-0000-0000-0000-000000000003", "sound.library", .soundscape, "Library", "Almost nothing, on purpose.", level: 4),
        make("33333333-0000-0000-0000-000000000004", "sound.brown", .soundscape, "Brown Noise", "A wall of low static.", level: 5),
    ]

    // MARK: Timer styles

    static let timerStyles: [Unlockable] = [
        make("44444444-0000-0000-0000-000000000001", "timer.disc", .timerStyle, "Disc", "The one that drains.", level: 1),
        make("44444444-0000-0000-0000-000000000002", "timer.bars", .timerStyle, "Bars", "Segments that empty one at a time.", level: 4),
        make("44444444-0000-0000-0000-000000000003", "timer.minimal", .timerStyle, "Minimal", "Digits and nothing else.", coins: 80),
    ]

    // MARK: Construction

    private static func make(
        _ id: String,
        _ key: String,
        _ type: UnlockableType,
        _ title: String,
        _ detail: String,
        level: Int = 0,
        coins: Int = 0
    ) -> Unlockable {
        var item = Unlockable()
        // A malformed literal here would be a build-time mistake, not a runtime
        // one, so a deterministic fallback keeps the app honest either way.
        item.id = UUID(uuidString: id) ?? UUID()
        item.key = key
        item.type = type
        item.title = title
        item.detail = detail
        item.requiredLevel = level
        item.coinCost = coins
        return item
    }
}

extension Unlockable {
    /// Whether the level gate is satisfied. Coin-priced items have no gate.
    func isUnlockableByLevel(_ level: Int) -> Bool {
        requiredLevel > 0 && level >= requiredLevel
    }

    var isPurchasable: Bool { coinCost > 0 }

    /// What the Collection screen shows under the title.
    func availabilityLabel(level: Int) -> String {
        if isUnlocked { return isEquipped ? "Equipped" : "Owned" }
        if isPurchasable { return "\(coinCost) coins" }
        if requiredLevel > 0 { return "Level \(requiredLevel)" }
        return "Locked"
    }
}
