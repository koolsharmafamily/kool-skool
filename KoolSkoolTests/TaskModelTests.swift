import Foundation
import Testing
@testable import KoolSkool

@MainActor
@Suite("Today screen")
struct TodayModelTests {

    private func makeStack() async throws -> (model: TodayModel, provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 15
        components.hour = 9

        let now = try #require(calendar.date(from: components))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let model = TodayModel(repositories: provider, clock: clock)
        return (model, provider, clock)
    }

    // MARK: Brain dump

    @Test("Each line of a brain dump becomes its own task")
    func captureSplitsByLine() async throws {
        let stack = try await makeStack()

        await stack.model.capture("""
        Read chapter three
        Email the supervisor
        Book the room
        """)

        let all = try await stack.provider.tasks.tasks(includeCompleted: false)
        #expect(all.count == 3)
        #expect(Set(all.map(\.title)) == ["Read chapter three", "Email the supervisor", "Book the room"])
    }

    @Test("Blank lines and stray whitespace are dropped")
    func captureIgnoresNoise() {
        let lines = TodayModel.splitCapture("  Alpha  \n\n   \n\tBeta\n")
        #expect(lines == ["Alpha", "Beta"])
    }

    @Test("An entirely empty dump creates nothing")
    func captureEmpty() async throws {
        let stack = try await makeStack()
        await stack.model.capture("   \n \n ")

        let all = try await stack.provider.tasks.tasks(includeCompleted: true)
        #expect(all.isEmpty)
        #expect(stack.model.error == nil)
    }

    // MARK: The rule of three

    @Test("Today holds three musts and offers a fourth slot to nobody")
    func threeMustsFillTheScreen() async throws {
        let stack = try await makeStack()
        await stack.model.capture("One\nTwo\nThree\nFour")
        await stack.model.load()

        for task in stack.model.candidates.prefix(3) {
            await stack.model.addMust(task)
        }

        #expect(stack.model.musts.count == 3)
        #expect(stack.model.remainingMustSlots == 0)
    }

    @Test("A fourth must is refused with a message, not an error")
    func fourthMustIsANotice() async throws {
        let stack = try await makeStack()
        await stack.model.capture("One\nTwo\nThree\nFour")
        await stack.model.load()

        for task in stack.model.candidates.prefix(3) {
            await stack.model.addMust(task)
        }

        let fourth = try #require(stack.model.candidates.first)
        await stack.model.addMust(fourth)

        // A cap being reached is information, not a failure.
        #expect(stack.model.notice != nil)
        #expect(stack.model.error == nil)
        #expect(stack.model.musts.count == 3)
    }

    @Test("Finishing a must frees its slot")
    func completingFreesASlot() async throws {
        let stack = try await makeStack()
        await stack.model.capture("One\nTwo\nThree\nFour")
        await stack.model.load()

        for task in stack.model.candidates.prefix(3) {
            await stack.model.addMust(task)
        }

        let first = try #require(stack.model.openMusts.first)
        await stack.model.toggleComplete(first)

        #expect(stack.model.openMusts.count == 2)
        #expect(stack.model.completedMusts.count == 1)
        #expect(stack.model.remainingMustSlots == 1)

        let fourth = try #require(stack.model.candidates.first)
        await stack.model.addMust(fourth)
        #expect(stack.model.notice == nil)
        #expect(stack.model.openMusts.count == 3)
    }

    @Test("Creating something new and pinning it happens in one step")
    func captureAsMust() async throws {
        let stack = try await makeStack()
        await stack.model.captureAsMust("Write the intro")

        #expect(stack.model.musts.count == 1)
        #expect(stack.model.musts.first?.title == "Write the intro")
    }

    @Test("A refused pin still keeps what was typed")
    func captureAsMustSurvivesTheCap() async throws {
        let stack = try await makeStack()
        await stack.model.capture("One\nTwo\nThree")
        await stack.model.load()
        for task in stack.model.candidates.prefix(3) {
            await stack.model.addMust(task)
        }

        await stack.model.captureAsMust("Fourth thing")

        // It did not make it onto Today, but it is not lost either.
        #expect(stack.model.notice != nil)
        #expect(stack.model.musts.count == 3)
        let all = try await stack.provider.tasks.tasks(includeCompleted: false)
        #expect(all.contains { $0.title == "Fourth thing" })
    }

    @Test("Musts belong to their own day")
    func mustsDoNotLeakAcrossDays() async throws {
        let stack = try await makeStack()
        await stack.model.captureAsMust("Today only")
        #expect(stack.model.musts.count == 1)

        // Tomorrow the slate is clear without anyone clearing it.
        stack.clock.advanceDays(1)
        await stack.model.load()
        #expect(stack.model.musts.isEmpty)
        #expect(stack.model.remainingMustSlots == TaskRules.mustLimit)
    }

    @Test("Removing a must leaves the task alone")
    func removingAMustKeepsTheTask() async throws {
        let stack = try await makeStack()
        await stack.model.captureAsMust("Still needed")

        let task = try #require(stack.model.musts.first)
        await stack.model.removeMust(task)

        #expect(stack.model.musts.isEmpty)
        #expect(stack.model.candidates.contains { $0.title == "Still needed" })
    }

    @Test("Setting a next tiny step changes what Today shows")
    func nextStepDrivesTheLabel() async throws {
        let stack = try await makeStack()
        await stack.model.captureAsMust("Write the dissertation")

        var task = try #require(stack.model.musts.first)
        #expect(task.startableLabel == "Write the dissertation")

        await stack.model.setNextStep("Open the outline file", for: task)
        task = try #require(stack.model.musts.first)
        #expect(task.startableLabel == "Open the outline file")
    }
}

@MainActor
@Suite("Task list and detail")
struct TaskListModelTests {

    private func makeStack() async throws -> (list: TaskListModel, provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        return (TaskListModel(repositories: provider, clock: clock), provider, clock)
    }

    @Test("The list separates today from the inbox")
    func sectionsSplitCorrectly() async throws {
        let stack = try await makeStack()
        await stack.list.capture("Pinned\nNot pinned")
        await stack.list.load()

        let pinned = try #require(stack.list.open.first { $0.title == "Pinned" })
        await stack.list.toggleMust(pinned)

        #expect(stack.list.musts.map(\.title) == ["Pinned"])
        #expect(stack.list.inbox.map(\.title) == ["Not pinned"])
    }

    @Test("Pinning toggles both ways")
    func toggleMustIsReversible() async throws {
        let stack = try await makeStack()
        await stack.list.capture("Thing")
        await stack.list.load()

        let task = try #require(stack.list.open.first)
        await stack.list.toggleMust(task)
        #expect(stack.list.musts.count == 1)

        let pinned = try #require(stack.list.musts.first)
        await stack.list.toggleMust(pinned)
        #expect(stack.list.musts.isEmpty)
        #expect(stack.list.inbox.count == 1)
    }

    @Test("Completing moves a task out of the open list")
    func completingMovesIt() async throws {
        let stack = try await makeStack()
        await stack.list.capture("Thing")
        await stack.list.load()

        let task = try #require(stack.list.open.first)
        await stack.list.toggleComplete(task)

        #expect(stack.list.open.isEmpty)
        #expect(stack.list.completed.count == 1)
    }

    @Test("Deleting removes it from every section")
    func deleteRemovesIt() async throws {
        let stack = try await makeStack()
        await stack.list.capture("Mistake")
        await stack.list.load()

        let task = try #require(stack.list.open.first)
        await stack.list.delete(task)

        #expect(stack.list.isEmpty)
    }

    @Test("A template replaces the steps in order")
    func templateAppliesInOrder() async throws {
        let stack = try await makeStack()
        let created = try await stack.provider.tasks.captureFromBrainDump("Essay")

        let detail = TaskDetailModel(task: created, repositories: stack.provider, clock: stack.clock)
        await detail.applyTemplate(.writing)

        #expect(detail.steps.map(\.title) == ["Read the brief", "Outline", "Draft", "Edit"])
        #expect(detail.notice != nil)
    }

    @Test("Steps can be added, ticked, and removed")
    func stepLifecycle() async throws {
        let stack = try await makeStack()
        let created = try await stack.provider.tasks.captureFromBrainDump("Essay")
        let detail = TaskDetailModel(task: created, repositories: stack.provider, clock: stack.clock)

        await detail.addStep("Outline")
        await detail.addStep("Draft")
        #expect(detail.steps.count == 2)
        #expect(detail.stepProgressLabel == "0 of 2 done")

        let first = try #require(detail.steps.first)
        await detail.toggleStep(first)
        #expect(detail.completedStepCount == 1)
        #expect(detail.stepProgressLabel == "1 of 2 done")

        let second = try #require(detail.steps.last)
        await detail.deleteStep(second)
        #expect(detail.steps.count == 1)
    }

    @Test("A blank step is not added")
    func blankStepIgnored() async throws {
        let stack = try await makeStack()
        let created = try await stack.provider.tasks.captureFromBrainDump("Essay")
        let detail = TaskDetailModel(task: created, repositories: stack.provider, clock: stack.clock)

        await detail.addStep("   ")
        #expect(detail.steps.isEmpty)
    }

    @Test("Editing a task writes the draft back")
    func draftSaves() async throws {
        let stack = try await makeStack()
        let created = try await stack.provider.tasks.captureFromBrainDump("Rough title")
        let detail = TaskDetailModel(task: created, repositories: stack.provider, clock: stack.clock)

        detail.draft.title = "Sharpened title"
        detail.draft.nextStep = "Open the doc"
        detail.draft.estimateMinutes = 60
        await detail.save()

        let stored = try #require(await stack.provider.tasks.task(id: created.id))
        #expect(stored.title == "Sharpened title")
        #expect(stored.nextStep == "Open the doc")
        #expect(stored.estimateMinutes == 60)
    }

    @Test("Deleting from the detail screen reports back")
    func detailDeleteSignals() async throws {
        let stack = try await makeStack()
        let created = try await stack.provider.tasks.captureFromBrainDump("Gone")
        let detail = TaskDetailModel(task: created, repositories: stack.provider, clock: stack.clock)

        await detail.delete()
        #expect(detail.wasDeleted)
    }
}

@Suite("Mode suggestion")
struct TaskSuggestionTests {

    private func task(resistance: Int?) -> FocusTask {
        var task = FocusTask()
        task.title = "Something"
        task.resistance = resistance.map { Rating(clamping: $0) }
        return task
    }

    @Test("A task nobody has rated uses the default mode")
    func unratedUsesDefault() {
        var settings = AppSettings()
        settings.defaultMode = .deepWork
        #expect(TaskSuggestion.suggestedMode(for: task(resistance: nil), settings: settings) == .deepWork)
        #expect(TaskSuggestion.suggestedMode(for: nil, settings: settings) == .deepWork)
    }

    @Test("A low-resistance task uses the default mode")
    func lowResistanceUsesDefault() {
        var settings = AppSettings()
        settings.defaultMode = .classicPomodoro
        #expect(TaskSuggestion.suggestedMode(for: task(resistance: 2), settings: settings) == .classicPomodoro)
    }

    @Test("A task you have been avoiding gets Just Start")
    func highResistanceGetsJustStart() {
        var settings = AppSettings()
        settings.defaultMode = .deepWork

        // Offering a 52-minute block for the thing being dodged is how an app
        // loses someone.
        #expect(TaskSuggestion.suggestedMode(for: task(resistance: 4), settings: settings) == .justStart)
        #expect(TaskSuggestion.suggestedMode(for: task(resistance: 5), settings: settings) == .justStart)
    }

    @Test("The override is explained rather than done silently")
    func overrideIsExplained() {
        var settings = AppSettings()
        settings.defaultMode = .deepWork
        #expect(TaskSuggestion.reason(for: task(resistance: 5), settings: settings) != nil)
        #expect(TaskSuggestion.reason(for: task(resistance: 1), settings: settings) == nil)

        // Nothing to explain when Just Start was already the default.
        settings.defaultMode = .justStart
        #expect(TaskSuggestion.reason(for: task(resistance: 5), settings: settings) == nil)
    }

    @Test("Only daunting tasks get nudged for a smaller first step")
    func nudgeIsSelective() {
        var small = FocusTask()
        small.title = "Buy milk"
        #expect(TaskSuggestion.needsSmallerFirstStep(small) == false)

        var long = FocusTask()
        long.title = "Write the dissertation"
        long.estimateMinutes = 120
        #expect(TaskSuggestion.needsSmallerFirstStep(long))

        // Already has one, so there is nothing to ask for.
        long.nextStep = "Open the outline"
        #expect(TaskSuggestion.needsSmallerFirstStep(long) == false)
    }

    @Test("A task with several steps counts as daunting")
    func manyStepsCountAsDaunting() {
        var task = FocusTask()
        task.title = "Essay"
        task.steps = (0..<3).map { index in
            TaskStep(taskID: task.id, title: "Step \(index)", order: index)
        }
        #expect(TaskSuggestion.needsSmallerFirstStep(task))
    }
}
