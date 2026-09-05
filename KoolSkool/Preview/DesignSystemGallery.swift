import SwiftUI

/// Every token in one scrollable place.
///
/// Worth opening in both appearances and at the largest Dynamic Type size
/// before any feature gets built on top of it — that is the cheapest moment to
/// discover the type scale breaks a layout.
struct DesignSystemGallery: View {
    @State private var previewState: KSEnergyState = .focusing
    @State private var shiftProgress: Double = 0.35

    var body: some View {
        KSScreen(state: previewState) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.xl) {
                    statePicker
                    ambientShift
                    typeScale
                    palette
                    components
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Design system")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var statePicker: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            sectionTitle("Energy states")

            Picker("Energy state", selection: $previewState) {
                ForEach(KSEnergyState.allCases) { state in
                    Text(state.accessibilityName).tag(state)
                }
            }
            .pickerStyle(.segmented)

            Text("The whole screen re-tints. Stillness is the deliberate step down — slower, quieter, lower contrast.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
    }

    private var ambientShift: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            sectionTitle("Ambient shift")

            RoundedRectangle(cornerRadius: KSRadius.lg, style: .continuous)
                .fill(KSColor.blend(from: .focusing, to: .overrun, progress: shiftProgress))
                .frame(height: 88)
                .overlay(
                    Text("\(Int(shiftProgress * 100))% elapsed")
                        .ksFont(KSFont.label)
                        .foregroundStyle(KSColor.onLight)
                )

            Slider(value: $shiftProgress, in: 0...1)
                .accessibilityLabel("Session progress")

            Text("During a session the background migrates from focusing toward overrun. Peripheral awareness of time, no reading required.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
    }

    private var typeScale: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            sectionTitle("Type scale")

            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("24:00").ksFont(KSFont.display)
                Text("1,240").ksFont(KSFont.displaySmall)
                Text("Today").ksFont(KSFont.title)
                Text("Three musts").ksFont(KSFont.headline)
                Text("Open the doc and read the first heading.").ksFont(KSFont.body)
                Text("Five minutes. Quit after if you want.").ksFont(KSFont.caption)
            }
            .foregroundStyle(KSColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            sectionTitle("Palette")

            ForEach(KSEnergyState.allCases) { state in
                HStack(spacing: KSSpacing.sm) {
                    RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous)
                        .fill(KSColor.accent(state))
                        .frame(width: 56, height: 44)
                        .overlay(
                            Text("Aa")
                                .ksFont(KSFont.label)
                                .foregroundStyle(KSColor.onAccent(state))
                        )

                    Text(state.accessibilityName)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)

                    Spacer()
                }
            }

            HStack(spacing: KSSpacing.sm) {
                surfaceSwatch("Canvas", KSColor.canvas)
                surfaceSwatch("Surface", KSColor.surface)
                surfaceSwatch("Raised", KSColor.surfaceRaised)
                surfaceSwatch("Track", KSColor.track)
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: KSSpacing.sm) {
            sectionTitle("Components")

            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    KSTag(text: "Day 12", systemImage: "flame.fill", state: .overrun)
                    Text("Finish the chapter summary")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)
                    Text("Open the doc and read the first heading")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                }
            }

            KSPrimaryButton(title: "Just start", systemImage: "bolt.fill") {}
            KSSecondaryButton(title: "End early") {}
        }
    }

    // MARK: Bits

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.headline)
            .foregroundStyle(KSColor.textPrimary)
    }

    private func surfaceSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: KSSpacing.xxs) {
            RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous)
                .fill(color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: KSRadius.sm, style: .continuous)
                        .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
                )
            Text(name)
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textSecondary)
        }
    }
}

#Preview("Gallery — dark") {
    NavigationStack { DesignSystemGallery() }
        .preferredColorScheme(.dark)
}

#Preview("Gallery — light") {
    NavigationStack { DesignSystemGallery() }
        .preferredColorScheme(.light)
}
