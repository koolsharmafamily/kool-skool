import Foundation
import Testing
@testable import KoolSkool

private func onboardingClock() throws -> MutableDateProvider {
    let utc = try #require(TimeZone(identifier: "UTC"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
    return MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
}

@MainActor
@Suite("Onboarding")
struct OnboardingTests {

    private final class Harness {
        var settings = AppSettings()
        var started: [SessionPlan] = []
        var permissionRequests = 0
        var events: [String] = []
    }

    private struct Stack {
        let model: OnboardingModel
        let harness: Harness
        let provider: SwiftDataRepositoryProvider
        let clock: MutableDateProvider
    }

    private func makeStack(status: NotificationStatus = .notDetermined, grants: Bool = true) async throws -> Stack {
        let clock = try onboardingClock()
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let harness = Harness()

        let model = OnboardingModel(
            repositories: provider,
            clock: clock,
            initialSettings: AppSettings(),
            notificationStatus: status,
            applySettings: { mutate in
                mutate(&harness.settings)
                harness.events.append("settings")
            },
            requestNotifications: {
                harness.permissionRequests += 1
                return grants ? .authorised : .denied
            },
            startSession: { plan in
                harness.started.append(plan)
                harness.events.append("start")
            }
        )
        return Stack(model: model, harness: harness, provider: provider, clock: clock)
    }

    private func advanceToStart(_ model: OnboardingModel) {
        for _ in OnboardingModel.Step.allCases where model.step != .start {
            model.advance()
        }
    }

    @Test("Never more than four screens")
    func atMostFourScreens() async throws {
        let stack = try await makeStack()
        #expect(stack.model.stepCount <= OnboardingModel.maximumSteps)
        #expect(OnboardingModel.Step.allCases.count <= OnboardingModel.maximumSteps)
    }

    @Test("The quickest way into a session is four taps")
    func quickestPath() async throws {
        let stack = try await makeStack()
        var taps = 0

        stack.model.advance()
        taps += 1 // Skip the focus question
        stack.model.advance()
        taps += 1 // Skip when you work best
        stack.model.advance()
        taps += 1 // Not now, to notifications
        #expect(stack.model.step == .start)

        await stack.model.finish()
        taps += 1 // Just Start

        #expect(taps <= OnboardingModel.maximumSteps)
        #expect(stack.harness.started.count == 1)
    }

    @Test("The last screen starts a five-minute Just Start")
    func endsInJustStart() async throws {
        let stack = try await makeStack()
        advanceToStart(stack.model)
        await stack.model.finish()

        let plan = try #require(stack.harness.started.first)
        #expect(plan.mode == .justStart)
        #expect(plan.plannedDuration == SessionMode.justStart.defaultProfile.workDuration)
    }

    @Test("What you want to focus on becomes today's must, and the first session is on it")
    func focusBecomesMust() async throws {
        let stack = try await makeStack()
        stack.model.focusText = "  Revise chapter four  "
        advanceToStart(stack.model)
        await stack.model.finish()

        let musts = try await stack.provider.tasks.musts(on: stack.clock.now)
        let must = try #require(musts.first)
        #expect(musts.count == 1)
        #expect(must.title == "Revise chapter four")
        #expect(stack.harness.started.first?.taskID == must.id)
    }

    @Test("Skipping the focus question still starts a session, on nothing")
    func skippedFocus() async throws {
        let stack = try await makeStack()
        stack.model.focusText = "   "
        advanceToStart(stack.model)
        await stack.model.finish()

        #expect(stack.harness.started.first?.taskID == nil)
        #expect(try await stack.provider.tasks.tasks(includeCompleted: true).isEmpty)
    }

    @Test("Nothing asks for notification permission until the button is tapped")
    func permissionOnlyOnTap() async throws {
        let stack = try await makeStack()
        stack.model.advance()
        stack.model.advance()
        #expect(stack.model.step == .notifications)
        #expect(stack.harness.permissionRequests == 0)

        await stack.model.allowNotifications()
        #expect(stack.harness.permissionRequests == 1)
        #expect(stack.model.step == .start)
    }

    @Test("Refusing permission still moves on")
    func refusalMovesOn() async throws {
        let stack = try await makeStack(grants: false)
        stack.model.advance()
        stack.model.advance()
        await stack.model.allowNotifications()

        #expect(stack.model.step == .start)
    }

    @Test("Already answered the permission question? That screen is skipped", arguments: [NotificationStatus.authorised, .denied])
    func answeredPermissionSkipsScreen(status: NotificationStatus) async throws {
        let stack = try await makeStack(status: status)
        #expect(stack.model.steps.contains(.notifications) == false)
        #expect(stack.model.stepCount == 3)

        stack.model.advance()
        stack.model.advance()
        #expect(stack.model.step == .start)
    }

    @Test("Finishing marks onboarding done and keeps the answers")
    func keepsAnswers() async throws {
        let stack = try await makeStack()
        stack.model.preferredWorkTime = .evening
        stack.model.tradition = .stoic
        advanceToStart(stack.model)
        await stack.model.finish()

        #expect(stack.harness.settings.hasCompletedOnboarding)
        #expect(stack.harness.settings.preferredWorkTime == .evening)
        #expect(stack.harness.settings.tradition == .stoic)
    }

    @Test("Looking around first completes onboarding without a session")
    func lookAroundFirst() async throws {
        let stack = try await makeStack()
        advanceToStart(stack.model)
        await stack.model.finish(startingSession: false)

        #expect(stack.harness.started.isEmpty)
        #expect(stack.harness.settings.hasCompletedOnboarding)
    }

    @Test("The session starts before onboarding is marked done, so Today never flashes up")
    func sessionBeforeCompletion() async throws {
        let stack = try await makeStack()
        advanceToStart(stack.model)
        await stack.model.finish()

        #expect(stack.harness.events == ["start", "settings"])
    }

    @Test("Tapping Just Start twice starts one session")
    func finishOnce() async throws {
        let stack = try await makeStack()
        advanceToStart(stack.model)
        await stack.model.finish()
        await stack.model.finish()

        #expect(stack.harness.started.count == 1)
    }

    @Test("Back goes back, and never past the first screen")
    func back() async throws {
        let stack = try await makeStack()
        #expect(stack.model.canGoBack == false)

        stack.model.goBack()
        #expect(stack.model.step == .focus)

        stack.model.advance()
        #expect(stack.model.canGoBack)
        stack.model.goBack()
        #expect(stack.model.step == .focus)
    }

    @Test("The framing starts on the secular default and nothing has to be answered")
    func framingDefault() async throws {
        let stack = try await makeStack()
        #expect(stack.model.tradition == .secular)
        #expect(stack.model.preferredWorkTime == nil)
    }
}

@Suite("What you said, against what happened")
struct PreferenceSentenceTests {

    private func insight(_ block: TimeOfDay, pattern: Bool) -> TimeOfDayInsight {
        TimeOfDayInsight(block: block, lift: pattern ? 0.4 : 0.05, isPattern: pattern, sentence: "")
    }

    @Test("Says nothing without both an answer and an insight")
    func nothingToCompare() {
        #expect(InsightsCalculator.preferenceSentence(preferred: nil, insight: insight(.morning, pattern: true)) == nil)
        #expect(InsightsCalculator.preferenceSentence(preferred: .morning, insight: nil) == nil)
    }

    @Test("Agreement is said as agreement")
    func agreement() throws {
        let sentence = try #require(InsightsCalculator.preferenceSentence(preferred: .morning, insight: insight(.morning, pattern: true)))
        #expect(sentence.contains("agree"))
    }

    @Test("Disagreement names both, and blames neither")
    func disagreement() throws {
        let sentence = try #require(InsightsCalculator.preferenceSentence(preferred: .morning, insight: insight(.evening, pattern: true)))
        #expect(sentence.contains(TimeOfDay.morning.whenPhrase))
        #expect(sentence.contains(TimeOfDay.evening.whenPhrase))
    }

    @Test("No pattern is reported as no pattern")
    func noPattern() throws {
        let sentence = try #require(InsightsCalculator.preferenceSentence(preferred: .late, insight: insight(.morning, pattern: false)))
        #expect(sentence.contains("about as well"))
    }

    @Test("An observation, never advice", arguments: TimeOfDay.allCases)
    func neverAdvice(preferred: TimeOfDay) {
        for block in TimeOfDay.allCases {
            for pattern in [true, false] {
                let sentence = (InsightsCalculator.preferenceSentence(preferred: preferred, insight: insight(block, pattern: pattern)) ?? "").lowercased()
                for word in ["should", "try ", "consider", "recommend", "instead", "better"] {
                    #expect(sentence.contains(word) == false, "\"\(sentence)\" contains \"\(word)\"")
                }
            }
        }
    }
}
