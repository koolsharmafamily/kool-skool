import SwiftUI

/// Hand-rolled confetti. No dependency, no particle engine — a few dozen
/// rectangles falling on staggered timings is indistinguishable at this size.
///
/// Renders nothing at all under Reduce Motion. Confetti is the one element in
/// the app with no informational value whatsoever, so when motion is unwelcome
/// it simply does not appear.
struct ConfettiView: View {
    var pieceCount: Int = 44

    @Environment(\.ksReduceMotion) private var reduceMotion
    @State private var phase: Double = 0
    @State private var pieces: [Piece] = []

    struct Piece: Identifiable {
        let id = UUID()
        var column: Double
        var delay: Double
        var spin: Double
        var drift: Double
        var width: Double
        var height: Double
        var state: KSEnergyState
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(KSColor.accent(piece.state))
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(piece.spin * phase))
                        .position(
                            x: proxy.size.width * piece.column + piece.drift * phase,
                            y: fall(piece, in: proxy.size.height)
                        )
                        .opacity(fade)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: start)
    }

    private func start() {
        guard !reduceMotion else { return }
        pieces = (0..<pieceCount).map { _ in
            Piece(
                column: Double.random(in: 0...1),
                delay: Double.random(in: 0...0.35),
                spin: Double.random(in: -540...540),
                drift: Double.random(in: -40...40),
                width: Double.random(in: 5...9),
                height: Double.random(in: 9...16),
                state: KSEnergyState.allCases.randomElement() ?? .focusing
            )
        }
        withAnimation(.easeIn(duration: 1.4)) { phase = 1 }
    }

    /// Each piece starts falling only once its own delay has passed, which is
    /// what stops it reading as a single sheet dropping.
    private func fall(_ piece: Piece, in height: Double) -> Double {
        let span = max(0.0001, 1 - piece.delay)
        let local = min(1, max(0, (phase - piece.delay) / span))
        return -24 + (height + 80) * local
    }

    private var fade: Double {
        phase > 0.85 ? max(0, (1 - phase) / 0.15) : 1
    }
}
