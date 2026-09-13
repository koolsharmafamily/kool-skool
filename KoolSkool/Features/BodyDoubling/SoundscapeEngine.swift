import AVFoundation
import Foundation

/// The one audio stack in the app.
///
/// The stillness layer's bells and interval chimes in Milestone 8 go through
/// this too — there is no second engine and no second session configuration.
///
/// ## The session category, and what it costs
///
/// The spec asks for three things: mix with other audio, respect the silent
/// switch, and keep playing in the background. On iOS you can have two of those.
/// `.ambient` mixes and respects the switch but stops the moment the app leaves
/// the foreground. `.playback` mixes (with the option) and survives backgrounding
/// but ignores the switch.
///
/// This picks `.playback` with `.mixWithOthers`. A focus timer whose bed cuts out
/// when the screen locks is broken in a way people notice within one session,
/// whereas the silent switch is usually flipped to stop notifications rather
/// than to stop deliberate media. The app provides its own off switch on the
/// session screen and in settings, which is the mute that actually gets used.
@MainActor
final class SoundscapeEngine {

    private let engine = AVAudioEngine()
    private let noise = NoiseSource()
    private var sourceNode: AVAudioSourceNode?
    private var filePlayer: AVAudioPlayerNode?
    private var chimePlayer: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?

    private var interruptionToken: (any NSObjectProtocol)?
    private var wasPlayingBeforeInterruption = false
    /// Interval bells ring the same note over and over, so the buffer is built
    /// once per frequency rather than once per ring.
    private var cachedBell: (frequency: Double, buffer: AVAudioPCMBuffer)?

    private(set) var current: Soundscape?
    private(set) var isPlaying = false
    private(set) var lastError: String?

    private let format: AVAudioFormat

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
            ?? AVAudioFormat()
        observeInterruptions()
    }

    deinit {
        if let interruptionToken {
            NotificationCenter.default.removeObserver(interruptionToken)
        }
    }

    // MARK: Playback

    func play(_ soundscape: Soundscape) {
        guard soundscape.isAvailable else {
            lastError = soundscape.unavailableReason
            return
        }

        stop(deactivateSession: false)
        current = soundscape

        do {
            try activateSession()
            try attachSource(for: soundscape)
            try engine.start()
            filePlayer?.play()
            isPlaying = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isPlaying = false
            current = nil
        }
    }

    func stop(deactivateSession: Bool = true) {
        filePlayer?.stop()
        if engine.isRunning { engine.stop() }
        detachSource()
        isPlaying = false
        current = nil

        guard deactivateSession else { return }
        // `.notifyOthersOnDeactivation` is what lets whatever was playing before
        // the session — a podcast, music — come back up on its own.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func setVolume(_ volume: Float) {
        noise.amplitude = min(max(volume, 0), 1) * 0.35
        engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
    }

    /// The completion sound the celebration has been missing.
    ///
    /// Built as a buffer rather than a bundled file so it needs no asset, and
    /// scheduled on its own player so it can land over a running bed.
    func playChime() {
        play(buffer: Self.makeStrikeBuffer(format: format, fundamental: 880, overtone: 1320, duration: 0.9, decay: 4.2))
    }

    /// The stillness bell: lower, longer, and with an inharmonic partial, which
    /// is most of what separates a struck bowl from a beep.
    ///
    /// Same engine, same session, same player as everything else — the spec is
    /// explicit that the stillness layer does not get a second audio stack.
    /// Cached because interval bells ring the same note repeatedly.
    func playBell(frequency: Double) {
        if cachedBell?.frequency != frequency {
            cachedBell = Self.makeStrikeBuffer(
                format: format,
                fundamental: frequency,
                overtone: frequency * 2.74,
                duration: 3.6,
                decay: 0.95
            )
            .map { (frequency: frequency, buffer: $0) }
        }

        play(buffer: cachedBell?.buffer)
    }

    private func play(buffer: AVAudioPCMBuffer?) {
        guard let buffer else { return }

        do {
            try activateSession()

            let player: AVAudioPlayerNode
            if let chimePlayer {
                player = chimePlayer
            } else {
                player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                chimePlayer = player
            }

            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            player.play()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Session

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    private func observeInterruptions() {
        interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return }

            let shouldResume = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false

            MainActor.assumeIsolated {
                self?.handleInterruption(type: type, shouldResume: shouldResume)
            }
        }
    }

    /// A phone call should pause the bed and hand it back afterwards, not end
    /// the session or leave silence behind.
    private func handleInterruption(type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                filePlayer?.pause()
                engine.pause()
                isPlaying = false
            }

        case .ended:
            guard wasPlayingBeforeInterruption, shouldResume, let current else { return }
            play(current)

        @unknown default:
            break
        }
    }

    // MARK: Graph

    private func attachSource(for soundscape: Soundscape) throws {
        switch soundscape.source {
        case let .synthesised(colour):
            noise.colour = colour
            noise.resetFilters()

            let node = AVAudioSourceNode(format: format) { [noise] _, _, frameCount, audioBufferList in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0..<Int(frameCount) {
                    let value = noise.next()
                    for buffer in buffers {
                        let samples = UnsafeMutableBufferPointer<Float>(buffer)
                        samples[frame] = value
                    }
                }
                return noErr
            }

            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNode = node

        case let .bundled(name, ext):
            guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
                throw SoundscapeError.missingAsset(name)
            }

            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

            // Looped by rescheduling on completion rather than by a gapless
            // buffer, which keeps memory flat for a long recording.
            scheduleLoop(player: player, file: file)

            filePlayer = player
            audioFile = file
        }
    }

    private func scheduleLoop(player: AVAudioPlayerNode, file: AVAudioFile) {
        player.scheduleFile(file, at: nil) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, let audioFile = self.audioFile else { return }
                self.scheduleLoop(player: player, file: audioFile)
            }
        }
    }

    private func detachSource() {
        if let sourceNode {
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        if let filePlayer {
            engine.detach(filePlayer)
            self.filePlayer = nil
        }
        audioFile = nil
    }

    // MARK: Struck tones

    /// Two overlapping partials with a quick attack and an exponential decay.
    /// About as close to something struck as arithmetic gets.
    ///
    /// A higher `decay` fades faster: the completion chime is gone in under a
    /// second, the stillness bell rings for several.
    private static func makeStrikeBuffer(
        format: AVAudioFormat,
        fundamental: Double,
        overtone: Double,
        duration: Double,
        decay: Double
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * duration)

        guard
            frames > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let channels = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.006)
            let envelope = Float(attack * exp(-t * decay))

            let value = Float(
                sin(2 * .pi * fundamental * t) * 0.6
                + sin(2 * .pi * overtone * t) * 0.25
            ) * envelope * 0.5

            for channel in 0..<Int(format.channelCount) {
                channels[channel][frame] = value
            }
        }

        return buffer
    }
}

enum SoundscapeError: LocalizedError {
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case let .missingAsset(name):
            "The audio for \(name) is not in this build yet."
        }
    }
}
