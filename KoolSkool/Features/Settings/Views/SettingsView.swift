import SwiftUI

/// Settings, in groups, each with one line of its current state so most checks
/// need no tap at all.
struct SettingsView: View {
    let settings: AppSettings
    let notificationStatus: NotificationStatus
    let onOpen: (SettingsSection) -> Void

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.sm) {
                    ForEach(SettingsSection.allCases) { section in
                        row(section)
                    }

                    Text("Everything stays on this device. No account, no analytics, nothing sent anywhere.")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                        .padding(.top, KSSpacing.sm)
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private func row(_ section: SettingsSection) -> some View {
        Button {
            onOpen(section)
        } label: {
            KSCard {
                HStack(spacing: KSSpacing.sm) {
                    Image(systemName: section.systemImage)
                        .foregroundStyle(KSColor.accent(.ready))
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text(section.title)
                            .ksFont(KSFont.body)
                            .foregroundStyle(KSColor.textPrimary)
                        Text(Self.summary(for: section, settings: settings, notificationStatus: notificationStatus))
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(KSColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    static func summary(for section: SettingsSection, settings: AppSettings, notificationStatus: NotificationStatus) -> String {
        switch section {
        case .focus:
            return "Setup opens on \(settings.defaultMode.displayName)"
        case .feel:
            let sound = settings.soundsEnabled ? "Sound on" : "Sound off"
            let haptics = settings.hapticsEnabled ? "haptics on" : "haptics off"
            return "\(sound), \(haptics)"
        case .notifications:
            switch notificationStatus {
            case .authorised:
                return settings.sessionEndAlertsEnabled ? "Session-end alerts on" : "Session-end alerts off"
            case .notDetermined:
                return "Not set up yet"
            case .denied:
                return "Off in iOS Settings"
            }
        case .checkIns:
            return settings.medicationTrackingEnabled ? "Check-ins and the medication log" : "Check-ins"
        case .stillness:
            return "\(settings.tradition.displayName) framing"
        case .accessibility:
            return settings.reduceMotionOverride ? "Reduced motion on" : "Follows your iOS settings"
        case .data:
            return "Export a copy of everything"
        case .about:
            return "Version \(version) · privacy"
        }
    }

    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }
}
