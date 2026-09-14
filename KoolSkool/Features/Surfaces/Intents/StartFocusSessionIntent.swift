import AppIntents

/// "Start a focus session."
///
/// Opens the app, because a focus session is a whole-screen thing and a Live
/// Activity can only be started from the foreground.
struct StartFocusSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Focus Session"
    static let description = IntentDescription("Starts a session straight away. Just Start asks nothing and runs for five minutes.")
    static let openAppWhenRun = true

    @Parameter(title: "Mode", default: .justStart)
    var mode: FocusModeOption

    init() {}

    init(mode: FocusModeOption) {
        self.mode = mode
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch await IntentRouter.shared.startSession(mode: mode.sessionMode) {
        case .started, .queued:
            return .result(dialog: "Started. Go.")
        case .alreadyRunning:
            return .result(dialog: "A session is already running.")
        case .sitInProgress:
            return .result(dialog: "Finish the practice you're in, then start.")
        }
    }
}
