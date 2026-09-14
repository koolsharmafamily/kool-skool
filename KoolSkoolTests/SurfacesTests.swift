import Foundation
import Testing
import UserNotifications
@testable import KoolSkool

private func utcClock(hour: Int = 9) throws -> MutableDateProvider {
    let utc = try #require(TimeZone(identifier: "UTC"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: hour)))
    return MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
}

// MARK: - Deep links

@Suite("Deep links")
struct DeepLinkTests {

    @Test("Every link survives a round trip through its URL", arguments: DeepLink.allCases)
    func roundTrip(link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }

    @Test("Other schemes are ignored")
    func otherSchemes() throws {
        let url = try #require(URL(string: "https://just-start"))
        #expect(DeepLink(url: url) == nil)
    }

    @Test("Unknown destinations are ignored rather than guessed at")
    func unknownHost() throws {
        let url = try #require(URL(string: "koolskool://settings"))
        #expect(DeepLink(url: url) == nil)
    }

    @Test("Matching ignores case")
    func caseInsensitive() throws {
        let url = try #require(URL(string: "KoolSkool://Just-Start"))
        #expect(DeepLink(url: url) == .justStart)
    }
}

// MARK: - Widget snapshot

@Suite("Widget snapshot")
struct WidgetSnapshotTests {

    private func sample(clock: MutableDateProvider, session: WidgetSnapshot.Session? = nil) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: clock.now,
            day: clock.today,
            streak: 4,
            level: 3,
            musts: [WidgetSnapshot.Must(title: "Read chapter three", isDone: false)],
            session: session
        )
    }

    private func pomodoro(clock: MutableDateProvider) -> WidgetSnapshot.Session {
        WidgetSnapshot.Session(
            startedAt: clock.now,
            plannedEnd: clock.now.addingTimeInterval(25 * 60),
            modeName: "Pomodoro"
        )
    }

    @Test("Only these fields can ever reach a home screen")
    func keyAllowlist() throws {
        // Adding a field here is a privacy decision. Check-ins, medication and
        // reflections are health-adjacent and must never appear on a widget.
        let clock = try utcClock()
        let data = try JSONEncoder().encode(sample(clock: clock, session: pomodoro(clock: clock)))
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])

        let expectedTop: Set<String> = ["version", "generatedAt", "day", "streak", "level", "musts", "session"]
        #expect(Set(object.keys) == expectedTop)

        let session = try #require(object["session"] as? [String: Any])
        let expectedSession: Set<String> = ["startedAt", "plannedEnd", "modeName"]
        #expect(Set(session.keys) == expectedSession)

        let must = try #require((object["musts"] as? [[String: Any]])?.first)
        let expectedMust: Set<String> = ["title", "isDone"]
        #expect(Set(must.keys) == expectedMust)
    }

    @Test("A widget shows at most the rule of three")
    func mustsCapped() throws {
        let clock = try utcClock()
        let tasks = (1...5).map { index -> FocusTask in
            var task = FocusTask()
            task.title = "Task \(index)"
            return task
        }

        let snapshot = WidgetSnapshot.make(progress: UserProgress(), musts: tasks, session: nil, clock: clock)
        #expect(snapshot.musts.count == TaskRules.mustLimit)
    }

    @Test("A count-up session reaches the widget with no planned end")
    func countUp() throws {
        let clock = try utcClock()
        var session = FocusSession()
        session.mode = .flowmodoro
        session.plannedDuration = 0
        session.startedAt = clock.now

        let snapshot = WidgetSnapshot.make(progress: UserProgress(), musts: [], session: session, clock: clock)
        #expect(snapshot.session != nil)
        #expect(snapshot.session?.plannedEnd == nil)
    }

    @Test("The widget and the app agree on streak wording", arguments: [0, 1, 12])
    func streakWording(streak: Int) throws {
        let clock = try utcClock()
        var progress = UserProgress()
        progress.currentStreak = streak

        let snapshot = WidgetSnapshot.make(progress: progress, musts: [], session: nil, clock: clock)
        #expect(snapshot.streakLabel == progress.streakLabel)
    }

    @Test("Idle, then running, then time's up")
    func sessionStates() throws {
        let clock = try utcClock()
        let session = pomodoro(clock: clock)

        #expect(sample(clock: clock).sessionState(asOf: clock.now) == .idle)

        let running = sample(clock: clock, session: session)
        #expect(running.sessionState(asOf: clock.now.addingTimeInterval(60)) == .running(session))
        #expect(running.sessionState(asOf: clock.now.addingTimeInterval(25 * 60)) == .timeUp(session))
    }

    @Test("Yesterday's musts never show today")
    func staleMusts() throws {
        let clock = try utcClock()
        let snapshot = sample(clock: clock)

        #expect(snapshot.musts(asOf: clock.now, calendar: clock.calendar).count == 1)
        #expect(snapshot.musts(asOf: clock.now.addingTimeInterval(86_400), calendar: clock.calendar).isEmpty)
    }

    @Test("An unchanged picture is recognised whenever it was taken")
    func sameContent() throws {
        let clock = try utcClock()
        let first = sample(clock: clock)

        var later = first
        later.generatedAt = first.generatedAt.addingTimeInterval(300)
        #expect(later.hasSameContent(as: first))

        var changed = first
        changed.streak += 1
        #expect(changed.hasSameContent(as: first) == false)
        #expect(first.hasSameContent(as: nil) == false)
    }

    @Test("The store round-trips, and ignores a snapshot from another version")
    func storeRoundTrip() throws {
        let suite = "kool-skool.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let clock = try utcClock()
        let snapshot = sample(clock: clock)
        WidgetSnapshotStore.write(snapshot, to: defaults)
        #expect(WidgetSnapshotStore.read(from: defaults) == snapshot)

        var future = snapshot
        future.version = WidgetSnapshot.currentVersion + 1
        WidgetSnapshotStore.write(future, to: defaults)
        #expect(WidgetSnapshotStore.read(from: defaults) == nil)
    }

    @Test("Widgets redraw at the planned end and at midnight, and nowhere else")
    func timeline() throws {
        let clock = try utcClock()
        let session = pomodoro(clock: clock)
        let end = clock.now.addingTimeInterval(25 * 60)
        let midnight = clock.today.addingTimeInterval(86_400)

        let dates = WidgetTimeline.refreshDates(for: sample(clock: clock, session: session), now: clock.now, calendar: clock.calendar)
        #expect(dates == [clock.now, end, midnight])

        let afterEnd = WidgetTimeline.refreshDates(
            for: sample(clock: clock, session: session),
            now: end.addingTimeInterval(60),
            calendar: clock.calendar
        )
        #expect(afterEnd.contains(end) == false)
    }
}

// MARK: - Session end alerts

@Suite("Session end alerts")
struct SessionEndAlertTests {

    private func session(mode: SessionMode, planned: TimeInterval, start: Date) -> FocusSession {
        var session = FocusSession()
        session.mode = mode
        session.plannedDuration = planned
        session.startedAt = start
        return session
    }

    @Test("A count-down session gets one alert, at its planned end")
    func schedulesAtEnd() throws {
        let clock = try utcClock()
        let pomodoro = session(mode: .classicPomodoro, planned: 25 * 60, start: clock.now)

        let plan = try #require(SessionEndAlert.plan(for: pomodoro, now: clock.now))
        #expect(plan.fireDate == clock.now.addingTimeInterval(25 * 60))
        #expect(plan.identifier == SessionEndAlert.identifier(for: pomodoro.id))
        #expect(SessionEndAlert.isSessionEnd(plan.identifier))
    }

    @Test("Flowmodoro has no end to back up")
    func countUpSchedulesNothing() throws {
        let clock = try utcClock()
        let flow = session(mode: .flowmodoro, planned: 0, start: clock.now)
        #expect(SessionEndAlert.plan(for: flow, now: clock.now) == nil)
    }

    @Test("An end that has already passed is not scheduled")
    func pastEndSchedulesNothing() throws {
        let clock = try utcClock()
        let pomodoro = session(mode: .classicPomodoro, planned: 25 * 60, start: clock.now)
        #expect(SessionEndAlert.plan(for: pomodoro, now: clock.now.addingTimeInterval(30 * 60)) == nil)
    }

    @Test("The Lock Screen never says what you were working on")
    func discreet() throws {
        let clock = try utcClock()
        var pomodoro = session(mode: .classicPomodoro, planned: 25 * 60, start: clock.now)
        pomodoro.intent = "Tax return for Dr Okafor"
        pomodoro.commitment = "Finish the Okafor forms"

        let plan = try #require(SessionEndAlert.plan(for: pomodoro, now: clock.now))
        let visible = plan.title + " " + plan.body
        #expect(visible.contains("Okafor") == false)
        #expect(visible.contains("Tax") == false)
    }

    @Test("Clearing session alerts never touches the medication reminder")
    func sparesMedicationReminder() {
        #expect(SessionEndAlert.isSessionEnd(LocalMedicationReminderScheduler.identifier) == false)
    }

    @Test("A session alert arriving with the app open is swallowed; the reminder is not")
    func foregroundPresentation() {
        #expect(NotificationPresenter.foregroundOptions(for: SessionEndAlert.identifier(for: UUID())).isEmpty)
        #expect(NotificationPresenter.foregroundOptions(for: LocalMedicationReminderScheduler.identifier).isEmpty == false)
    }
}

// MARK: - Live Activity

@Suite("Live Activity content")
struct LiveActivityContentTests {

    @Test("The activity carries dates, not a countdown")
    func carriesDates() throws {
        let clock = try utcClock()
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.plannedDuration = 25 * 60
        session.startedAt = clock.now

        let content = FocusActivityContent.make(for: session, taskTitle: "  Outline chapter two  ")
        #expect(content.state.startedAt == clock.now)
        #expect(content.state.plannedEnd == clock.now.addingTimeInterval(25 * 60))
        #expect(content.staleDate == content.state.plannedEnd)
        #expect(content.attributes.sessionID == session.id)
        #expect(content.attributes.taskTitle == "Outline chapter two")
    }

    @Test("A count-up session has no end and never goes stale")
    func countUp() throws {
        let clock = try utcClock()
        var session = FocusSession()
        session.mode = .flowmodoro
        session.plannedDuration = 0
        session.startedAt = clock.now

        let content = FocusActivityContent.make(for: session, taskTitle: nil)
        #expect(content.state.plannedEnd == nil)
        #expect(content.state.countsUp)
        #expect(content.staleDate == nil)
    }

    @Test("A blank task title is left off rather than shown empty")
    func blankTitle() throws {
        let clock = try utcClock()
        var session = FocusSession()
        session.startedAt = clock.now
        #expect(FocusActivityContent.make(for: session, taskTitle: "   ").attributes.taskTitle == nil)
    }

    @Test("The timer range is never backwards, because a backwards range crashes")
    func rangeNeverBackwards() throws {
        let clock = try utcClock()
        let state = FocusActivityAttributes.ContentState(startedAt: clock.now, plannedEnd: clock.now.addingTimeInterval(-60))
        #expect(state.timerRange.lowerBound == state.timerRange.upperBound)
    }

    @Test("Relaunching a running session updates its activity instead of adding one")
    func reconcileSameSession() {
        let id = UUID()
        let plan = LiveActivityReconciler.plan(existing: [id], desired: id)
        #expect(plan.update == id)
        #expect(plan.request == false)
        #expect(plan.end.isEmpty)
    }

    @Test("A new session requests an activity and clears any left over")
    func reconcileNewSession() {
        let leftover = UUID()
        let current = UUID()
        let plan = LiveActivityReconciler.plan(existing: [leftover], desired: current)
        #expect(plan.update == nil)
        #expect(plan.request)
        #expect(plan.end == [leftover])
    }

    @Test("With nothing showing, one is requested")
    func reconcileEmpty() {
        let plan = LiveActivityReconciler.plan(existing: [], desired: UUID())
        #expect(plan.request)
        #expect(plan.end.isEmpty)
    }
}

// MARK: - Engine

@MainActor
@Suite("Engine and the Lock Screen")
struct EngineSurfaceTests {

    private struct Stack {
        let engine: FocusEngine
        let provider: SwiftDataRepositoryProvider
        let clock: MutableDateProvider
        let alerts: RecordingSessionAlertScheduler
        let activities: RecordingLiveActivityManager
    }

    private func makeStack(settings: AppSettings = AppSettings()) async throws -> Stack {
        let clock = try utcClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let alerts = RecordingSessionAlertScheduler()
        let activities = RecordingLiveActivityManager()

        let engine = FocusEngine(
            repositories: provider,
            clock: clock,
            haptics: NoOpHaptics(),
            alerts: alerts,
            idleGuard: NoOpScreenIdleGuard(),
            liveActivity: activities,
            ticksAutomatically: false
        )
        engine.apply(settings: settings)
        return Stack(engine: engine, provider: provider, clock: clock, alerts: alerts, activities: activities)
    }

    @Test("Starting a session puts it on the Lock Screen and arms the backstop")
    func startShowsActivity() async throws {
        let stack = try await makeStack()
        await stack.engine.start(SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60))

        let id = try #require(stack.engine.session?.id)
        #expect(stack.activities.started.count == 1)
        #expect(stack.activities.started.first?.attributes.sessionID == id)
        #expect(stack.alerts.scheduled == [id])
    }

    @Test("Ending early takes it off the Lock Screen and cancels the alert")
    func endEarlyRemovesActivity() async throws {
        let stack = try await makeStack()
        await stack.engine.start(SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60))
        let id = try #require(stack.engine.session?.id)

        stack.clock.advance(by: 60)
        await stack.engine.endEarly()

        #expect(stack.activities.ended == [id])
        #expect(stack.alerts.cancelCount >= 1)
    }

    @Test("A relaunch refreshes the same session's activity")
    func relaunchReusesSession() async throws {
        let stack = try await makeStack()
        await stack.engine.start(SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60))
        let id = try #require(stack.engine.session?.id)

        let relaunchedActivities = RecordingLiveActivityManager()
        let relaunched = FocusEngine(
            repositories: stack.provider,
            clock: stack.clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            liveActivity: relaunchedActivities,
            ticksAutomatically: false
        )
        stack.clock.advance(by: 5 * 60)
        await relaunched.restore()

        // Same session id, so the manager's reconciler updates rather than adds.
        #expect(relaunchedActivities.started.first?.attributes.sessionID == id)
    }

    @Test("Switching the alert off still leaves the Lock Screen timer running")
    func alertsOffActivityOn() async throws {
        var settings = AppSettings()
        settings.sessionEndAlertsEnabled = false
        let stack = try await makeStack(settings: settings)

        await stack.engine.start(SessionPlan(mode: .classicPomodoro, plannedDuration: 25 * 60))

        #expect(stack.alerts.scheduled.isEmpty)
        #expect(stack.activities.started.count == 1)
    }

    @Test("Session-end alerts are on unless switched off")
    func alertsDefaultOn() {
        #expect(AppSettings().sessionEndAlertsEnabled)
    }
}

// MARK: - Siri and Shortcuts

@MainActor
@Suite("Siri and Shortcuts")
struct IntentTests {

    @Test("Every session mode can be started from Siri", arguments: SessionMode.allCases)
    func everyMode(mode: SessionMode) {
        #expect(FocusModeOption(rawValue: mode.rawValue)?.sessionMode == mode)
    }

    private func makeEnvironment(widgets: RecordingWidgetPublisher = RecordingWidgetPublisher()) async throws -> (environment: AppEnvironment, provider: SwiftDataRepositoryProvider) {
        let clock = try utcClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

        let environment = AppEnvironment(
            repositories: provider,
            clock: clock,
            haptics: NoOpHaptics(),
            alerts: RecordingSessionAlertScheduler(),
            idleGuard: NoOpScreenIdleGuard(),
            reminders: RecordingReminderScheduler(),
            liveActivities: RecordingLiveActivityManager(),
            widgets: widgets
        )
        await environment.bootstrap()
        return (environment, provider)
    }

    @Test("A start that arrives mid-launch waits for launch, then runs")
    func queuedStart() async throws {
        let stack = try await makeEnvironment()
        let router = IntentRouter(fallbackRepositories: { stack.provider })

        let outcome = await router.startSession(mode: .justStart)
        #expect(outcome == .queued)
        #expect(stack.environment.focusEngine.status != .running)

        await router.attach(stack.environment)
        #expect(stack.environment.focusEngine.status == .running)
        #expect(stack.environment.focusEngine.session?.mode == .justStart)
        #expect(router.pendingStart == nil)
    }

    @Test("A second start while one is running is refused, not stacked")
    func alreadyRunning() async throws {
        let stack = try await makeEnvironment()
        let router = IntentRouter(fallbackRepositories: { stack.provider })
        await router.attach(stack.environment)

        #expect(await router.startSession(mode: .justStart) == .started)
        #expect(await router.startSession(mode: .deepWork) == .alreadyRunning)
    }

    @Test("A brain dump with the app closed still lands in the inbox")
    func captureWithoutApp() async throws {
        let clock = try utcClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let router = IntentRouter(fallbackRepositories: { provider })

        let count = try await router.capture("Email Sam\nBook the dentist")
        #expect(count == 2)

        let titles = try await provider.tasks.tasks(includeCompleted: true).map { $0.title }
        let expected: Set<String> = ["Email Sam", "Book the dentist"]
        #expect(Set(titles) == expected)
    }

    @Test("An empty brain dump writes nothing")
    func emptyCapture() async throws {
        let clock = try utcClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let router = IntentRouter(fallbackRepositories: { provider })

        #expect(try await router.capture("   \n  ") == 0)
        #expect(try await provider.tasks.tasks(includeCompleted: true).isEmpty)
    }

    @Test("Launch hands the widgets one picture, and does not resend an unchanged one")
    func widgetsPublishOnce() async throws {
        let widgets = RecordingWidgetPublisher()
        let stack = try await makeEnvironment(widgets: widgets)
        #expect(widgets.published.count == 1)

        await stack.environment.refreshWidgets()
        #expect(widgets.published.count == 1)
    }
}
