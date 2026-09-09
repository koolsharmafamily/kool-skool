import Foundation

/// Generates the noise beds one sample at a time.
///
/// Everything here runs on the audio render thread, which has a hard deadline
/// and must never allocate, lock, or call into Swift runtime machinery that
/// might. So: fixed-size state, a hand-rolled PRNG rather than
/// `Float.random(in:)` — which takes a lock on the system generator — and no
/// branching beyond a switch on an enum.
///
/// `@unchecked Sendable` is deliberate and narrow. After `start()`, only the
/// render thread reads the filter state. `amplitude` and `colour` are written
/// from the main actor while it runs; a torn read of either produces one
/// slightly wrong sample, which is inaudible and cannot corrupt anything.
final class NoiseSource: @unchecked Sendable {

    var colour: NoiseColour
    /// 0...1. Kept well below full scale — this is a bed, not a foreground.
    var amplitude: Float

    // Brown state
    private var brownLast: Float = 0

    // Pink state (Paul Kellet's economy filter)
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var b3: Float = 0
    private var b4: Float = 0
    private var b5: Float = 0
    private var b6: Float = 0

    // Rain state
    private var lowpass: Float = 0
    private var modulationPhase: Float = 0

    private var randomState: UInt32

    init(colour: NoiseColour = .brown, amplitude: Float = 0.28, seed: UInt32 = 0x9E37_79B9) {
        self.colour = colour
        self.amplitude = amplitude
        self.randomState = seed == 0 ? 1 : seed
    }

    /// Marsaglia xorshift32. Realtime-safe, and more than good enough for noise.
    private func white() -> Float {
        randomState ^= randomState << 13
        randomState ^= randomState >> 17
        randomState ^= randomState << 5
        // Map to -1...1 without a division on the hot path.
        return Float(Int32(bitPattern: randomState)) * (1.0 / 2_147_483_648.0)
    }

    func next() -> Float {
        let sample: Float

        switch colour {
        case .brown:
            let w = white()
            brownLast = (brownLast + 0.02 * w) / 1.02
            sample = brownLast * 3.5

        case .pink:
            let w = white()
            b0 = 0.99886 * b0 + w * 0.0555179
            b1 = 0.99332 * b1 + w * 0.0750759
            b2 = 0.96900 * b2 + w * 0.1538520
            b3 = 0.86650 * b3 + w * 0.3104856
            b4 = 0.55000 * b4 + w * 0.5329522
            b5 = -0.7616 * b5 - w * 0.0168980
            let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
            b6 = w * 0.115926
            sample = out * 0.11

        case .rain:
            // Noise with the rumble taken out, then breathed on slowly so it
            // does not sit as a flat hiss.
            let w = white()
            lowpass += 0.06 * (w - lowpass)
            let bright = w - lowpass

            modulationPhase += 0.000_012
            if modulationPhase >= 1 { modulationPhase -= 1 }
            let breath = 0.85 + 0.15 * sinf(modulationPhase * 2 * .pi)

            sample = bright * breath * 0.9
        }

        return clamp(sample * amplitude)
    }

    private func clamp(_ value: Float) -> Float {
        min(max(value, -1), 1)
    }

    /// Called when switching beds so the new one does not inherit the old one's
    /// filter state and click.
    func resetFilters() {
        brownLast = 0
        b0 = 0; b1 = 0; b2 = 0; b3 = 0; b4 = 0; b5 = 0; b6 = 0
        lowpass = 0
        modulationPhase = 0
    }
}
