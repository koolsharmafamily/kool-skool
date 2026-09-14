import AppIntents

/// The phrases Siri knows without the user setting anything up.
struct KoolSkoolShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start a focus session in \(.applicationName)",
                "Just start in \(.applicationName)",
                "Start \(\.$mode) in \(.applicationName)",
            ],
            shortTitle: "Start a Session",
            systemImageName: "bolt.fill"
        )

        AppShortcut(
            intent: BrainDumpIntent(),
            phrases: [
                "Brain dump in \(.applicationName)",
                "Add to my \(.applicationName) inbox",
            ],
            shortTitle: "Brain Dump",
            systemImageName: "tray.and.arrow.down"
        )
    }
}
