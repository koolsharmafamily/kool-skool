import Foundation

/// Rule-based, on-device, no network. The spec's adaptive suggestion is a v2
/// idea; this is the one rule worth having now because it is the whole reason
/// resistance gets logged in the first place.
enum TaskSuggestion {

    /// Resistance at or above this is treated as "you have been avoiding this".
    static let highResistance = 4

    /// Which mode to open the setup screen on.
    ///
    /// A task the user has already flagged as hard to start gets Just Start,
    /// whatever their default is. Offering someone a 52-minute deep work block
    /// for the thing they have been dodging for a week is how an app loses them.
    static func suggestedMode(for task: FocusTask?, settings: AppSettings) -> SessionMode {
        guard let resistance = task?.resistance else { return settings.defaultMode }
        return resistance.rawValue >= highResistance ? .justStart : settings.defaultMode
    }

    /// Shown under the mode picker when the suggestion overrode the default, so
    /// the app is never quietly deciding things on the user's behalf.
    static func reason(for task: FocusTask?, settings: AppSettings) -> String? {
        guard let task, let resistance = task.resistance else { return nil }
        guard resistance.rawValue >= highResistance else { return nil }
        guard settings.defaultMode != .justStart else { return nil }
        return "You marked this one hard to start, so this is set to five minutes."
    }

    /// Whether the Today card should nudge for a smaller first step.
    ///
    /// Only for tasks that actually look daunting — a long estimate or several
    /// steps. Asking "what is the smallest first step?" about "buy milk" is
    /// noise, and noise is what makes people stop reading prompts.
    static func needsSmallerFirstStep(_ task: FocusTask) -> Bool {
        guard task.nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if let estimate = task.estimateMinutes, estimate >= 45 { return true }
        return task.steps.filter { !$0.isDeleted }.count >= 3
    }
}
