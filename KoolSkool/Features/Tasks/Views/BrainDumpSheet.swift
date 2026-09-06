import SwiftUI

/// One giant text field and nothing else.
///
/// No title field, no project, no due date, no priority. Every one of those is a
/// reason to close the sheet without capturing anything. Each line becomes its
/// own task, because a brain dump is a list by nature.
struct BrainDumpSheet: View {
    let onCapture: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var lineCount: Int { TodayModel.splitCapture(text).count }
    private var canSave: Bool { lineCount > 0 }

    var body: some View {
        NavigationStack {
            KSScreen(state: .ready) {
                VStack(alignment: .leading, spacing: KSSpacing.sm) {
                    TextEditor(text: $text)
                        .ksFont(KSFont.headline)
                        .foregroundStyle(KSColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(KSSpacing.xs)
                        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.lg, style: .continuous))
                        .accessibilityLabel("Brain dump")
                        .accessibilityHint("Type anything on your mind. Each line becomes its own task.")

                    Text(hint)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)

                    KSPrimaryButton(title: saveTitle, systemImage: "tray.and.arrow.down.fill", isEnabled: canSave) {
                        onCapture(text)
                    }
                }
                .padding(.vertical, KSSpacing.md)
            }
            .navigationTitle("Brain dump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private var hint: String {
        text.isEmpty
            ? "Everything rattling around. One thing per line. Sorting it out is optional."
            : "One line, one task."
    }

    private var saveTitle: String {
        switch lineCount {
        case 0: "Capture"
        case 1: "Capture 1 thing"
        default: "Capture \(lineCount) things"
        }
    }
}

#Preview("Brain dump") {
    BrainDumpSheet(onCapture: { _ in }, onCancel: {})
}
