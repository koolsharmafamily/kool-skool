import SwiftUI
import UIKit

/// One group of settings.
///
/// The cards that lived in the time-and-attention sheet since Milestone 5 are
/// here now, alongside durations, haptics, accessibility and about. Export has
/// its own screen, because it owns a model.
struct SettingsSectionView: View {
    let section: SettingsSection
    let settings: AppSettings
    let calibration: EstimateCalibration
    let notificationStatus: NotificationStatus
    let onChange: (@escaping (inout AppSettings) -> Void) -> Void
    let onRequestNotifications: () -> Void
    var onOpenMedication: () -> Void = {}

    @State private var isPickingTradition = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        KSScreen(state: section == .stillness ? .stillness : .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    cards
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var cards: some View {
        switch section {
        case .focus:
            defaultModeCard
            customDurationCard
            countdownCard
            timeCheckCard
            sessionScreenCard
            estimatesCard
        case .feel:
            soundCard
            hapticsCard
        case .notifications:
            notificationCard
        case .checkIns:
            checkInCard
            medicationCard
        case .stillness:
            stillnessCard
        case .accessibility:
            accessibilityCard
        case .data:
            // Routed to `DataExportScreen`, which owns its own model.
            EmptyView()
        case .about:
            aboutCards
        }
    }

    // MARK: Focus and time

    private var defaultModeCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                cardTitle("Setup opens on")

                ScrollView(.horizontal) {
                    HStack(spacing: KSSpacing.xs) {
                        ForEach(SessionMode.pickerOrder) { mode in
                            chip(mode.displayName, isSelected: settings.defaultMode == mode) {
                                onChange { $0.defaultMode = mode }
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)

                caption("The Just Start button on Today always starts Just Start. This is what the setup screen picks for you — except for a task you've marked hard to start, which still opens on Just Start.")
            }
        }
    }

    private var customDurationCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                cardTitle("Custom mode")

                Stepper(value: intBinding(\.customWorkMinutes), in: 5...180, step: 5) {
                    Text("Work for \(settings.customWorkMinutes) minutes")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Stepper(value: intBinding(\.customBreakMinutes), in: 0...60) {
                    Text(settings.customBreakMinutes == 0 ? "No break" : "Break for \(settings.customBreakMinutes) minutes")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                caption("Just Start, Pomodoro, Deep Work and Flowmodoro keep their own timings. These numbers are only for Custom.")
            }
        }
    }

    private var countdownCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                toggle("Show the countdown", \.showDigitalTimer)
                caption("The disc is the timer either way. Turn the digits off if watching a number tick down is worse than not knowing.")
            }
        }
    }

    private var timeCheckCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                toggle("Time check pulses", \.timeChecksEnabled)
                caption("A short buzz at a set interval. Off by default — some people find it grounding and some find it an interruption.")

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

    private var sessionScreenCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                cardTitle("During a session")

                toggle("Show the companion", \.companionEnabled)

                toggle("Commitment card", \.commitmentCardEnabled)
                caption("Say what you are about to do, in a sentence, and see it again at the end. It replaces the intent field rather than adding to it.")

                toggle("Keep the screen awake", \.keepScreenAwakeDuringSession)
                caption("Stops the phone dimming while a session is on screen. Uses a little more battery.")
            }
        }
    }

    private var estimatesCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                cardTitle("Estimates")

                if let summary = calibration.summary {
                    Text(summary)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textSecondary)

                    toggle("Pad new estimates to match", \.autoPadEstimates)
                } else {
                    caption("After \(EstimateCalibrator.minimumSamples) finished tasks with an estimate on them, this will tell you how far off they run. \(calibration.sampleCount) so far.")
                }
            }
        }
    }

    // MARK: Sound and haptics

    private var soundCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                toggle("Sound", \.soundsEnabled)
                caption("Soundscapes, the completion chime and stillness bells. Soundscapes keep playing when the screen locks, which means they do not follow the silent switch — this is the switch that does.")
            }
        }
    }

    private var hapticsCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                toggle("Haptics", \.hapticsEnabled)
                caption("The buzz when a session starts and ends, time check pulses, and the breath pacer's rhythm. Off here means off everywhere.")
            }
        }
    }

    // MARK: Notifications

    /// Shows what the system actually allows, not what the setting says. A
    /// switch that reads "on" while nothing can ever arrive would be a quiet lie.
    private var notificationCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                switch notificationStatus {
                case .authorised:
                    toggle("Tell me when a session ends", \.sessionEndAlertsEnabled)
                    caption("Only matters when the app isn't on screen at the time. The Lock Screen timer shows either way.")

                case .notDetermined:
                    caption("Kool Skool can tell you when a session ends while you're in another app. It's used for that and for the medication reminder, if you switch one on — nothing else.")
                    KSSecondaryButton(title: "Allow notifications", systemImage: "bell", action: onRequestNotifications)

                case .denied:
                    caption("Notifications are off for Kool Skool in iOS Settings, so a session that ends while you're elsewhere can't tell you. The Lock Screen timer still works.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .ksFont(KSFont.label)
                }
            }
        }
    }

    // MARK: Check-ins and medication

    private var checkInCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                cardTitle("Check-ins")
                toggle("\"How did that go?\" after a session", \.postSessionCheckIn)
                toggle("Energy and mood before a session", \.preSessionCheckIn)
                caption("Always skippable and never asked twice. The one after a session is what the Insights chart of how sessions felt is built on.")
            }
        }
    }

    private var medicationCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                cardTitle("Medication")
                toggle("Keep a medication log", \.medicationTrackingEnabled)
                caption("Adds a one-tap line to Today and a daily reminder you can switch on. Stays on this device and is never sent anywhere.")

                if settings.medicationTrackingEnabled {
                    KSSecondaryButton(title: "Open the log and reminder", systemImage: "list.bullet.rectangle", action: onOpenMedication)
                }

                // The plain note the spec asks for, where medication tracking is
                // switched on rather than in a legal page nobody opens.
                Text("Kool Skool is not a medical device and does not give medical advice.")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textPrimary)
            }
        }
    }

    // MARK: Stillness

    private var stillnessCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
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

                toggle("Offer a practice on breaks", \.offerBreakPractice)
                caption("After a session, one practice that fits the break. Always skippable in a tap.")

                toggle("Interval bells", \.intervalBellsEnabled)
                caption("A bell each minute during sits of five minutes or more. Sound Anchor rings either way — the bell is the practice.")
            }
        }
    }

    // MARK: Accessibility

    private var accessibilityCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                toggle("Reduce motion", \.reduceMotionOverride)
                caption("Swaps movement for quick fades throughout the app. If Reduce Motion is on in iOS, Kool Skool already follows it — this switch can only add to that, never undo it.")
                caption("Text follows the size you've set in iOS.")
            }
        }
    }

    // MARK: About

    private var aboutCards: some View {
        VStack(alignment: .leading, spacing: KSSpacing.lg) {
            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    cardTitle("Kool Skool")
                    caption("Version \(SettingsView.version)")
                }
            }

            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    cardTitle("Privacy")
                    paragraph("Everything you put into Kool Skool stays on this device. There's no account and no analytics, and the app makes no network requests.")
                    paragraph("Check-ins, the medication log and reflections are treated as health-adjacent: they're left out of exports unless you choose to include them.")
                }
            }

            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    cardTitle("Not medical advice")
                    paragraph("Kool Skool is not a medical device and does not give medical advice.")
                }
            }
        }
    }

    // MARK: Bits

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.headline)
            .foregroundStyle(KSColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.body)
            .foregroundStyle(KSColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ title: String, _ keyPath: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(isOn: binding(keyPath)) {
            Text(title)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            KSHaptics.shared.fire(.selection)
            action()
        } label: {
            Text(title)
                .ksFont(KSFont.label)
                .padding(.horizontal, KSSpacing.md)
                .frame(minHeight: KSSize.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
        .background(
            isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
            in: Capsule(style: .continuous)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in onChange { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in onChange { $0[keyPath: keyPath] = newValue } }
        )
    }
}
