import SwiftUI

/// Social pressure without the social.
///
/// Saying what you are about to do, in a sentence, to something that will read
/// it back to you afterwards. It works for the same reason telling a colleague
/// works, minus the colleague.
///
/// It *replaces* the intent field rather than joining it. Both ask nearly the
/// same question, and the setup screen has ten seconds before people bounce.
struct CommitmentField: View {
    @Binding var text: String
    let minutes: Int
    var isCountUp: Bool = false

    @FocusState private var isFocused: Bool

    private var durationPhrase: String {
        isCountUp ? "for as long as it holds" : "for \(minutes) minutes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KSSpacing.xs) {
            Text("Say what you are doing")
                .ksFont(KSFont.label)
                .foregroundStyle(KSColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: KSSpacing.xxs) {
                Text("I'm going to")
                    .ksFont(KSFont.body)
                    .foregroundStyle(KSColor.textSecondary)

                TextField("read chapter three", text: $text, axis: .vertical)
                    .ksFont(KSFont.bodyEmphasis)
                    .foregroundStyle(KSColor.textPrimary)
                    .lineLimit(1...3)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { isFocused = false }
            }
            .padding(KSSpacing.sm)
            .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                    .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
            )

            Text("\(durationPhrase). You will see this again at the end.")
                .ksFont(KSFont.caption)
                .foregroundStyle(KSColor.textTertiary)
        }
        .accessibilityElement(children: .contain)
    }
}

/// The card read back once the session is over.
struct CommitmentRecap: View {
    let commitment: String
    let minutes: Int
    let kept: Bool

    private var sentence: String {
        "I'm going to \(commitment)."
    }

    var body: some View {
        KSCard {
            VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                Text("Before you started, you said")
                    .ksFont(KSFont.caption)
                    .foregroundStyle(KSColor.textSecondary)

                Text(sentence)
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)

                Text(verdict)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(kept ? KSColor.accent(.focusing) : KSColor.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Reports the time, not a judgement. Whether the thing itself got done is
    /// the task's question, asked separately and answered by the user.
    private var verdict: String {
        kept
            ? "You gave it \(minutes) minutes."
            : "You gave it \(minutes) minutes before stopping."
    }
}

#Preview("Commitment") {
    @Previewable @State var text = "read chapter three"

    return VStack(spacing: KSSpacing.lg) {
        CommitmentField(text: $text, minutes: 25)
        CommitmentRecap(commitment: "read chapter three", minutes: 25, kept: true)
    }
    .padding(KSSpacing.screenMargin)
    .frame(maxHeight: .infinity)
    .background(KSColor.canvas)
}
