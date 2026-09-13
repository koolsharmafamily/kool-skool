import Foundation
import Observation

/// Ties the companion and the soundscape to the session lifecycle.
///
/// The engine calls into this; the views read from it. Swapping
/// `LocalCompanionProvider` for a future `RemoteRoomProvider` happens here and
/// nowhere else.
@MainActor
@Observable
final class BodyDoublingController {
    private let provider: any BodyDoublingProvider
    private let audio: SoundscapeEngine
    private let repositories: any RepositoryProvider

    private(set) var coworkers: [Coworker] = []
    private(set) var availableSoundscapes: [Soundscape] = []
    private(set) var lastMilestone: CompanionMilestone?
    /// Bumped on each milestone so the companion's symbol effect has something
    /// to fire on.
    private(set) var milestoneCount = 0

    var settings = AppSettings()

    init(
        provider: any BodyDoublingProvider = LocalCompanionProvider(),
        audio: SoundscapeEngine = SoundscapeEngine(),
        repositories: any RepositoryProvider
    ) {
        self.provider = provider
        self.audio = audio
        self.repositories = repositories
    }

    // MARK: Derived

    var currentSoundscape: Soundscape? { audio.current }
    var isPlayingAudio: Bool { audio.isPlaying }
    var audioError: String? { audio.lastError }

    // MARK: Loading

    /// Refreshes what the picker can offer. A soundscape has to be both
    /// unlocked and actually playable to appear.
    func refreshCatalogue() async {
        do {
            let owned = try await repositories.collection.unlockables()
                .filter(\.isUnlocked)
            availableSoundscapes = SoundscapeCatalogue.available(ownedKeys: Set(owned.map(\.key)))

            if let equippedSkin = owned.first(where: { $0.type == .companionSkin && $0.isEquipped }),
               let local = provider as? LocalCompanionProvider {
                await local.setSkin(equippedSkin.key)
            }

            coworkers = await provider.coworkers()
        } catch {
            availableSoundscapes = []
        }
    }

    // MARK: Session lifecycle

    func sessionDidStart(_ session: FocusSession) async {
        await provider.begin(session: session)
        coworkers = await provider.coworkers()
        lastMilestone = nil
        milestoneCount = 0

        await refreshCatalogue()
        resumeSavedSoundscape()
    }

    /// Called from the engine tick. Only acts when a new milestone is crossed.
    func sessionDidProgress(to progress: Double) async {
        guard let milestone = CompanionMilestone.reached(at: progress) else { return }
        guard milestone != lastMilestone else { return }

        lastMilestone = milestone
        milestoneCount += 1
        await provider.reportMilestone(milestone)
        coworkers = await provider.coworkers()
    }

    func sessionDidEnd(_ session: FocusSession, completed: Bool) async {
        await provider.end(session: session, completed: completed)
        coworkers = await provider.coworkers()
        audio.stop()

        if completed && settings.soundsEnabled {
            audio.playChime()
        }
    }

    func reset() async {
        await provider.reset()
        coworkers = await provider.coworkers()
        lastMilestone = nil
        milestoneCount = 0
    }

    // MARK: Audio control

    func select(_ soundscape: Soundscape?) {
        guard let soundscape else {
            audio.stop()
            Task { await persistSelection(nil) }
            return
        }

        audio.play(soundscape)
        Task { await persistSelection(soundscape.key) }
    }

    func toggleAudio() {
        if audio.isPlaying {
            audio.stop()
        } else if let saved = SoundscapeCatalogue.named(settings.soundscapeKey) {
            audio.play(saved)
        } else if let first = availableSoundscapes.first {
            select(first)
        }
    }

    func setVolume(_ volume: Float) {
        audio.setVolume(volume)
    }

    /// The stillness layer's bell, routed through the one audio stack.
    ///
    /// Owned here rather than by the sit model so there is still exactly one
    /// `AVAudioSession` configuration in the app, and so a bell can ring over a
    /// soundscape that is already playing.
    func ringBell(frequency: Double) {
        guard settings.soundsEnabled else { return }
        audio.playBell(frequency: frequency)
    }

    /// Picks up whatever was playing last time, if it is still owned and the
    /// user has not turned sound off.
    private func resumeSavedSoundscape() {
        guard settings.soundsEnabled else { return }
        guard let saved = SoundscapeCatalogue.named(settings.soundscapeKey) else { return }
        guard availableSoundscapes.contains(where: { $0.key == saved.key }) else { return }
        audio.play(saved)
    }

    private func persistSelection(_ key: String?) async {
        do {
            var updated = try await repositories.settings.settings()
            updated.soundscapeKey = key
            settings = try await repositories.settings.update(updated)
        } catch {
            // A soundscape that fails to stick is a preference, not data loss.
        }
    }
}
