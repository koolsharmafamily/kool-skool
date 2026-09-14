import SwiftUI

@main
struct KoolSkoolApp: App {
    @State private var appEnvironment = AppEnvironment.launch()

    init() {
        // Installed before any notification can arrive, so a session-end alert
        // never duplicates the completion screen that is already showing.
        NotificationPresenter.install()
    }

    /// Nil in normal use, so the app follows the system appearance. The UI
    /// tests set it to audit dark mode, the app's primary design.
    private var colorSchemeOverride: ColorScheme? {
        #if DEBUG
        return UITesting.forcesDark ? .dark : nil
        #else
        return nil
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                // The in-app Reduce Motion switch layers on top of the system
                // one; `ksReduceMotion` is the OR of the two.
                .ksReduceMotionOverride(appEnvironment.settings.reduceMotionOverride)
                .preferredColorScheme(colorSchemeOverride)
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
