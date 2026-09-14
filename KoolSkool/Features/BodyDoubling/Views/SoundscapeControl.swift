import SwiftUI

/// The one audio control on the session screen: a single quiet button that
/// opens the picker, and nothing else competing with the disc.
struct SoundscapeControl: View {
    let controller: BodyDoublingController
    @State private var isPresentingPicker = false

    @Environment(\.ksEnergyState) private var energyState

    private var label: String {
        controller.currentSoundscape?.displayName ?? "Sound"
    }

    var body: some View {
        Button {
            isPresentingPicker = true
        } label: {
            HStack(spacing: KSSpacing.xxs) {
                Image(systemName: controller.isPlayingAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Text(label)
            }
            .ksFont(KSFont.label)
            // Secondary, not tertiary: the session screen's ambient wash warms
            // the background enough to push the quietest grey under 4.5:1.
            .foregroundStyle(controller.isPlayingAudio ? KSColor.accent(energyState) : KSColor.textSecondary)
            .padding(.horizontal, KSSpacing.sm)
            .frame(minHeight: KSSize.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(controller.isPlayingAudio ? "Sound: \(label). Change it." : "Sound off. Choose one.")
        .sheet(isPresented: $isPresentingPicker) {
            SoundscapePicker(controller: controller) { isPresentingPicker = false }
        }
    }
}

struct SoundscapePicker: View {
    let controller: BodyDoublingController
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            KSScreen(state: .focusing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.sm) {
                        silenceRow

                        ForEach(controller.availableSoundscapes) { soundscape in
                            row(soundscape)
                        }

                        if controller.availableSoundscapes.isEmpty {
                            emptyState
                        }

                        lockedNote

                        if let error = controller.audioError {
                            Text(error)
                                .ksFont(KSFont.caption)
                                .foregroundStyle(KSColor.accent(.overrun))
                        }
                    }
                    .padding(.vertical, KSSpacing.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .task { await controller.refreshCatalogue() }
        }
        .presentationDetents([.medium, .large])
    }

    private var silenceRow: some View {
        Button {
            controller.select(nil)
        } label: {
            rowLabel(
                title: "Silence",
                detail: "Nothing playing.",
                isSelected: controller.currentSoundscape == nil
            )
        }
        .buttonStyle(.plain)
    }

    private func row(_ soundscape: Soundscape) -> some View {
        Button {
            controller.select(soundscape)
        } label: {
            rowLabel(
                title: soundscape.displayName,
                detail: soundscape.detail,
                isSelected: controller.currentSoundscape?.key == soundscape.key
            )
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(title: String, detail: String, isSelected: Bool) -> some View {
        HStack(spacing: KSSpacing.sm) {
            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text(title)
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textPrimary)
                Text(detail)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(KSColor.accent(.focusing))
            }
        }
        .padding(KSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var emptyState: some View {
        Text("Nothing unlocked yet. Soundscapes arrive by level or from the collection.")
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textTertiary)
    }

    /// Straight about the two that need recordings nobody has made yet.
    private var lockedNote: some View {
        let pending = SoundscapeCatalogue.all.filter { !$0.isAvailable }
        return Group {
            if !pending.isEmpty {
                Text("\(pending.map(\.displayName).joined(separator: " and ")) need recorded audio and are not in this build.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textTertiary)
            }
        }
    }
}
