import Foundation
import SwiftData

@Model
final class SDAppSettings {
    var id: UUID = UUID()
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var deletedAt: Date?

    var defaultModeRaw: String = SessionMode.justStart.rawValue
    var customWorkMinutes: Int = 30
    var customBreakMinutes: Int = 6
    var keepScreenAwakeDuringSession: Bool = true

    var timeChecksEnabled: Bool = false
    var timeCheckIntervalMinutes: Int = 10
    var showDigitalTimer: Bool = true
    var autoPadEstimates: Bool = false

    var hapticsEnabled: Bool = true
    var soundsEnabled: Bool = true
    var soundscapeKey: String?

    var reduceMotionOverride: Bool = false

    var traditionRaw: String = Tradition.secular.rawValue
    var offerBreakPractice: Bool = true
    var intervalBellsEnabled: Bool = false

    var hasCompletedOnboarding: Bool = false

    var defaultMode: SessionMode {
        get { SessionMode(rawValue: defaultModeRaw) ?? .justStart }
        set { defaultModeRaw = newValue.rawValue }
    }

    var tradition: Tradition {
        get { Tradition(rawValue: traditionRaw) ?? .secular }
        set { traditionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

// MARK: - Mapping

extension SDAppSettings {
    func toDomain() -> AppSettings {
        AppSettings(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            defaultMode: defaultMode,
            customWorkMinutes: customWorkMinutes,
            customBreakMinutes: customBreakMinutes,
            keepScreenAwakeDuringSession: keepScreenAwakeDuringSession,
            timeChecksEnabled: timeChecksEnabled,
            timeCheckIntervalMinutes: timeCheckIntervalMinutes,
            showDigitalTimer: showDigitalTimer,
            autoPadEstimates: autoPadEstimates,
            hapticsEnabled: hapticsEnabled,
            soundsEnabled: soundsEnabled,
            soundscapeKey: soundscapeKey,
            reduceMotionOverride: reduceMotionOverride,
            tradition: tradition,
            offerBreakPractice: offerBreakPractice,
            intervalBellsEnabled: intervalBellsEnabled,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    func apply(_ dto: AppSettings) {
        defaultModeRaw = dto.defaultMode.rawValue
        customWorkMinutes = dto.customWorkMinutes
        customBreakMinutes = dto.customBreakMinutes
        keepScreenAwakeDuringSession = dto.keepScreenAwakeDuringSession
        timeChecksEnabled = dto.timeChecksEnabled
        timeCheckIntervalMinutes = dto.timeCheckIntervalMinutes
        showDigitalTimer = dto.showDigitalTimer
        autoPadEstimates = dto.autoPadEstimates
        hapticsEnabled = dto.hapticsEnabled
        soundsEnabled = dto.soundsEnabled
        soundscapeKey = dto.soundscapeKey
        reduceMotionOverride = dto.reduceMotionOverride
        traditionRaw = dto.tradition.rawValue
        offerBreakPractice = dto.offerBreakPractice
        intervalBellsEnabled = dto.intervalBellsEnabled
        hasCompletedOnboarding = dto.hasCompletedOnboarding
        deletedAt = dto.deletedAt
    }
}
