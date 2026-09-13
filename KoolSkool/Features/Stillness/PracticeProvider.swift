import Foundation

/// Where practices come from.
///
/// v1 has exactly one implementation and it reads a constant. The protocol
/// exists because the eventual library — licensed courses, recorded guidance,
/// multi-week programs — arrives as a different implementation of this and
/// nothing else. Views and view models talk to the repository, which is seeded
/// from here, so neither changes when the source does.
protocol PracticeProvider: Sendable {
    func practices() async throws -> [Practice]
}

struct BundledPracticeProvider: PracticeProvider {
    init() {}

    func practices() async throws -> [Practice] { PracticeCatalogue.all }
}

/// A script split into the cues shown one at a time while a sit runs.
///
/// There is no recorded audio in v1 — see the note on `PracticeCatalogue` — so
/// guidance is text paced by the timer. Pure, so the pacing is testable without
/// a screen.
struct PracticeScript: Sendable, Equatable {
    var cues: [String]

    init(_ text: String) {
        cues = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var isEmpty: Bool { cues.isEmpty }

    /// Which cue is showing, given how far through the sit we are.
    ///
    /// Cues are spread evenly across the planned duration. Running over the
    /// planned end holds on the last cue rather than wrapping around.
    func index(elapsed: TimeInterval, duration: TimeInterval) -> Int {
        guard cues.count > 1, duration > 0 else { return 0 }
        let slice = duration / Double(cues.count)
        guard slice > 0 else { return 0 }
        let raw = Int(max(0, elapsed) / slice)
        return min(raw, cues.count - 1)
    }

    func cue(elapsed: TimeInterval, duration: TimeInterval) -> String? {
        guard !cues.isEmpty else { return nil }
        return cues[index(elapsed: elapsed, duration: duration)]
    }
}

/// The seven practices that ship.
///
/// ## Two content decisions worth knowing about
///
/// **Everything here is written for this app.** No line is attributed to anyone,
/// quotes no one, and paraphrases no named teacher's guidance.
/// `Practice.attribution` stays nil across the whole catalogue; it is rendered
/// wherever it is set, so genuine public-domain or licensed text can be added
/// later without touching a view.
///
/// **There is no bundled audio.** The spec asks for local audio and text
/// scripts; the text scripts are here, and `audioAssetName` is wired through to
/// the practice screen, but no recording is bundled because none exists and
/// synthesising a voice is off the table. Guidance is text cues paced by the
/// timer, plus the synthesised bell.
enum PracticeCatalogue {

    /// Stable identities, built from bytes rather than parsed from strings so
    /// there is no optional to unwrap and no way for a typo to silently produce
    /// a fresh id on every launch — which would duplicate the catalogue each
    /// time the app started.
    static func id(_ index: UInt8) -> UUID {
        UUID(uuid: (0xB0, 0x01, 0x5E, 0xED, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, index))
    }

    static var all: [Practice] {
        [boxBreathing, physiologicalSigh, bodyScan, walking, soundAnchor, movement, openAwareness]
    }

    static func practice(for type: PracticeType) -> Practice? {
        all.first { $0.type == type }
    }

    // MARK: Paced breath

    static let boxBreathing = Practice(
        id: Self.id(1),
        title: "Box Breathing",
        subtitle: "In four, hold four, out four, hold four",
        type: .boxBreathing,
        durationOptionsSeconds: [60, 120, 180],
        scriptText: """
        Follow the shape. It expands while you breathe in, holds, then shrinks while you breathe out.
        If four counts feels long, breathe shallower rather than faster.
        """
    )

    static let physiologicalSigh = Practice(
        id: Self.id(2),
        title: "Physiological Sigh",
        subtitle: "The fastest reset in the app",
        type: .physiologicalSigh,
        durationOptionsSeconds: [60],
        scriptText: """
        Two breaths in through the nose — a long one, then a short one on top of it.
        Then a long, slow breath out through the mouth. The out-breath is the part that does the work.
        """
    )

    // MARK: Timed and cued

    static let bodyScan = Practice(
        id: Self.id(3),
        title: "Body Scan",
        subtitle: "Attention moving through the body, one place at a time",
        type: .bodyScan,
        durationOptionsSeconds: [180, 300],
        scriptText: """
        Feet. Notice whatever is there — pressure, temperature, or nothing much.
        Lower legs, and the knees.
        Hips, and the seat underneath you.
        Belly. Let it move with the breath.
        Chest, and the upper back behind it.
        Hands. Fingers, palms, wrists.
        Arms and shoulders. Let the shoulders drop if they have not already.
        Neck, and the jaw. Unclench the jaw.
        Face, and the space behind the eyes.
        The whole body at once. Stay here a moment.
        """
    )

    static let walking = Practice(
        id: Self.id(4),
        title: "Walking",
        subtitle: "No sitting still required",
        type: .walking,
        durationOptionsSeconds: [180, 300, 600],
        scriptText: """
        Stand up and start walking, a little slower than usual.
        Count steps: one, two, three, four. Then start again at one.
        When you lose count — and you will — start again at one.
        Notice the moment each foot leaves the ground.
        And the moment it lands.
        If you have to turn around, notice the turn.
        Back to the count. One, two, three, four.
        Let the pace settle wherever it wants to settle.
        """
    )

    static let soundAnchor = Practice(
        id: Self.id(5),
        title: "Sound Anchor",
        subtitle: "A bell to come back to",
        type: .soundAnchor,
        durationOptionsSeconds: [120, 180, 300],
        scriptText: """
        Close your eyes, or let them go soft and unfocused.
        A bell will sound. Listen to it until you cannot hear it any more.
        In the quiet afterwards, listen for whatever else is there.
        Traffic, a fan, the room itself. Nothing you hear is a distraction here.
        When you notice you are thinking rather than listening, come back to the nearest sound.
        Another bell is on its way. Wait for it.
        """
    )

    static let movement = Practice(
        id: Self.id(6),
        title: "Movement",
        subtitle: "Shoulders, neck, spine — for a body that has been sitting",
        type: .movement,
        durationOptionsSeconds: [120, 180, 240],
        scriptText: """
        Roll your shoulders backwards, slowly. About five times.
        Now forwards, the same.
        Drop your right ear toward your right shoulder. Wait there.
        And the left side. Wait there too.
        Look slowly left, then slowly right.
        Interlace your fingers and push your palms up and away from you.
        Stand, reach up, then fold forward as far as is comfortable. No further.
        Roll back up slowly, one piece of the spine at a time.
        Shake out your hands. That is the whole thing.
        """
    )

    static let openAwareness = Practice(
        id: Self.id(7),
        title: "Open Awareness",
        subtitle: "Nothing to focus on",
        type: .openAwareness,
        durationOptionsSeconds: [300],
        scriptText: """
        No anchor this time. Sit, and let attention land wherever it lands.
        A sound, a feeling in the body, a thought. Notice it, then let it go without following it.
        You are not trying to empty anything out. Things arrive, and you let them pass.
        When you get pulled into a train of thought, notice that you were pulled, and come back to just sitting.
        That will happen repeatedly. It is supposed to.
        The rest of the time: here, with nothing to do.
        """,
        requiredCompletedSits: StillnessRules.openAwarenessSitsRequired
    )
}

extension Practice {
    var script: PracticeScript { PracticeScript(scriptText) }

    /// Whether the timer paces text cues rather than a breathing shape.
    var usesCues: Bool { !type.usesBreathPacer && !script.isEmpty }

    /// The sound anchor is the one practice whose bells are the practice
    /// itself, so it rings regardless of the interval-bell setting.
    var alwaysRingsIntervalBells: Bool { type == .soundAnchor }

    var durationOptions: [TimeInterval] {
        durationOptionsSeconds.map(TimeInterval.init)
    }

    static func minutesLabel(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) sec" }
        let minutes = seconds / 60
        return "\(minutes) min"
    }

    /// "1–3 min", or "1 min" when there is only one length on offer.
    var lengthLabel: String {
        guard let first = durationOptionsSeconds.first else { return "" }
        guard let last = durationOptionsSeconds.last, last != first else {
            return Self.minutesLabel(first)
        }
        if first >= 60, last >= 60 {
            return "\(first / 60)–\(last / 60) min"
        }
        return "\(Self.minutesLabel(first))–\(Self.minutesLabel(last))"
    }
}
