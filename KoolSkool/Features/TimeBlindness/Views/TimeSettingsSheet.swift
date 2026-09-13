import SwiftUI

/// The time-blindness controls, on their own.
///
/// Milestone 10 builds the real Settings screen and this folds into it. It
/// exists now because every switch on it belongs to a Milestone 5 feature, and
/// a feature nobody can reach is a feature nobody can judge.
struct TimeSettingsSheet: View {
    let settings: AppSettings
    let calibration: EstimateCalibration
    let onChange: (@escaping (inout AppSettings) -> Void) -> Void
    let onClose: () -> Void

    @State private var isPickingTradition = false

    var body: some View {
        NavigationStack {
            KSScreen(state: .ready) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        discSection
                        timeCheckSection
                        calibrationSection
                        companySection
                        checkInSection
                        stillnessSection
                        medicationSection
                    }
                    .padding(.vertical, KSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .sheet(isPresented: $isPickingTradition) {
                TraditionPickerSheet(
                    selected: settings.tradition,
                    onSelect: { tradition in
                        onChange { $0.tradition = tradition }
                        isPickingTradition = false
                    },
                    onClose: { isPickingTradition = false }
                )
            }
        }
    }

    // MARK: Sections

    private var discSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Toggle(isOn: binding(\.showDigitalTimer)) {
                    Text("Show the countdown")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("The disc is the timer either way. Turn the digits off if watching a number tick down is worse than not knowing.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var timeCheckSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Toggle(isOn: binding(\.timeChecksEnabled)) {
                    Text("Time check pulses")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("A short buzz at a set interval. Off by default — some people find it grounding and some find it an interruption.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                if settings.timeChecksEnabled {
                    intervalPicker
                }
            }
        }
    }

    private var intervalPicker: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("Every \(settings.timeCheckIntervalMinutes) minutes")
                .ksFont(KSFont.label)
                .foregroundStyle(KSColor.textSecondary)

            HStack(spacing: KSSpacing.xs) {
                ForEach([5, 10, 15, 20], id: \.self) { minutes in
                    let isSelected = settings.timeCheckIntervalMinutes == minutes

                    Button {
                        KSHaptics.shared.fire(.selection)
                        onChange { $0.timeCheckIntervalMinutes = minutes }
                    } label: {
                        Text("\(minutes)")
                            .ksFont(KSFont.label)
                            .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
                    .background(
                        isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                    )
                    .accessibilityLabel("Every \(minutes) minutes")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var calibrationSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("Estimates")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                if let summary = calibration.summary {
                    Text(summary)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textSecondary)

                    Toggle(isOn: binding(\.autoPadEstimates)) {
                        Text("Pad new estimates to match")
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)
                    }
                } else {
                    Text("After \(EstimateCalibrator.minimumSamples) finished tasks with an estimate on them, this will tell you how far off they run. \(calibration.sampleCount) so far.")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }
        }
    }

    private var companySection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Company")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Toggle(isOn: binding(\.companionEnabled)) {
                    Text("Show the companion")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Toggle(isOn: binding(\.commitmentCardEnabled)) {
                    Text("Commitment card")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("Say what you are about to do, in a sentence, and see it again at the end. It replaces the intent field rather than adding to it.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                Toggle(isOn: binding(\.soundsEnabled)) {
                    Text("Sound")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("Soundscapes keep playing when the screen locks, which means they do not follow the silent switch. Turn them off here or from the session screen.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var checkInSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Check-ins")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Toggle(isOn: binding(\.postSessionCheckIn)) {
                    Text("\"How did that go?\" after a session")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Toggle(isOn: binding(\.preSessionCheckIn)) {
                    Text("Energy and mood before a session")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("Always skippable and never asked twice. The one after a session is what the Insights chart of how sessions felt is built on.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var stillnessSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Stillness")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Button {
                    isPickingTradition = true
                } label: {
                    HStack {
                        Text("Framing")
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)
                        Spacer()
                        Text(settings.tradition.displayName)
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(KSColor.textTertiary)
                    }
                    .frame(minHeight: KSSize.minimumTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Toggle(isOn: binding(\.offerBreakPractice)) {
                    Text("Offer a practice on breaks")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("After a session, one practice that fits the break. Always skippable in a tap.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                Toggle(isOn: binding(\.intervalBellsEnabled)) {
                    Text("Interval bells")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("A bell each minute during sits of five minutes or more. Sound Anchor rings either way — the bell is the practice.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
            }
        }
    }

    private var medicationSection: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Text("Medication")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Toggle(isOn: binding(\.medicationTrackingEnabled)) {
                    Text("Keep a medication log")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("Adds a one-tap line to Today and a daily reminder you can switch on. Stays on this device and is never sent anywhere.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                // The plain note the spec asks for, where medication tracking is
                // switched on rather than in a legal page nobody opens.
                Text("Kool Skool is not a medical device and does not give medical advice.")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textPrimary)
            }
        }
    }

    // MARK: Bits

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in onChange { $0[keyPath: keyPath] = newValue } }
        )
    }
}
