import AppIntents

/// "Brain dump."
///
/// Does not open the app. Getting a thought out of your head should not cost
/// you whatever you were in the middle of.
struct BrainDumpIntent: AppIntent {
    static let title: LocalizedStringResource = "Brain Dump"
    static let description = IntentDescription("Gets a thought out of your head and into your inbox without opening the app.")
    static let openAppWhenRun = false

    @Parameter(title: "Thought", requestValueDialog: "What's on your mind?")
    var text: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = try await IntentRouter.shared.capture(text)
        switch count {
        case 0:
            return .result(dialog: "Nothing to add.")
        case 1:
            return .result(dialog: "In your inbox.")
        default:
            return .result(dialog: "Added \(count) to your inbox.")
        }
    }
}
