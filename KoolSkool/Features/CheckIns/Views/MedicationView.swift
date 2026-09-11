import SwiftUI
import UIKit

/// The medication log in full: today's entry, an optional note, the reminder,
/// and the last month.
///
/// Every piece of text on this screen describes what the user recorded. None of
/// it describes the medication itself — the app knows nothing about what it is,
/// and that is the point.
struct MedicationView: View {
    let model: MedicationModel
    let settings: AppSettings
    let onChangeSettings: (@escaping (inout AppSettings) -> Void) -> Void

    @State private var note = ""
    @State private var reminderTime = Date()
    @FocusState private var noteFocused: Bool

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    todayCard
                    reminderCard
                    historySection
                    disclaimer
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Medication")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
            note = model.todaysLog?.note ?? ""
            reminderTime = Self.date(fromMinutes: settings.medicationReminderMinutes)
        }
    }

    // MARK: Today

    private var todayCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                KSPrimaryButton(
                    title: model.isLoggedToday ? "Logged today" : "Log it",
                    systemImage: model.isLoggedToday ? "checkmark" : "plus"
                ) {
                    Task {
                        await model.toggleToday(note: note)
                        note = model.todaysLog?.note ?? note
                    }
                }
                .ksEnergyState(model.isLoggedToday ? .focusing : .ready)

                Text(model.isLoggedToday ? "\(model.todaysLabel). Tap again to undo." : "One tap. Undo is the same button.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)

                if model.isLoggedToday {
                    TextField("Note — optional", text: $note, axis: .vertical)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                        .lineLimit(1...3)
                        .focused($noteFocused)
                        .submitLabel(.done)
                        .onSubmit(saveNote)
                        .padding(KSSpacing.sm)
                        .background(KSColor.surfaceRaised, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                }
            }
        }
    }

    // MARK: Reminder

    private var reminderCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.sm) {
                Toggle(isOn: reminderBinding) {
                    Text("Daily reminder")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                if settings.medicationReminderEnabled {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .ksFont(KSFont.body)
                        .onChange(of: reminderTime) { _, newValue in
                            let minutes = Self.minutes(from: newValue)
                            onChangeSettings { $0.medicationReminderMinutes = minutes }
                            Task { _ = await model.setReminder(enabled: true, minutesAfterMidnight: minutes) }
                        }
                }

                Text("The notification just says \"Your daily reminder\" — nothing about medication shows on the lock screen.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                if model.permissionDenied {
                    permissionNote
                }
            }
        }
    }

    private var permissionNote: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("Notifications are off for Kool Skool, so the reminder can't reach you.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.accent(.breakTime))

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .ksFont(KSFont.label)
        }
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        if !model.recent.isEmpty {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("Last 30 days")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.textSecondary)

                ForEach(model.recent) { log in
                    HStack(alignment: .top, spacing: KSSpacing.sm) {
                        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .ksFont(KSFont.body)
                                .foregroundStyle(KSColor.textPrimary)
                            if !log.note.isEmpty {
                                Text(log.note)
                                    .ksFont(KSFont.caption)
                                    .foregroundStyle(KSColor.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(KSSpacing.sm)
                    .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous))
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            Task { await model.delete(log) }
                        }
                    }
                }
            }
        }
    }

    /// The plain note the spec asks for. Short, unmissable, and not buried in a
    /// legal page nobody opens.
    private var disclaimer: some View {
        Text("Kool Skool is not a medical device and does not give medical advice. This is a log of what you record — it has no information about any medication and cannot tell you anything about one.")
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textTertiary)
    }

    // MARK: Bits

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { settings.medicationReminderEnabled },
            set: { newValue in
                let minutes = Self.minutes(from: reminderTime)
                Task {
                    let armed = await model.setReminder(enabled: newValue, minutesAfterMidnight: minutes)
                    // The toggle only stays on if the reminder is genuinely
                    // armed. A switch that says "on" while nothing will ever
                    // arrive is a quiet lie.
                    onChangeSettings {
                        $0.medicationReminderEnabled = armed
                        $0.medicationReminderMinutes = minutes
                    }
                }
            }
        )
    }

    private func saveNote() {
        noteFocused = false
        Task { await model.updateNote(note) }
    }

    static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 8) * 60 + (components.minute ?? 0)
    }

    static func date(fromMinutes minutes: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = minutes / 60
        components.minute = minutes % 60
        return Calendar.current.date(from: components) ?? Date()
    }
}
