import Foundation
import Testing
@testable import KoolSkool

@Suite("Companion milestones")
struct CompanionMilestoneTests {

    @Test("Nothing has been reached at the start")
    func nothingAtZero() {
        #expect(CompanionMilestone.reached(at: 0) == nil)
        #expect(CompanionMilestone.reached(at: 0.24) == nil)
    }

    @Test("Each threshold reports the milestone just passed")
    func thresholds() {
        #expect(CompanionMilestone.reached(at: 0.25) == .quarter)
        #expect(CompanionMilestone.reached(at: 0.49) == .quarter)
        #expect(CompanionMilestone.reached(at: 0.5) == .half)
        #expect(CompanionMilestone.reached(at: 0.75) == .threeQuarters)
        #expect(CompanionMilestone.reached(at: 0.9) == .nearlyDone)
        #expect(CompanionMilestone.reached(at: 1) == .nearlyDone)
    }

    @Test("There are only four of them")
    func stayScarce() {
        // A companion that responds to everything is a pet demanding attention,
        // which is the opposite of what body doubling is for.
        #expect(CompanionMilestone.allCases.count == 4)
    }
}

@Suite("Companion skins")
struct CompanionSkinTests {

    @Test("Every skin has a distinct key and a symbol")
    func skinsAreWellFormed() {
        let keys = CompanionSkin.all.map(\.key)
        #expect(Set(keys).count == keys.count)
        #expect(CompanionSkin.all.allSatisfy { !$0.symbolName.isEmpty })
    }

    @Test("An unknown key falls back rather than showing nothing")
    func unknownKeyFallsBack() {
        #expect(CompanionSkin.named("companion.nonsense") == .default)
        #expect(CompanionSkin.named("companion.owl").displayName == "Owl")
    }

    @Test("Every skin in the catalogue has a matching collectable")
    func skinsMatchTheCatalogue() {
        let unlockableKeys = Set(
            UnlockableCatalogue.all
                .filter { $0.type == .companionSkin }
                .map(\.key)
        )
        for skin in CompanionSkin.all {
            #expect(unlockableKeys.contains(skin.key), "\(skin.key) has no collectable")
        }
    }
}

@Suite("Soundscape catalogue")
struct SoundscapeCatalogueTests {

    @Test("Generated beds are always playable")
    func synthesisedAlwaysAvailable() {
        let generated = SoundscapeCatalogue.all.filter {
            if case .synthesised = $0.source { return true }
            return false
        }
        #expect(generated.count == 3)
        #expect(generated.allSatisfy(\.isAvailable))
    }

    @Test("Recorded beds are honest about not being here yet")
    func bundledUnavailableWithoutAssets() {
        // No audio files ship in this build, so the recorded ones must report
        // themselves unavailable rather than failing silently at play time.
        let recorded = SoundscapeCatalogue.all.filter {
            if case .bundled = $0.source { return true }
            return false
        }
        #expect(recorded.isEmpty == false)
        #expect(recorded.allSatisfy { $0.isAvailable == false })
        #expect(recorded.allSatisfy { $0.unavailableReason != nil })
    }

    @Test("The picker only offers what is both owned and playable")
    func availabilityFiltersOnOwnership() {
        let owned: Set<String> = ["sound.brown", "sound.cafe"]
        let offered = SoundscapeCatalogue.available(ownedKeys: owned)

        #expect(offered.map(\.key) == ["sound.brown"])
    }

    @Test("Nothing owned means nothing offered")
    func emptyOwnership() {
        #expect(SoundscapeCatalogue.available(ownedKeys: []).isEmpty)
    }

    @Test("Every soundscape has a matching collectable")
    func soundscapesMatchTheCatalogue() {
        let unlockableKeys = Set(
            UnlockableCatalogue.all
                .filter { $0.type == .soundscape }
                .map(\.key)
        )
        for soundscape in SoundscapeCatalogue.all {
            #expect(unlockableKeys.contains(soundscape.key), "\(soundscape.key) has no collectable")
        }
    }

    @Test("Looking up by key handles nil and nonsense")
    func lookup() {
        #expect(SoundscapeCatalogue.named(nil) == nil)
        #expect(SoundscapeCatalogue.named("sound.nope") == nil)
        #expect(SoundscapeCatalogue.named("sound.pink")?.displayName == "Pink Noise")
    }
}

/// The render block runs on a realtime audio thread with a hard deadline. These
/// check the arithmetic, which is the part a device cannot tell you is wrong —
/// it just sounds bad.
@Suite("Noise generation")
struct NoiseSourceTests {

    private func samples(_ colour: NoiseColour, count: Int = 8_000, amplitude: Float = 1) -> [Float] {
        let source = NoiseSource(colour: colour, amplitude: amplitude)
        return (0..<count).map { _ in source.next() }
    }

    @Test("Every bed stays inside full scale", arguments: NoiseColour.allCases)
    func neverClips(colour: NoiseColour) {
        // Anything outside -1...1 is audible distortion, not noise.
        #expect(samples(colour).allSatisfy { $0 >= -1 && $0 <= 1 })
    }

    @Test("Every bed actually produces signal", arguments: NoiseColour.allCases)
    func producesSignal(colour: NoiseColour) {
        let values = samples(colour)
        let peak = values.map(abs).max() ?? 0
        #expect(peak > 0.001, "\(colour) generated silence")
    }

    @Test("Nothing is NaN or infinite", arguments: NoiseColour.allCases)
    func staysFinite(colour: NoiseColour) {
        #expect(samples(colour).allSatisfy(\.isFinite))
    }

    @Test("Brown noise has more low-frequency energy than pink")
    func brownIsHeavierThanPink() {
        // Brown noise wanders rather than jumping, so neighbouring samples are
        // more alike. Normalised by RMS so the comparison is about spectrum
        // rather than about which bed happens to be louder.
        func smoothness(_ values: [Float]) -> Float {
            guard values.count > 1 else { return 0 }

            var stepTotal: Float = 0
            var squareTotal: Float = 0
            for index in 1..<values.count {
                stepTotal += abs(values[index] - values[index - 1])
                squareTotal += values[index] * values[index]
            }

            let meanStep = stepTotal / Float(values.count - 1)
            let rms = (squareTotal / Float(values.count - 1)).squareRoot()
            return rms > 0 ? meanStep / rms : .greatestFiniteMagnitude
        }

        #expect(smoothness(samples(.brown)) < smoothness(samples(.pink)))
    }

    @Test("Amplitude scales the output")
    func amplitudeScales() {
        let quiet = samples(.brown, amplitude: 0.1).map(abs).max() ?? 0
        let loud = samples(.brown, amplitude: 1.0).map(abs).max() ?? 0
        #expect(loud > quiet)
    }

    @Test("Silence is achievable")
    func zeroAmplitudeIsSilent() {
        #expect(samples(.pink, amplitude: 0).allSatisfy { $0 == 0 })
    }

    @Test("The generator is deterministic for a given seed")
    func deterministic() {
        let first = NoiseSource(colour: .pink, seed: 12_345)
        let second = NoiseSource(colour: .pink, seed: 12_345)
        #expect((0..<500).allSatisfy { _ in first.next() == second.next() })
    }

    @Test("A zero seed does not lock the generator at silence")
    func zeroSeedIsHandled() {
        // xorshift stays at zero forever if it starts there.
        let source = NoiseSource(colour: .brown, seed: 0)
        let values = (0..<2_000).map { _ in source.next() }
        #expect((values.map(abs).max() ?? 0) > 0.001)
    }

    @Test("Resetting clears the filters so a switch does not click")
    func resetClearsState() {
        let source = NoiseSource(colour: .brown, seed: 999)
        for _ in 0..<5_000 { _ = source.next() }
        source.resetFilters()

        // Straight after a reset the integrator is empty, so the first sample is
        // small rather than picking up wherever the last bed left off.
        #expect(abs(source.next()) < 0.2)
    }
}

@MainActor
@Suite("Body doubling controller")
struct BodyDoublingControllerTests {

    private func makeController() async throws -> (controller: BodyDoublingController, provider: SwiftDataRepositoryProvider) {
        let utc = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 9)))
        let clock = MutableDateProvider(now: now, calendar: calendar, timeZone: utc)
        let provider = try await SwiftDataRepositoryProvider.inMemory(clock: clock)

        let controller = BodyDoublingController(repositories: provider)
        // Keeps AVAudioSession out of the unit tests. The audio path is
        // exercised on device; what is worth asserting here is the state machine.
        var settings = AppSettings()
        settings.soundsEnabled = false
        controller.settings = settings

        return (controller, provider)
    }

    private func session() -> FocusSession {
        var session = FocusSession()
        session.mode = .classicPomodoro
        session.plannedDuration = 25 * 60
        return session
    }

    @Test("A companion is present from the start")
    func alwaysHasCompany() async throws {
        let stack = try await makeController()
        await stack.controller.sessionDidStart(session())

        #expect(stack.controller.coworkers.count == 1)
        #expect(stack.controller.coworkers.first?.state == .working)
    }

    @Test("Milestones fire once each, in order")
    func milestonesFireOnce() async throws {
        let stack = try await makeController()
        await stack.controller.sessionDidStart(session())

        await stack.controller.sessionDidProgress(to: 0.1)
        #expect(stack.controller.milestoneCount == 0)

        await stack.controller.sessionDidProgress(to: 0.3)
        #expect(stack.controller.milestoneCount == 1)
        #expect(stack.controller.lastMilestone == .quarter)

        // Ticking repeatedly inside the same band must not keep firing.
        await stack.controller.sessionDidProgress(to: 0.35)
        await stack.controller.sessionDidProgress(to: 0.4)
        #expect(stack.controller.milestoneCount == 1)

        await stack.controller.sessionDidProgress(to: 0.55)
        #expect(stack.controller.milestoneCount == 2)
        #expect(stack.controller.lastMilestone == .half)
    }

    @Test("Jumping several bands at once counts as one reaction")
    func skippingBandsDoesNotStack() async throws {
        let stack = try await makeController()
        await stack.controller.sessionDidStart(session())

        // Backgrounded through most of the session.
        await stack.controller.sessionDidProgress(to: 0.95)
        #expect(stack.controller.milestoneCount == 1)
        #expect(stack.controller.lastMilestone == .nearlyDone)
    }

    @Test("Finishing changes what the companion is doing")
    func endStates() async throws {
        let stack = try await makeController()
        await stack.controller.sessionDidStart(session())

        await stack.controller.sessionDidEnd(session(), completed: true)
        #expect(stack.controller.coworkers.first?.state == .justFinished)

        await stack.controller.sessionDidStart(session())
        await stack.controller.sessionDidEnd(session(), completed: false)
        #expect(stack.controller.coworkers.first?.state == .onBreak)
    }

    @Test("Resetting returns the companion to waiting")
    func resetReturnsToArriving() async throws {
        let stack = try await makeController()
        await stack.controller.sessionDidStart(session())
        await stack.controller.reset()

        #expect(stack.controller.coworkers.first?.state == .arriving)
        #expect(stack.controller.milestoneCount == 0)
    }

    @Test("Only unlocked soundscapes reach the picker")
    func catalogueFollowsOwnership() async throws {
        let stack = try await makeController()
        await stack.controller.refreshCatalogue()
        #expect(stack.controller.availableSoundscapes.isEmpty)

        var brown = Unlockable()
        brown.key = "sound.brown"
        brown.type = .soundscape
        brown.title = "Brown Noise"
        brown.unlockedAt = Date()
        _ = try await stack.provider.collection.upsert(brown)

        await stack.controller.refreshCatalogue()
        #expect(stack.controller.availableSoundscapes.map(\.key) == ["sound.brown"])
    }

    @Test("An unlocked but unrecorded soundscape still does not appear")
    func unrecordedStaysHidden() async throws {
        let stack = try await makeController()

        var cafe = Unlockable()
        cafe.key = "sound.cafe"
        cafe.type = .soundscape
        cafe.title = "Café"
        cafe.unlockedAt = Date()
        _ = try await stack.provider.collection.upsert(cafe)

        await stack.controller.refreshCatalogue()
        #expect(stack.controller.availableSoundscapes.isEmpty)
    }
}
