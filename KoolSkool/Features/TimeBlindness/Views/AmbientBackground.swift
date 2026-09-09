import SwiftUI

/// The session background, migrating from the focusing accent toward the
/// overrun accent as time runs out.
///
/// The point is that it costs nothing to read. It is never looked at directly —
/// it sits in peripheral vision and gets slowly warmer, so "time is nearly up"
/// arrives without anyone having to check anything.
struct AmbientBackground: View {
    /// 0 at the start of a session, 1 at its planned end.
    let progress: Double

    /// Faint enough at the start to be almost subliminal, unmistakable by the end.
    private var intensity: Double {
        0.06 + 0.32 * min(max(progress, 0), 1)
    }

    private var tint: Color {
        KSColor.blend(from: .focusing, to: .overrun, progress: progress)
    }

    var body: some View {
        ZStack {
            KSColor.canvas

            LinearGradient(
                colors: [tint.opacity(intensity), tint.opacity(intensity * 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .ksAnimation(KSAnimation.continuous, value: progress)
        .accessibilityHidden(true)
    }
}

#Preview("Ambient shift") {
    VStack(spacing: 0) {
        ForEach([0.0, 0.35, 0.7, 1.0], id: \.self) { value in
            ZStack {
                AmbientBackground(progress: value)
                Text("\(Int(value * 100))%")
                    .ksFont(KSFont.headline)
                    .foregroundStyle(KSColor.textPrimary)
            }
        }
    }
}
