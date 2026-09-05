import SwiftUI

@main
struct KoolSkoolApp: App {
    @State private var appEnvironment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                // The in-app Reduce Motion switch layers on top of the system
                // one; `ksReduceMotion` is the OR of the two.
                .ksReduceMotionOverride(appEnvironment.settings.reduceMotionOverride)
                .task { await appEnvironment.bootstrap() }
        }
    }
}
