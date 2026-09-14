import SwiftUI

/// The one line medication gets on the Today screen, and only for people who
/// switched tracking on.
///
/// Quiet on purpose. Today is the rule-of-three screen, and a log that shouted
/// would be competing with the three things that matter.
struct MedicationRow: View {
    let model: MedicationModel
    let onOpen: () -> Void

    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 22

    var body: some View {
        HStack(spacing: KSSpacing.sm) {
            Button {
                Task { await model.toggleToday() }
            } label: {
                Image(systemName: model.isLoggedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(model.isLoggedToday ? KSColor.accent(.focusing) : KSColor.textTertiary)
                    .frame(width: max(KSSize.minimumTapTarget, iconSize + 22), height: max(KSSize.minimumTapTarget, iconSize + 22))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isLoggedToday ? "Medication logged. Tap to undo." : "Log medication for today")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Text("Medication")
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                    Text(model.todaysLabel)
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the medication log")

            Image(systemName: "chevron.right")
                .foregroundStyle(KSColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, KSSpacing.sm)
        .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
    }
}
