import AppIntents

/// The session modes, as Siri and Shortcuts see them.
///
/// Its own type rather than `SessionMode` conforming to `AppEnum`, so the domain
/// layer stays free of App Intents. The raw values match, and a test holds them
/// together. Display strings are literals because the App Intents metadata
/// extractor reads them at build time and cannot evaluate a function call.
enum FocusModeOption: String, AppEnum {
    case justStart
    case classicPomodoro
    case deepWork
    case flowmodoro
    case custom

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Mode"

    static let caseDisplayRepresentations: [FocusModeOption: DisplayRepresentation] = [
        .justStart: "Just Start",
        .classicPomodoro: "Pomodoro",
        .deepWork: "Deep Work",
        .flowmodoro: "Flowmodoro",
        .custom: "Custom",
    ]

    var sessionMode: SessionMode {
        SessionMode(rawValue: rawValue) ?? .justStart
    }
}
