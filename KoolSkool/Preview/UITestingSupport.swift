#if DEBUG
import Foundation

/// The launch arguments the UI tests pass, and the app they launch into.
///
/// Debug builds only. An install on a phone never sees any of this.
enum UITesting {
    static let flag = "-KSUITesting"
    static let onboardingFlag = "-KSUITestingOnboarding"
    static let reduceMotionFlag = "-KSUITestingReduceMotion"
    static let darkFlag = "-KSUITestingDark"

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isActive: Bool { arguments.contains(flag) }
    static var showsOnboarding: Bool { arguments.contains(onboardingFlag) }
    static var reducesMotion: Bool { arguments.contains(reduceMotionFlag) }
    static var forcesDark: Bool { arguments.contains(darkFlag) }
}

extension AppEnvironment {
    /// Memory-only and self-contained: no notifications, no Live Activity, no
    /// widget reloads, no haptics — nothing that reaches outside the app.
    static func uiTesting() -> AppEnvironment {
        guard let container = try? KoolSkoolSchema.makeContainer(inMemory: true) else {
            return .live()
        }
        return AppEnvironment(
            repositories: SwiftDataRepositoryProvider(container: container),
            haptics: NoOpHaptics(),
            alerts: NoOpSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            reminders: RecordingReminderScheduler(),
            liveActivities: NoOpLiveActivityManager(),
            widgets: NoOpWidgetPublisher()
        )
    }

    /// A plausible few weeks of use, so every screen the tests visit has
    /// something real on it — including enough history for Insights to speak.
    func seedForUITesting() async {
        let now = clock.now

        if var settings = try? await repositories.settings.settings() {
            settings.hasCompletedOnboarding = !UITesting.showsOnboarding
            settings.reduceMotionOverride = UITesting.reducesMotion
            settings.soundsEnabled = false
            _ = try? await repositories.settings.update(settings)
        }

        let titles = ["Revise chapter four", "Email the supervisor about the extension", "Book the dentist"]
        for (index, title) in titles.enumerated() {
            guard let task = try? await repositories.tasks.captureFromBrainDump(title) else { continue }
            if index < 2 {
                _ = try? await repositories.tasks.setMust(taskID: task.id, day: now)
            }
        }

        for daysAgo in 1...20 {
            var session = FocusSession()
            session.mode = daysAgo % 3 == 0 ? .deepWork : .classicPomodoro
            session.startedAt = now.addingTimeInterval(-Double(daysAgo) * 86_400 + Double(daysAgo % 5) * 3_600)
            session.plannedDuration = session.mode == .deepWork ? 52 * 60 : 25 * 60
            session.endedAt = session.startedAt.addingTimeInterval(session.plannedDuration)
            session.endReason = .reachedPlannedEnd
            session.wasCompleted = daysAgo % 4 != 0
            _ = try? await repositories.sessions.upsert(session)
        }
    }
}
#endif
