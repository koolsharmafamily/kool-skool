import Foundation

/// The numbers behind the stillness layer, collected where they can be argued
/// with.
enum StillnessRules {

    /// How often the sit model recomputes while a breath pacer is on screen.
    ///
    /// Faster than the focus timer's one second because a phase boundary that
    /// lands up to a second late is a pacer people stop trusting. Nothing
    /// accumulates across ticks, so the rate only affects how promptly a
    /// boundary is noticed.
    static let pacedTickInterval: TimeInterval = 0.1

    /// The tick rate for everything else — timed sits with no pacer.
    static let plainTickInterval: TimeInterval = 1

    /// Sits shorter than this are not recorded. Same reasoning as focus
    /// sessions: a mis-tap should not leave litter in the history.
    static let minimumRecordableDuration: TimeInterval = 10

    /// Completed sits required before open awareness appears in the library.
    static let openAwarenessSitsRequired = 20

    /// Interval bells are only offered on sits at least this long. A bell
    /// halfway through a sixty-second practice is just noise.
    static let intervalBellMinimumDuration: TimeInterval = 5 * 60

    /// Gap between interval bells during a long sit.
    static let intervalBellSpacing: TimeInterval = 60

    /// A sit is credited as completed once this much of it has run. Same
    /// eighty-percent rule the focus timer uses, for the same reason: stopping
    /// a three-minute practice at two minutes fifty is not a failure.
    static let completionThreshold: Double = 0.8

    /// How far back the calm streak walks. Two years, same ceiling as the focus
    /// streak.
    static let maximumLookbackDays = StreakCalculator.maximumLookbackDays
}

/// The words the stillness layer speaks in.
///
/// ## The content rule, and how this file obeys it
///
/// Every line here is written by and for this app. Nothing is attributed to any
/// real person, nothing is presented as a quotation, and nothing paraphrases a
/// named teacher's guidance. The tradition framings change vocabulary and tone
/// only — the app speaking plainly, in a register that suits the framing the
/// user picked.
///
/// Genuine quotations are a separate mechanism: `Practice.attribution`, which is
/// nil for everything bundled in v1 and is rendered next to the passage whenever
/// it is set. Verbatim public-domain text can be added there once it has been
/// checked against a real source.
enum StillnessCopy {

    /// What the app calls a sit under this framing.
    static func sitNoun(_ tradition: Tradition) -> String {
        switch tradition {
        case .secular: "Sit"
        case .buddhist: "Sit"
        case .yogic: "Practice"
        case .zen: "Sitting"
        case .stoic: "Pause"
        case .sufi: "Practice"
        case .christianContemplative: "Quiet"
        }
    }

    /// Shown once as the sit begins.
    static func settling(_ tradition: Tradition) -> String {
        switch tradition {
        case .secular:
            "Sit however you like. Feet on the floor is enough."
        case .buddhist:
            "Settle in and let the breath be exactly as it is. Nothing to fix."
        case .yogic:
            "Sit tall, shoulders down, jaw loose. Let the breath find its own length."
        case .zen:
            "Sit down. Face a blank wall if there is one. That is most of it."
        case .stoic:
            "A few minutes to see things plainly before going back to work."
        case .sufi:
            "Settle, and let the breath become a rhythm you can return to."
        case .christianContemplative:
            "Sit quietly. Nothing has to be achieved in the next few minutes."
        }
    }

    /// The most important line in the whole layer.
    ///
    /// Being told your wandering mind is a failure is the single most common
    /// reason people decide they cannot meditate. Every framing says the
    /// opposite, out loud, before the sit starts.
    static func wandering(_ tradition: Tradition) -> String {
        switch tradition {
        case .secular:
            "Your attention will wander. Noticing that and coming back is the practice — not a sign you are doing it wrong."
        case .buddhist:
            "The mind moves. Every time you notice it has wandered and come back, that is one repetition of the practice, not a failure of it."
        case .yogic:
            "A restless mind is the normal starting condition. The practice is returning, over and over, not staying."
        case .zen:
            "When you notice you have drifted, come back. That is the practice. Nothing else is being asked."
        case .stoic:
            "Thoughts arrive on their own; what you do next is the part that belongs to you. Notice, and come back."
        case .sufi:
            "Attention wanders and is brought back, again and again. The returning is the practice."
        case .christianContemplative:
            "When you notice your attention has gone, return gently. The gentleness is part of it."
        }
    }

    /// The short closing line after a sit. The app's own words, deliberately
    /// modest — an observation, not a teaching.
    static func closing(_ tradition: Tradition) -> String {
        switch tradition {
        case .secular:
            "That was a few minutes of doing one thing. Take it back with you."
        case .buddhist:
            "However that sit went, it has already changed. There is nothing to hold on to."
        case .yogic:
            "Steady, comfortable, unforced. That is the whole of it."
        case .zen:
            "Nothing special happened. That is fine."
        case .stoic:
            "Some of what is ahead is up to you and some of it is not. Spend yourself on the first kind."
        case .sufi:
            "Whatever you were carrying, you set it down for a few minutes. That counts."
        case .christianContemplative:
            "A few minutes of stillness, freely given. Nothing was required of you."
        }
    }

    /// Never "you broke your calm streak". Missing days simply do not appear.
    static func calmStreakLabel(_ streak: Int) -> String {
        switch streak {
        case 0: "No sits yet"
        case 1: "1 day"
        default: "\(streak) days"
        }
    }
}

extension Tradition {
    /// The bell's fundamental, in hertz.
    ///
    /// This is the "ambient sound palette" the tradition selector changes, done
    /// with the synthesiser that already exists rather than with audio files
    /// that do not. Lower is rounder and more bowl-like; higher is brighter and
    /// more like a struck bell.
    var bellFrequency: Double {
        switch self {
        case .secular: 528
        case .buddhist: 396
        case .yogic: 432
        case .zen: 352
        case .stoic: 480
        case .sufi: 440
        case .christianContemplative: 466
        }
    }

    /// One line under the name in the picker. Describes what changes in the
    /// app, not what the tradition teaches — the app is in no position to do
    /// the second and should not pretend otherwise.
    var pickerDetail: String {
        switch self {
        case .secular: "Plain language, no metaphysics."
        case .buddhist: "Vocabulary drawn from Buddhist and Vipassana practice."
        case .yogic: "Vocabulary drawn from yogic and Vedantic practice."
        case .zen: "Spare language. Very little spelled out."
        case .stoic: "Framed around what is and is not up to you."
        case .sufi: "Framed around rhythm and return."
        case .christianContemplative: "Quiet, unhurried, nothing required."
        }
    }
}
