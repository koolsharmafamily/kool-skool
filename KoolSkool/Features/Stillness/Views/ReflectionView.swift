import SwiftUI

/// The day's intention and its close.
///
/// Both halves are optional and neither is ever chased. The morning line is an
/// intention, not a task: nothing marks it done, nothing scores it, and it is
/// never mentioned again except to be shown back during a session.
struct ReflectionView: View {
    let model: ReflectionModel
    let tradition: Tradition

    @State private var intention = ""
    @State private var wentWell = ""
    @State private var wasHard = ""
    @State private var gratitude = ""
    @State private var hasLoaded = false

    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case intention, wentWell, wasHard, gratitude
    }

    var body: some View {
        KSScreen(state: .stillness) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    morningSection
                    eveningSection

                    if let error = model.lastError {
                        Text(error)
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.accent(.overrun))
                    }
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Today's reflection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { focused = nil }
            }
        }
        .task {
            guard !hasLoaded else { return }
            await model.load()
            seedFields()
            hasLoaded = true
        }
        // Saving on the way out as well as on submit, so a line typed and then
        // navigated away from is not lost.
        .onDisappear { save() }
    }

    // MARK: Sections

    private var morningSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Intention")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Text("One line about how you want today to go. Not a task — nothing will ever mark this done.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                TextField("Steady, not frantic", text: $intention, axis: .vertical)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...3)
                    .focused($focused, equals: .intention)
                    .onSubmit(save)
                    .padding(KSSpacing.sm)
                    .background(KSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                    .accessibilityLabel("Today's intention")
            }
        }
    }

    private var eveningSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Close the day")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Text("Thirty seconds, whenever you want it. Any of these can stay empty.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                field("What went well?", text: $wentWell, prompt: "Anything at all", field: .wentWell)
                field("What was hard?", text: $wasHard, prompt: "No need to solve it", field: .wasHard)
                field("One thing you're grateful for", text: $gratitude, prompt: "Small counts", field: .gratitude)

                Text(StillnessCopy.closing(tradition))
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
                    .padding(.top, KSSpacing.xxs)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
            Text(title)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)

            TextField(prompt, text: text, axis: .vertical)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
                .focused($focused, equals: field)
                .onSubmit(save)
                .padding(KSSpacing.sm)
                .background(KSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                .accessibilityLabel(title)
        }
    }

    // MARK: Persistence

    private func seedFields() {
        intention = model.today.morningIntention
        wentWell = model.today.eveningWentWell
        wasHard = model.today.eveningWasHard
        gratitude = model.today.gratitude
    }

    private func save() {
        Task {
            await model.setMorningIntention(intention)
            await model.setEvening(wentWell: wentWell, wasHard: wasHard, gratitude: gratitude)
        }
    }
}

/// The one line Today shows, and the tap that sets it.
///
/// Quiet by design: it sits under the musts rather than above them, because the
/// three things are still the point of that screen.
struct IntentionRow: View {
    let intention: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            KSCard {
                HStack(spacing: KSSpacing.sm) {
                    Image(systemName: intention.isEmpty ? "sunrise" : "quote.opening")
                        .foregroundStyle(KSColor.accent(.stillness))

                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text(intention.isEmpty ? "Set an intention" : intention)
                            .ksFont(KSFont.body)
                            .foregroundStyle(intention.isEmpty ? KSColor.textSecondary : KSColor.textPrimary)
                            .multilineTextAlignment(.leading)

                        if intention.isEmpty {
                            Text("One line. Optional.")
                                .ksFont(KSFont.caption)
                                .foregroundStyle(KSColor.textTertiary)
                        }
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
}

/// The way into the stillness layer from Today.
struct StillnessRow: View {
    let calmStreak: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            KSCard {
                HStack(spacing: KSSpacing.sm) {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(KSColor.accent(.stillness))

                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text("Stillness")
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)

                        Text(calmStreak > 0
                            ? "\(StillnessCopy.calmStreakLabel(calmStreak)) in a row"
                            : "A minute of breathing, whenever")
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
}
