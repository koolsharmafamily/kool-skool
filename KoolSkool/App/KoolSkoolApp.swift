import SwiftUI

@main
struct KoolSkoolApp: App {
    @State private var appEnvironment = AppEnvironment.launch()

    init() {
        // Installed before any notification can arrive, so a session-end alert
        // never duplicates the completion screen that is already showing.
        NotificationPresenter.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                // The in-app Reduce Motion switch layers on top of the system
                // one; `ksReduceMotion` is the OR of the two.
                .ksReduceMotionOverride(appEnvironment.settings.reduceMotionOverride)
                .task {
                    #if DEBUG
                    if UITesting.isActive {
                        await appEnvironment.seedForUITesting()
                    }
                    #endif
                    await appEnvironment.bootstrap()
                    // Only now can an intent that arrived mid-launch safely start
                    // a session: bootstrap has recovered any running one.
                    await IntentRouter.shared.attach(appEnvironment)
                }
        }
    }
}
