import SwiftUI

/// Where coins go.
///
/// Two ways in, deliberately: levels hand things over on their own, coins let
/// you pick which one arrives sooner. That choice is the point of having two
/// currencies rather than one.
struct CollectionView: View {
    let model: CollectionModel

    var body: some View {
        KSScreen(state: .breakTime) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    balance

                    if let notice = model.notice {
                        noticeBanner(notice)
                    }

                    honestyNote

                    ForEach(UnlockableType.allCases) { type in
                        section(type)
                    }

                    if let error = model.error {
                        Text(error)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.accent(.overrun))
                    }
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .task { await model.load() }
    }

    // MARK: Sections

    private var balance: some View {
        HStack(spacing: KSSpacing.xs) {
            KSTag(text: "\(model.coins) coins", systemImage: "circle.hexagongrid.fill", state: .breakTime)
            KSTag(text: "Level \(model.level)", systemImage: "chart.line.uptrend.xyaxis", state: .ready)
            Spacer()
            Text("\(model.ownedCount) of \(model.items.count)")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
    }

    /// Straight about what these do today. Selling someone a soundscape before
    /// there is any audio would be a small lie, and small lies are how an app
    /// stops being trusted.
    private var honestyNote: some View {
        Text("Everything here is earned and kept. Equipping takes visual effect as each feature ships — companions and soundscapes arrive with the body doubling layer.")
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textTertiary)
    }

    @ViewBuilder
    private func section(_ type: UnlockableType) -> some View {
        let entries = model.items(of: type)

        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text(type.displayName)
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textSecondary)

                ForEach(entries) { item in
                    CollectionRow(
                        item: item,
                        level: model.level,
                        canAfford: model.canAfford(item),
                        onBuy: { Task { await model.purchase(item) } },
                        onEquip: { Task { await model.equip(item) } }
                    )
                }
            }
        }
    }

    private func noticeBanner(_ notice: String) -> some View {
        KSCard {
            HStack(alignment: .top, spacing: KSSpacing.xs) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(KSColor.accent(.breakTime))
                Text(notice)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textPrimary)
                Spacer(minLength: 0)
                Button("OK") { model.dismissNotice() }
                    .ksFont(KSFont.label)
            }
        }
    }
}

private struct CollectionRow: View {
    let item: Unlockable
    let level: Int
    let canAfford: Bool
    let onBuy: () -> Void
    let onEquip: () -> Void

    var body: some View {
        KSCard(padding: KSSpacing.sm) {
            HStack(spacing: KSSpacing.sm) {
                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Text(item.title)
                        .ksFont(KSFont.body)
                        .foregroundStyle(item.isUnlocked ? KSColor.textPrimary : KSColor.textSecondary)

                    Text(item.detail)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                }

                Spacer(minLength: 0)
                trailing
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.availabilityLabel(level: level))")
    }

    @ViewBuilder
    private var trailing: some View {
        if item.isEquipped {
            KSTag(text: "Equipped", systemImage: "checkmark", state: .focusing)
        } else if item.isUnlocked {
            Button("Equip", action: onEquip)
                .ksFont(KSFont.label)
        } else if item.isPurchasable {
            Button(action: onBuy) {
                Label("\(item.coinCost)", systemImage: "circle.hexagongrid.fill")
                    .ksFont(KSFont.label)
            }
            .foregroundStyle(canAfford ? KSColor.accent(.breakTime) : KSColor.textTertiary)
        } else {
            Text("Level \(item.requiredLevel)")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
    }
}
