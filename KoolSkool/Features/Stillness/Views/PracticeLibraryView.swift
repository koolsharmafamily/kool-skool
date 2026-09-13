import SwiftUI

/// The practice library.
///
/// Everything is short, everything has an anchor, and nothing here is
/// open-ended silent sitting — except the one practice that is, and it stays
/// out of sight until twenty sits have happened. That ordering is the whole
/// argument of this layer: "sit still and clear your mind" is where most people
/// decide meditation is not for them.
struct PracticeLibraryView: View {
    let entries: [PracticeEntry]
    let tradition: Tradition
    let calmStreak: Int
    let completedSits: Int
    let onStart: (Practice, TimeInterval) -> Void
    let onOpenReflection: () -> Void
    let onChangeTradition: (Tradition) -> Void

    @State private var expanded: UUID?
    @State private var isPickingTradition = false

    var body: some View {
        KSScreen(state: .stillness) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.md) {
                    summary
                    reflectionRow
                    framingRow

                    Text("Practices")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)
                        .padding(.top, KSSpacing.xs)

                    ForEach(entries) { entry in
                        card(for: entry)
                    }

                    Text(StillnessCopy.wandering(tradition))
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                        .padding(.top, KSSpacing.xs)
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Stillness")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickingTradition) {
            TraditionPickerSheet(
                selected: tradition,
                onSelect: { newValue in
                    onChangeTradition(newValue)
                    isPickingTradition = false
                },
                onClose: { isPickingTradition = false }
            )
        }
    }

    // MARK: Pieces

    /// The calm streak, counted separately from the focus streak and never
    /// punitive. A day without a sit is simply a day that does not appear.
    private var summary: some View {
        KSCard {
            HStack(spacing: KSSpacing.md) {
                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Text(StillnessCopy.calmStreakLabel(calmStreak))
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)

                    Text(calmStreak > 0 ? "in a row" : "Start whenever")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: KSSpacing.xxs) {
                    Text("\(completedSits)")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)

                    Text(completedSits == 1 ? "sit" : "sits")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var reflectionRow: some View {
        Button(action: onOpenReflection) {
            KSCard {
                HStack(spacing: KSSpacing.sm) {
                    Image(systemName: "sunrise")
                        .foregroundStyle(KSColor.accent(.stillness))

                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text("Intention and close")
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)

                        Text("A line in the morning, three taps at night. Neither is required.")
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(KSColor.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var framingRow: some View {
        Button {
            isPickingTradition = true
        } label: {
            KSCard {
                HStack(spacing: KSSpacing.sm) {
                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text("Framing")
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)

                        Text(tradition.displayName)
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(KSColor.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func card(for entry: PracticeEntry) -> some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Button {
                    guard entry.isAvailable else { return }
                    KSHaptics.shared.fire(.selection)
                    withKSAnimation(KSAnimation.calm) {
                        expanded = expanded == entry.id ? nil : entry.id
                    }
                } label: {
                    header(for: entry)
                }
                .buttonStyle(.plain)
                .disabled(!entry.isAvailable)

                if expanded == entry.id, entry.isAvailable {
                    durationRow(for: entry.practice)
                }
            }
        }
        .opacity(entry.isAvailable ? 1 : 0.55)
    }

    private func header(for entry: PracticeEntry) -> some View {
        HStack(alignment: .top, spacing: KSSpacing.sm) {
            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text(entry.practice.title)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)

                Text(entry.practice.subtitle)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if let lock = entry.lockLabel {
                KSTag(text: lock, systemImage: "lock", state: .stillness)
            } else {
                KSTag(text: entry.practice.lengthLabel, systemImage: "timer", state: .stillness)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.isAvailable ? "Shows the lengths on offer" : "")
    }

    private func durationRow(for practice: Practice) -> some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text(practice.script.cues.first ?? "")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)

            HStack(spacing: KSSpacing.xs) {
                ForEach(practice.durationOptionsSeconds, id: \.self) { seconds in
                    Button {
                        onStart(practice, TimeInterval(seconds))
                    } label: {
                        Text(Practice.minutesLabel(seconds))
                            .ksFont(KSFont.label)
                            .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(KSColor.onAccent(.stillness))
                    .background(
                        KSColor.accent(.stillness),
                        in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                    )
                    .accessibilityLabel("Start \(practice.title), \(Practice.minutesLabel(seconds))")
                }
            }
        }
        .ksTransition(.opacity)
    }
}

/// The tradition selector.
///
/// What changes is stated plainly: vocabulary, the closing line, and the bell.
/// Never the mechanics of a practice, and the app is complete on the secular
/// default — this is an invitation, not a prerequisite.
struct TraditionPickerSheet: View {
    let selected: Tradition
    let onSelect: (Tradition) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            KSScreen(state: .stillness) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.sm) {
                        Text("Changes the words the app uses, the line it closes a sit with, and the bell. It never changes what a practice actually asks you to do.")
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                            .padding(.bottom, KSSpacing.xs)

                        ForEach(Tradition.allCases) { tradition in
                            row(for: tradition)
                        }
                    }
                    .padding(.vertical, KSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Framing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }

    private func row(for tradition: Tradition) -> some View {
        Button {
            KSHaptics.shared.fire(.selection)
            onSelect(tradition)
        } label: {
            KSCard {
                HStack(alignment: .top, spacing: KSSpacing.sm) {
                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text(tradition.displayName)
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)

                        Text(tradition.pickerDetail)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    if tradition == selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KSColor.accent(.stillness))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(tradition == selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Library") {
    NavigationStack {
        PracticeLibraryView(
            entries: PracticeCatalogue.all.map {
                PracticeEntry(practice: $0, isAvailable: $0.requiredCompletedSits == 0, sitsRemaining: $0.requiredCompletedSits)
            },
            tradition: .secular,
            calmStreak: 3,
            completedSits: 11,
            onStart: { _, _ in },
            onOpenReflection: {},
            onChangeTradition: { _ in }
        )
    }
}
