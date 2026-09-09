import Foundation

/// What a soundscape is made of.
enum NoiseColour: String, Sendable, Equatable, CaseIterable {
    case brown
    case pink
    case rain
}

/// One ambient bed.
///
/// Two kinds, deliberately. The noise beds are generated on the fly, so they
/// need no assets, never loop audibly, and weigh nothing in the app bundle. The
/// recorded ones — a café, a library — cannot be faked and are marked
/// unavailable until real audio exists rather than shipping a lie.
struct Soundscape: Identifiable, Sendable, Equatable {
    enum Source: Sendable, Equatable {
        case synthesised(NoiseColour)
        case bundled(assetName: String, fileExtension: String)
    }

    /// Matches the `Unlockable` key, so owning the collectable is what unlocks it.
    var key: String
    var displayName: String
    var detail: String
    var source: Source

    var id: String { key }

    /// A generated bed is always playable. A recorded one is only playable once
    /// its file is actually in the bundle.
    var isAvailable: Bool {
        switch source {
        case .synthesised:
            return true
        case let .bundled(name, ext):
            return Bundle.main.url(forResource: name, withExtension: ext) != nil
        }
    }

    var unavailableReason: String? {
        isAvailable ? nil : "Arrives with the recorded audio."
    }
}

enum SoundscapeCatalogue {
    static let all: [Soundscape] = [
        Soundscape(
            key: "sound.brown",
            displayName: "Brown Noise",
            detail: "A wall of low static.",
            source: .synthesised(.brown)
        ),
        Soundscape(
            key: "sound.pink",
            displayName: "Pink Noise",
            detail: "Softer than white, less heavy than brown.",
            source: .synthesised(.pink)
        ),
        Soundscape(
            key: "sound.rain",
            displayName: "Rain",
            detail: "Steady, no thunder.",
            source: .synthesised(.rain)
        ),
        Soundscape(
            key: "sound.cafe",
            displayName: "Café",
            detail: "Other people, working.",
            source: .bundled(assetName: "soundscape-cafe", fileExtension: "m4a")
        ),
        Soundscape(
            key: "sound.library",
            displayName: "Library",
            detail: "Almost nothing, on purpose.",
            source: .bundled(assetName: "soundscape-library", fileExtension: "m4a")
        ),
    ]

    static func named(_ key: String?) -> Soundscape? {
        guard let key else { return nil }
        return all.first { $0.key == key }
    }

    /// What the picker offers: unlocked, and actually playable.
    static func available(ownedKeys: Set<String>) -> [Soundscape] {
        all.filter { ownedKeys.contains($0.key) && $0.isAvailable }
    }
}
