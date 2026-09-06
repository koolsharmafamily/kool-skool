import SwiftUI

/// The moment after a completed session.
///
/// About a second and a half, and a tap anywhere ends it early. It has to be
/// worth watching the first ten times and never in the way on the hundredth,
/// which is the whole reason it is short and skippable rather than grand.
struct CelebrationOverlay: View {
    let award: AwardOutcome
    let onFinish: () -> Void

    @Environment(\.ksReduceMotion) private var reduceMotion
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            KSColor.canvas
                .opacity(0.96)
                .ignoresSafeArea()

            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: KSSpacing.md) {
                if award.didLevelUp {
                    KSTag(text: "Level \(award.level)", systemImage: "arrow.up.circle.fill", state: .breakTime)
                }

                RollingNumber(target: award.xp, prefix: "+", suffix: " XP")
                    .ksFont(KSFont.display)
                    .foregroundStyle(KSColor.accent(.focusing))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                HStack(spacing: KSSpacing.md) {
                    RollingNumber(target: award.coins, prefix: "+", suffix: " coins")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.accent(.breakTime))

                    if award.didExtendStreak {
                        Text(award.streak == 1 ? "Day 1" : "Day \(award.streak)")
                            .ksFont(KSFont.headline)
                            .foregroundStyle(KSColor.accent(.overrun))
                    }
                }

                if let bonusLine {
                    Text(bonusLine)
                        .ksFont(KSFont.label)
                        .foregroundStyle(KSColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, KSSpacing.xs)
                }
            }
            .padding(KSSpacing.screenMargin)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .task {
            await KSHaptics.shared.celebrate()
            try? await Task.sleep(for: .seconds(RewardRules.celebrationDuration))
            finish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenSummary)
        .accessibilityHint("Tap to continue")
        .accessibilityAddTraits(.isButton)
    }

    private var bonusLine: String? {
        guard let bonus = award.bonus else { return nil }
        switch bonus {
        case let .coinMultiplier(multiplier):
            return "Bonus chest — \(multiplier)x coins"
        case .cosmetic:
            guard let unlocked = award.unlocked else { return "Bonus chest" }
            return "Bonus chest — \(unlocked.title) unlocked"
        }
    }

    /// VoiceOver gets the whole thing in one utterance rather than three numbers
    /// rolling past it.
    private var spokenSummary: String {
        var parts = ["\(award.xp) XP", "\(award.coins) coins"]
        if award.didLevelUp { parts.append("level \(award.level)") }
        if award.didExtendStreak { parts.append("day \(award.streak)") }
        if let bonusLine { parts.append(bonusLine) }
        return parts.joined(separator: ", ")
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}

/// The quiet, permanent version shown on the completion screen once the
/// celebration has played.
struct RewardSummary: View {
    let award: AwardOutcome

    private var coinMultiplier: Int? {
        guard let bonus = award.bonus, case let .coinMultiplier(multiplier) = bonus else { return nil }
        return multiplier
    }

    var body: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                HStack(spacing: KSSpacing.xs) {
                    KSTag(text: "+\(award.xp) XP", systemImage: "bolt.fill", state: .focusing)
                    KSTag(text: "+\(award.coins)", systemImage: "circle.hexagongrid.fill", state: .breakTime)
                    if award.streak > 0 {
                        KSTag(text: "Day \(award.streak)", systemImage: "flame.fill", state: .overrun)
                    }
                }

                if let unlocked = award.unlocked {
                    Text("Unlocked \(unlocked.title).")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                } else if let multiplier = coinMultiplier {
                    Text("Bonus chest — \(multiplier)x coins on this one.")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }

                if award.didLevelUp {
                    Text("Level \(award.level).")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }
        }
    }
}
