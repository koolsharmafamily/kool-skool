import Foundation
import Testing
@testable import KoolSkool

@Suite("Breath pacer")
struct BreathPatternTests {

    @Test("Box breathing runs four equal phases")
    func boxPhases() {
        let pattern = BreathPattern.box
        #expect(pattern.cycleDuration == 16)
        #expect(pattern.steps.map(\.phase) == [.inhale, .holdFull, .exhale, .holdEmpty])
    }

    @Test(
        "Each second of a box cycle lands in the right phase",
        arguments: [
            (0.0, BreathPhase.inhale), (3.9, .inhale),
            (4.0, .holdFull), (7.9, .holdFull),
            (8.0, .exhale), (11.9, .exhale),
            (12.0, .holdEmpty), (15.9, .holdEmpty),
            (16.0, .inhale),
        ]
    )
    func boxBoundaries(elapsed: Double, expected: BreathPhase) {
        #expect(BreathPattern.box.tick(atElapsed: elapsed).phase == expected)
    }

    @Test("Fullness rises evenly through the inhale and holds through the hold")
    func fullness() {
        let pattern = BreathPattern.box

        #expect(pattern.tick(atElapsed: 0).fullness == 0)
        #expect(abs(pattern.tick(atElapsed: 2).fullness - 0.5) < 0.0001)
        #expect(pattern.tick(atElapsed: 4).fullness == 1)
        #expect(pattern.tick(atElapsed: 6).fullness == 1)
        #expect(abs(pattern.tick(atElapsed: 10).fullness - 0.5) < 0.0001)
        #expect(pattern.tick(atElapsed: 12).fullness == 0)
    }

    @Test("The shape is always told where it is heading and how long it has")
    func target() {
        // This is what the view animates to. Getting it wrong makes the shape
        // arrive at a different moment from the breath, which is the one thing
        // a pacer must not do.
        let inhale = BreathPattern.box.tick(atElapsed: 1)
        #expect(inhale.targetFullness == 1)
        #expect(inhale.stepDuration == 4)

        let exhale = BreathPattern.box.tick(atElapsed: 9)
        #expect(exhale.targetFullness == 0)
    }

    @Test("Cycles are counted, so a step key never repeats within a sit")
    func cycles() {
        let first = BreathPattern.box.tick(atElapsed: 1)
        let second = BreathPattern.box.tick(atElapsed: 17)

        #expect(first.phase == second.phase)
        #expect(first.cycleIndex == 0)
        #expect(second.cycleIndex == 1)
        #expect(first.stepKey != second.stepKey)
    }

    @Test("Twenty minutes of drift changes nothing, because nothing accumulates")
    func longElapsed() {
        let tick = BreathPattern.box.tick(atElapsed: 1200)
        #expect(tick.cycleIndex == 75)
        #expect(tick.phase == .inhale)
        #expect(tick.fullness == 0)
    }

    @Test("Counting starts at one, the way a person counts")
    func counting() {
        #expect(BreathPattern.box.tick(atElapsed: 0).countInStep == 1)
        #expect(BreathPattern.box.tick(atElapsed: 1.5).countInStep == 2)
        #expect(BreathPattern.box.tick(atElapsed: 3.9).countInStep == 4)
    }

    @Test("The sigh is two inhales and a longer exhale")
    func sigh() {
        let pattern = BreathPattern.physiologicalSigh
        #expect(pattern.steps.map(\.phase) == [.inhale, .topUp, .exhale, .holdEmpty])

        let inhales = pattern.steps.filter { $0.phase == .inhale || $0.phase == .topUp }
        let exhale = pattern.steps.first { $0.phase == .exhale }

        let intake = inhales.reduce(0) { $0 + $1.duration }
        // The long out-breath is the mechanism. If it stops being the longest
        // phase, this is not a physiological sigh any more.
        #expect((exhale?.duration ?? 0) > intake)
        #expect(pattern.tick(atElapsed: 2.5).phase == .topUp)
    }

    @Test("Only the breath practices are paced")
    func pacedOnly() {
        #expect(BreathPattern.forPractice(.boxBreathing) != nil)
        #expect(BreathPattern.forPractice(.physiologicalSigh) != nil)

        for type in [PracticeType.bodyScan, .walking, .soundAnchor, .movement, .openAwareness] {
            #expect(BreathPattern.forPractice(type) == nil)
        }
    }

    @Test("Every phase boundary gets a haptic, and the two holds get the softest")
    func haptics() {
        #expect(BreathPhase.inhale.haptic == .breathIn)
        #expect(BreathPhase.topUp.haptic == .breathIn)
        #expect(BreathPhase.exhale.haptic == .breathOut)
        #expect(BreathPhase.holdFull.haptic == .timeCheck)
        #expect(BreathPhase.holdEmpty.haptic == .timeCheck)
    }
}

@Suite("Practice catalogue")
struct PracticeCatalogueTests {

    @Test("Nothing in the catalogue is attributed to anybody")
    func nothingIsAttributed() {
        // The hard rule: guidance is never presented as coming from a named
        // real person. Everything bundled is the app's own words, so every
        // attribution is nil. Adding a real one is a deliberate act that has to
        // get past this test first, with verbatim checked text behind it.
        for practice in PracticeCatalogue.all {
            #expect(practice.attribution == nil, "\(practice.title) carries an attribution")
        }
    }

    /// Words that would mean the app is speaking for somebody else.
    ///
    /// Not an em dash: plenty of the app's own sentences use one, and it is the
    /// trailing "— Name" shape that matters, which the quote-mark check and the
    /// nil attributions already cover.
    static let attributionMarkers = ["said", "wrote", "teaches", "taught", "according to", "as the", "quote"]

    @Test("No script reads as a quotation")
    func nothingReadsAsAQuote() {
        for practice in PracticeCatalogue.all {
            let text = practice.scriptText.lowercased()
            for marker in Self.attributionMarkers {
                #expect(!text.contains(marker), "\(practice.title) contains \"\(marker)\"")
            }
            #expect(!practice.scriptText.contains("\""), "\(practice.title) contains quoted text")
        }
    }

    @Test("No tradition framing puts words in anyone's mouth")
    func framingsAreTheAppsOwnWords() {
        let markers = Self.attributionMarkers

        for tradition in Tradition.allCases {
            let lines = [
                StillnessCopy.settling(tradition),
                StillnessCopy.wandering(tradition),
                StillnessCopy.closing(tradition),
                tradition.pickerDetail,
            ]

            for line in lines {
                let lowered = line.lowercased()
                for marker in markers {
                    #expect(!lowered.contains(marker), "\(tradition.displayName) copy contains \"\(marker)\"")
                }
                #expect(!line.contains("\""), "\(tradition.displayName) copy is quoted")
            }
        }
    }

    @Test("Every framing says that a wandering mind is the practice, not a failure")
    func everyFramingForgivesWandering() {
        // The single most common reason people conclude they cannot meditate.
        // Every framing has to say the opposite out loud.
        for tradition in Tradition.allCases {
            let line = StillnessCopy.wandering(tradition).lowercased()
            #expect(line.contains("return") || line.contains("come back") || line.contains("back"))
        }
    }

    @Test("Every practice ships with a script and at least one length")
    func complete() {
        for practice in PracticeCatalogue.all {
            #expect(!practice.title.isEmpty)
            #expect(!practice.subtitle.isEmpty)
            #expect(!practice.scriptText.isEmpty)
            #expect(!practice.durationOptionsSeconds.isEmpty)
            #expect(practice.durationOptionsSeconds == practice.durationOptionsSeconds.sorted())
        }
    }

    @Test("Practice ids are stable across launches")
    func stableIdentity() {
        // Reseeding matches on id. If these were generated, every launch would
        // add another copy of the whole catalogue.
        #expect(PracticeCatalogue.all.map(\.id) == PracticeCatalogue.all.map(\.id))
        #expect(PracticeCatalogue.boxBreathing.id == PracticeCatalogue.id(1))
        #expect(Set(PracticeCatalogue.all.map(\.id)).count == PracticeCatalogue.all.count)
    }

    @Test("Only open awareness is gated, and only on sits")
    func gating() {
        for practice in PracticeCatalogue.all where practice.type != .openAwareness {
            #expect(practice.isAvailable(level: 1, completedSits: 0), "\(practice.title) is gated")
        }

        let advanced = PracticeCatalogue.openAwareness
        #expect(advanced.isAvailable(level: 99, completedSits: 19) == false)
        #expect(advanced.isAvailable(level: 1, completedSits: 20))
    }

    @Test("Cues are spread across the sit and hold on the last one")
    func cuePacing() {
        let script = PracticeScript("One\nTwo\nThree\nFour")

        #expect(script.cues.count == 4)
        #expect(script.index(elapsed: 0, duration: 200) == 0)
        #expect(script.index(elapsed: 60, duration: 200) == 1)
        #expect(script.index(elapsed: 199, duration: 200) == 3)
        // Running past the planned end holds rather than wrapping around.
        #expect(script.index(elapsed: 5_000, duration: 200) == 3)
    }

    @Test("Blank lines in a script do not become blank cues")
    func blankLines() {
        #expect(PracticeScript("One\n\n  \nTwo").cues == ["One", "Two"])
    }
}

@Suite("Calm streak")
struct CalmStreakTests {

    private func makeClock() throws -> MutableDateProvider {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 20)))
        return MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
    }

    private func days(_ offsets: [Int], from clock: MutableDateProvider) -> [Date] {
        offsets.map { clock.today.addingTimeInterval(TimeInterval($0) * 86_400) }
    }

    @Test("Consecutive sits build the streak")
    func consecutive() throws {
        let clock = try makeClock()
        let outcome = StreakCalculator.evaluate(
            completedDays: days([0, -1, -2], from: clock),
            today: clock.now,
            previousLongest: 0,
            clock: clock,
            freezeBudget: 0
        )

        #expect(outcome.current == 3)
    }

    @Test("A missed day is not rescued by a freeze")
    func noFreezes() throws {
        let clock = try makeClock()
        let outcome = StreakCalculator.evaluate(
            completedDays: days([0, -2, -3], from: clock),
            today: clock.now,
            previousLongest: 0,
            clock: clock,
            freezeBudget: 0
        )

        // The focus streak would bridge this. The calm streak does not, because
        // it has nothing to rescue: a day without a sit just does not appear.
        #expect(outcome.current == 1)
        #expect(outcome.frozenDays.isEmpty)
        #expect(outcome.freezesRemaining == 0)
    }

    @Test("A day with no sit yet is not held against anyone")
    func todayIsNotAFailure() throws {
        let clock = try makeClock()
        let outcome = StreakCalculator.evaluate(
            completedDays: days([-1, -2], from: clock),
            today: clock.now,
            previousLongest: 0,
            clock: clock,
            freezeBudget: 0
        )

        // Sat yesterday and the day before, nothing yet today. The day is not
        // over, so the streak stands at two.
        #expect(outcome.current == 2)
    }

    @Test("The longest calm streak survives a lapse")
    func longestSurvives() throws {
        let clock = try makeClock()
        var progress = UserProgress()
        progress.longestCalmStreak = 12

        let outcome = StreakCalculator.evaluate(
            completedDays: days([0], from: clock),
            today: clock.now,
            previousLongest: progress.longestCalmStreak,
            clock: clock,
            freezeBudget: 0
        )

        let updated = progress.applyingCalm(outcome)
        #expect(updated.calmStreak == 1)
        #expect(updated.longestCalmStreak == 12)
    }

    @Test("The calm streak never spends the focus streak's freezes")
    func doesNotTouchFreezes() throws {
        let clock = try makeClock()
        var progress = UserProgress()
        progress.freezesRemaining = 2
        progress.freezesUsedThisMonth = 0
        progress.currentStreak = 9

        let outcome = StreakCalculator.evaluate(
            completedDays: days([0, -5], from: clock),
            today: clock.now,
            previousLongest: 0,
            clock: clock,
            freezeBudget: 0
        )

        let updated = progress.applyingCalm(outcome)
        #expect(updated.freezesRemaining == 2)
        #expect(updated.freezesUsedThisMonth == 0)
        #expect(updated.currentStreak == 9)
    }

    @Test("Never phrased as a loss")
    func copyIsNotPunitive() {
        #expect(StillnessCopy.calmStreakLabel(0) == "No sits yet")
        #expect(StillnessCopy.calmStreakLabel(1) == "1 day")
        #expect(StillnessCopy.calmStreakLabel(9) == "9 days")
    }
}

@MainActor
@Suite("Sits")
struct StillnessModelTests {

    private struct Stack {
        var model: StillnessModel
        var provider: SwiftDataRepositoryProvider
        var clock: MutableDateProvider
        var haptics: NoOpHaptics
    }

    private func makeStack(settings: AppSettings = AppSettings()) async throws -> Stack {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        let haptics = NoOpHaptics()

        let model = StillnessModel(
            repositories: provider,
            clock: clock,
            haptics: haptics,
            ticksAutomatically: false
        )
        model.apply(settings: settings)
        await model.load()

        return Stack(model: model, provider: provider, clock: clock, haptics: haptics)
    }

    private func allSits(_ stack: Stack) async throws -> [StillnessSession] {
        try await stack.provider.stillness.recentSits(limit: 100)
    }

    @Test("The bundled catalogue is seeded once, not once per launch")
    func seedingIsIdempotent() async throws {
        let stack = try await makeStack()
        #expect(stack.model.practices.count == PracticeCatalogue.all.count)

        await stack.model.load()
        await stack.model.load()

        let stored = try await stack.provider.stillness.practices()
        #expect(stored.count == PracticeCatalogue.all.count)
    }

    @Test("Starting a sit writes nothing yet")
    func startWritesNothing() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 180)

        #expect(stack.model.isRunning)
        // Sits are recorded when they end. There is no open-sit state to recover.
        #expect(try await allSits(stack).isEmpty)
    }

    @Test("Running to the end records a completed sit")
    func completes() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 180)

        stack.clock.advance(by: 180)
        await stack.model.tick()

        let sits = try await allSits(stack)
        #expect(sits.count == 1)
        #expect(sits.first?.completed == true)
        #expect(sits.first?.durationSeconds == 180)
        #expect(sits.first?.practiceType == .boxBreathing)
        #expect(stack.model.isRunning == false)
        #expect(stack.model.lastFinished != nil)
    }

    @Test("Stopping near the end still counts")
    func eightyPercentCounts() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.bodyScan, duration: 180)

        stack.clock.advance(by: 150)
        await stack.model.end(reachedEnd: false)

        // Same mercy rule as the focus timer. Two and a half minutes of a
        // three-minute body scan is a body scan.
        #expect(try await allSits(stack).first?.completed == true)
    }

    @Test("Stopping early is recorded honestly, not as a completed sit")
    func earlyStopIsHonest() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.bodyScan, duration: 180)

        stack.clock.advance(by: 40)
        await stack.model.end(reachedEnd: false)

        let sits = try await allSits(stack)
        #expect(sits.count == 1)
        #expect(sits.first?.completed == false)
        #expect(stack.model.calmStreak == 0)
    }

    @Test("A mis-tap leaves no litter")
    func misTap() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.physiologicalSigh, duration: 60)

        stack.clock.advance(by: 3)
        await stack.model.end(reachedEnd: false)

        #expect(try await allSits(stack).isEmpty)
    }

    @Test("A plain break timer is not a sit and is never recorded")
    func plainBreakRecordsNothing() async throws {
        let stack = try await makeStack()
        stack.model.startPlainBreak(duration: 300)

        stack.clock.advance(by: 300)
        await stack.model.tick()

        // Counting a break as a sit would inflate the calm streak with minutes
        // nobody practised.
        #expect(try await allSits(stack).isEmpty)
        #expect(stack.model.calmStreak == 0)
    }

    @Test("A completed sit moves the calm streak")
    func calmStreakMoves() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 60)
        stack.clock.advance(by: 60)
        await stack.model.tick()

        #expect(stack.model.calmStreak == 1)
        #expect(stack.model.completedSits == 1)
    }

    @Test("The tradition in force is recorded on the sit, not looked up later")
    func traditionIsRecorded() async throws {
        var settings = AppSettings()
        settings.tradition = .zen
        let stack = try await makeStack(settings: settings)

        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 60)
        stack.clock.advance(by: 60)
        await stack.model.tick()

        // Switching framing later must not rewrite what already happened.
        #expect(try await allSits(stack).first?.tradition == .zen)
    }

    @Test("The pacer advances with the clock")
    func pacerAdvances() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 180)
        #expect(stack.model.breathTick?.phase == .inhale)

        stack.clock.advance(by: 5)
        await stack.model.tick()
        #expect(stack.model.breathTick?.phase == .holdFull)

        stack.clock.advance(by: 4)
        await stack.model.tick()
        #expect(stack.model.breathTick?.phase == .exhale)
    }

    @Test("A cued practice has no pacer")
    func cuedPracticeHasNoPacer() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.bodyScan, duration: 180)

        #expect(stack.model.breathTick == nil)
        #expect(stack.model.currentCue == PracticeCatalogue.bodyScan.script.cues.first)
    }

    @Test("One haptic per phase, never two")
    func onePulsePerPhase() async throws {
        let stack = try await makeStack()
        stack.model.start(practice: PracticeCatalogue.boxBreathing, duration: 180)

        // Four ticks inside the same phase.
        for _ in 0..<4 {
            stack.clock.advance(by: 0.5)
            await stack.model.tick()
        }

        let breathPulses = stack.haptics.fired.filter { $0 == .breathIn || $0 == .breathOut }
        #expect(breathPulses.count == 1)
    }

    @Test("Interval bells are off unless asked for")
    func bellsOffByDefault() {
        let run = StillnessRun(
            practice: PracticeCatalogue.bodyScan,
            plannedDuration: 600,
            startedAt: .now,
            intervalBellsEnabled: false
        )
        #expect(run.ringsIntervalBells == false)
        #expect(StillnessModel.bellsDue(elapsed: 300, run: run) == 0)
    }

    @Test("Interval bells are spaced by elapsed time, so they cannot drift")
    func bellSpacing() {
        let run = StillnessRun(
            practice: PracticeCatalogue.bodyScan,
            plannedDuration: 600,
            startedAt: .now,
            intervalBellsEnabled: true
        )

        #expect(StillnessModel.bellsDue(elapsed: 0, run: run) == 0)
        #expect(StillnessModel.bellsDue(elapsed: 59, run: run) == 0)
        #expect(StillnessModel.bellsDue(elapsed: 60, run: run) == 1)
        #expect(StillnessModel.bellsDue(elapsed: 305, run: run) == 5)
    }

    @Test("The sound anchor rings whatever the setting says")
    func soundAnchorAlwaysRings() {
        let run = StillnessRun(
            practice: PracticeCatalogue.soundAnchor,
            plannedDuration: 120,
            startedAt: .now,
            intervalBellsEnabled: false
        )
        // The bell is the practice. Silencing it would leave nothing to do.
        #expect(run.ringsIntervalBells)
    }

    @Test("A short sit never gets interval bells")
    func shortSitsAreQuiet() {
        let run = StillnessRun(
            practice: PracticeCatalogue.boxBreathing,
            plannedDuration: 60,
            startedAt: .now,
            intervalBellsEnabled: true
        )
        #expect(run.ringsIntervalBells == false)
    }
}

@MainActor
@Suite("Breaks")
struct BreakOfferTests {

    private func makeModel(settings: AppSettings = AppSettings()) async throws -> (model: StillnessModel, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

        let model = StillnessModel(
            repositories: provider,
            clock: clock,
            haptics: NoOpHaptics(),
            ticksAutomatically: false
        )
        model.apply(settings: settings)
        await model.load()
        return (model, clock)
    }

    private func finishedPomodoro(clock: MutableDateProvider) -> FocusSession {
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.plannedDuration = 25 * 60
        session.startedAt = clock.now.addingTimeInterval(-25 * 60)
        session.endedAt = clock.now
        session.wasCompleted = true
        session.endReason = .reachedPlannedEnd
        return session
    }

    @Test("A finished session offers its break")
    func offersBreak() async throws {
        let stack = try await makeModel()
        stack.model.offerBreak(after: finishedPomodoro(clock: stack.clock), settings: AppSettings())

        let offer = try #require(stack.model.breakOffer)
        #expect(offer.minutes == 5)
        #expect(offer.suggested != nil)
    }

    @Test("Nothing is offered when the setting is off")
    func respectsTheSetting() async throws {
        var settings = AppSettings()
        settings.offerBreakPractice = false
        let stack = try await makeModel(settings: settings)

        stack.model.offerBreak(after: finishedPomodoro(clock: stack.clock), settings: settings)
        #expect(stack.model.breakOffer == nil)
    }

    @Test("Just Start has no break, so nothing is offered")
    func noBreakNoOffer() async throws {
        let stack = try await makeModel()

        var session = FocusSession()
        session.mode = .justStart
        session.plannedDuration = 5 * 60
        session.startedAt = stack.clock.now.addingTimeInterval(-5 * 60)
        session.endedAt = stack.clock.now
        session.wasCompleted = true

        stack.model.offerBreak(after: session, settings: AppSettings())
        #expect(stack.model.breakOffer == nil)
    }

    @Test("The suggestion fits inside the break")
    func suggestionFits() async throws {
        let stack = try await makeModel()

        for breakLength in [60.0, 120.0, 300.0, 17 * 60.0] {
            let practice = try #require(stack.model.suggestedPractice(forBreakOf: breakLength))
            let duration = StillnessModel.bestDuration(of: practice, within: breakLength)
            #expect(duration <= breakLength, "\(practice.title) overran a \(breakLength)s break")
        }
    }

    @Test("A longer break gets a longer practice")
    func longerBreakLongerPractice() async throws {
        let stack = try await makeModel()

        let short = try #require(stack.model.suggestedPractice(forBreakOf: 60))
        let long = try #require(stack.model.suggestedPractice(forBreakOf: 300))

        #expect(StillnessModel.bestDuration(of: short, within: 60) <= StillnessModel.bestDuration(of: long, within: 300))
    }

    @Test("A locked practice is never suggested")
    func neverSuggestsLocked() async throws {
        let stack = try await makeModel()
        let suggestion = stack.model.suggestedPractice(forBreakOf: 17 * 60)

        // Open awareness needs twenty sits. A fresh user must not be handed it.
        #expect(suggestion?.type != .openAwareness)
    }

    @Test("Starting a break practice links it to the session it came from")
    func linksToSession() async throws {
        let stack = try await makeModel()
        let session = finishedPomodoro(clock: stack.clock)
        stack.model.offerBreak(after: session, settings: AppSettings())

        stack.model.start(
            practice: PracticeCatalogue.boxBreathing,
            duration: 180,
            focusSessionID: session.id,
            isBreak: true
        )

        #expect(stack.model.run?.focusSessionID == session.id)
        #expect(stack.model.run?.isBreak == true)
        // Starting clears the offer, so it cannot reappear behind the sit.
        #expect(stack.model.breakOffer == nil)
    }

    @Test("The library shows locked practices rather than hiding them")
    func libraryShowsLocked() async throws {
        let stack = try await makeModel()
        let entries = stack.model.libraryEntries(level: 1)

        #expect(entries.count == PracticeCatalogue.all.count)

        let advanced = try #require(entries.first { $0.practice.type == .openAwareness })
        #expect(advanced.isAvailable == false)
        #expect(advanced.lockLabel == "After 20 more sits")
    }
}

@MainActor
@Suite("Reflection")
struct ReflectionTests {

    private func makeModel() async throws -> (model: ReflectionModel, provider: SwiftDataRepositoryProvider, clock: MutableDateProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 7)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)
        return (ReflectionModel(repositories: provider, clock: clock), provider, clock)
    }

    @Test("The morning line and the evening close land in one row")
    func oneRowPerDay() async throws {
        let stack = try await makeModel()
        await stack.model.load()

        await stack.model.setMorningIntention("Steady, not frantic")
        stack.clock.advance(by: 14 * 3_600)
        await stack.model.setEvening(wentWell: "Finished the draft", wasHard: "Starting", gratitude: "Coffee")

        let day = stack.clock.today
        let stored = try await stack.provider.reflections.reflections(in: day..<day.addingTimeInterval(86_400))

        #expect(stored.count == 1)
        #expect(stored.first?.morningIntention == "Steady, not frantic")
        #expect(stored.first?.eveningWentWell == "Finished the draft")
        #expect(stored.first?.gratitude == "Coffee")
    }

    @Test("Writing the evening does not wipe the morning")
    func eveningKeepsMorning() async throws {
        let stack = try await makeModel()
        await stack.model.load()
        await stack.model.setMorningIntention("One thing at a time")
        await stack.model.setEvening(wentWell: "", wasHard: "", gratitude: "The dog")

        #expect(stack.model.today.morningIntention == "One thing at a time")
        #expect(stack.model.hasMorning)
        #expect(stack.model.hasEvening)
    }

    @Test("Saying nothing writes nothing")
    func emptyWritesNothing() async throws {
        let stack = try await makeModel()
        await stack.model.load()
        await stack.model.setMorningIntention("   ")
        await stack.model.setEvening(wentWell: "", wasHard: "", gratitude: "")

        let day = stack.clock.today
        let stored = try await stack.provider.reflections.reflections(in: day..<day.addingTimeInterval(86_400))
        #expect(stored.isEmpty)
    }

    @Test("Whitespace is trimmed off what is kept")
    func trims() async throws {
        let stack = try await makeModel()
        await stack.model.load()
        await stack.model.setMorningIntention("  Finish the chapter  ")

        #expect(stack.model.today.morningIntention == "Finish the chapter")
    }

    @Test("A new day starts blank")
    func newDayIsBlank() async throws {
        let stack = try await makeModel()
        await stack.model.load()
        await stack.model.setMorningIntention("Yesterday's line")

        stack.clock.advanceDays(1)
        await stack.model.load()

        #expect(stack.model.today.morningIntention.isEmpty)
        #expect(stack.model.recent.count == 1)
    }
}
