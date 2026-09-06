import Foundation
import Observation

@MainActor
@Observable
final class CollectionModel {
    private let repositories: any RepositoryProvider
    private let rewards: RewardService

    private(set) var items: [Unlockable] = []
    private(set) var coins = 0
    private(set) var level = 1
    private(set) var error: String?
    private(set) var notice: String?

    init(repositories: any RepositoryProvider, rewards: RewardService) {
        self.repositories = repositories
        self.rewards = rewards
    }

    func load() async {
        do {
            items = try await repositories.collection.unlockables()
            let progress = try await repositories.progress.progress()
            coins = progress.coins
            level = progress.level
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func items(of type: UnlockableType) -> [Unlockable] {
        items.filter { $0.type == type }
    }

    var ownedCount: Int { items.filter(\.isUnlocked).count }

    func canAfford(_ item: Unlockable) -> Bool {
        item.isPurchasable && coins >= item.coinCost
    }

    func purchase(_ item: Unlockable) async {
        do {
            try await rewards.purchase(item)
            notice = "\(item.title) is yours."
            await load()
        } catch let repositoryError as RepositoryError {
            // Not being able to afford something is information, not an error
            // worth a red banner.
            notice = repositoryError.errorDescription
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func equip(_ item: Unlockable) async {
        do {
            try await repositories.collection.equip(key: item.key)
            await load()
        } catch let repositoryError as RepositoryError {
            notice = repositoryError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func dismissNotice() { notice = nil }
}
