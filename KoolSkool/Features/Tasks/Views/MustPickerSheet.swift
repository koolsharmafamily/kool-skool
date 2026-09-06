import SwiftUI

/// Fills one of the three slots — either from what already exists or by typing
/// something new. Both paths in one sheet, because sending someone somewhere
/// else to create a task first is how a two-second decision becomes a detour.
struct MustPickerSheet: View {
    let candidates: [FocusTask]
    let remainingSlots: Int
    let onPick: (FocusTask) -> Void
    let onCreate: (String) -> Void
    let onCancel: () -> Void

    @State private var newTitle = ""
    @FocusState private var isFocused: Bool

    private var trimmedTitle: String {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            KSScreen(state: .ready) {
                ScrollView {
                    VStack(alignment: .leading, spacing: KSSpacing.lg) {
                        newTaskField

                        if candidates.isEmpty {
                            emptyState
                        } else {
                            candidateList
                        }
                    }
                    .padding(.vertical, KSSpacing.md)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(slotsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    private var newTaskField: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            TextField("Something new", text: $newTitle)
                .ksFont(KSFont.body)
                .foregroundStyle(KSColor.textPrimary)
                .focused($isFocused)
                .submitLabel(.done)
                .padding(KSSpacing.sm)
                .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                        .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
                )
                .onSubmit(create)

            KSPrimaryButton(
                title: "Add to today",
                systemImage: "plus",
                isEnabled: !trimmedTitle.isEmpty,
                action: create
            )
        }
    }

    private var candidateList: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("Or pick one you already have")
                .ksFont(KSFont.label)
                .foregroundStyle(KSColor.textSecondary)

            ForEach(candidates) { task in
                Button {
                    onPick(task)
                } label: {
                    HStack(spacing: KSSpacing.sm) {
                        VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                            Text(task.title)
                                .ksFont(KSFont.body)
                                .foregroundStyle(KSColor.textPrimary)
                                .multilineTextAlignment(.leading)

                            if !task.nextStep.isEmpty {
                                Text(task.nextStep)
                                    .ksFont(KSFont.caption)
                                    .foregroundStyle(KSColor.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(KSColor.accent(.ready))
                    }
                    .padding(KSSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget, alignment: .leading)
                    .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        Text("Nothing else waiting. Whatever you type above is the whole list.")
            .ksFont(KSFont.caption)
            .foregroundStyle(KSColor.textTertiary)
    }

    private var slotsTitle: String {
        remainingSlots == 1 ? "One slot left" : "\(remainingSlots) slots left"
    }

    private func create() {
        guard !trimmedTitle.isEmpty else { return }
        onCreate(trimmedTitle)
    }
}

#Preview("Picker") {
    var a = FocusTask()
    a.title = "Read chapter three"
    a.nextStep = "Open the PDF"

    var b = FocusTask()
    b.title = "Email the supervisor"

    return MustPickerSheet(
        candidates: [a, b],
        remainingSlots: 2,
        onPick: { _ in },
        onCreate: { _ in },
        onCancel: {}
    )
}
