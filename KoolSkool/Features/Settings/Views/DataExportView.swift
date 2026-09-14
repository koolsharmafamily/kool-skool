import SwiftUI

/// Owns one `DataExportModel` for the life of the pushed screen.
struct DataExportScreen: View {
    @State private var model: DataExportModel

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        _model = State(initialValue: DataExportModel(repositories: repositories, clock: clock))
    }

    var body: some View {
        DataExportView(model: model)
    }
}

/// Export: prepare a file, see what is in it, then choose where it goes.
///
/// Two steps rather than one, so the count of what is about to leave the app is
/// on screen before it does.
struct DataExportView: View {
    let model: DataExportModel

    var body: some View {
        KSScreen(state: .ready) {
            ScrollView {
                VStack(alignment: .leading, spacing: KSSpacing.lg) {
                    introCard
                    healthCard
                    result
                }
                .padding(.vertical, KSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Your data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Text("Export a copy")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Your tasks, sessions, sits, progress and settings, as a JSON file. You choose where it goes — Files, AirDrop, email. The app uploads nothing.")
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var healthCard: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xs) {
                Toggle(isOn: Binding(
                    get: { model.includeHealthAdjacent },
                    set: { model.setIncludeHealthAdjacent($0) }
                )) {
                    Text("Include check-ins, medication and reflections")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }

                Text("Off unless you switch it on. These are health-adjacent, so they only leave the app when you say so — and your medication reminder settings go with them.")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var result: some View {
        switch model.state {
        case .idle:
            KSPrimaryButton(title: "Prepare export", systemImage: "doc.badge.gearshape") {
                Task { await model.prepare() }
            }

        case .preparing:
            ProgressView("Preparing…")
                .frame(maxWidth: .infinity)

        case let .ready(url, summary):
            KSCard {
                VStack(alignment: .leading, spacing: KSSpacing.xs) {
                    Text("In the file")
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)

                    ForEach(summary) { line in
                        HStack {
                            Text(line.label)
                                .ksFont(KSFont.body)
                                .foregroundStyle(KSColor.textPrimary)
                            Spacer()
                            Text("\(line.count)")
                                .ksFont(KSFont.label)
                                .foregroundStyle(KSColor.textSecondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Text(url.lastPathComponent)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                }
            }

            ShareLink(item: url) {
                HStack(spacing: KSSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share the file")
                }
                .ksFont(KSFont.headline)
                .frame(maxWidth: .infinity, minHeight: KSSize.primaryButtonHeight)
            }
            .buttonStyle(KSPrimaryButtonStyle(state: .ready))

        case let .failed(message):
            Text("Couldn't prepare the export. \(message)")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.accent(.overrun))

            KSSecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                Task { await model.prepare() }
            }
        }
    }
}
