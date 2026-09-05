import Foundation
import Testing
@testable import KoolSkool

@Suite("XP and levels")
struct ProgressMathTests {

    @Test("A new user is level 1 with no XP")
    func startsAtLevelOne() {
        let progress = UserProgress()
        #expect(progress.level == 1)
        #expect(progress.xpIntoCurrentLevel == 0)
        #expect(progress.levelProgress == 0)
    }

    @Test("The XP curve is strictly increasing")
    func curveIsMonotonic() {
        var previous = UserProgress.xpRequired(forLevel: 1)
        for level in 2...40 {
            let required = UserProgress.xpRequired(forLevel: level)
            #expect(required > previous, "Level \(level) must cost more than \(level - 1)")
            previous = required
        }
    }

    @Test("Level 1 requires no XP")
    func levelOneIsFree() {
        #expect(UserProgress.xpRequired(forLevel: 1) == 0)
        #expect(UserProgress.xpRequired(forLevel: 0) == 0)
    }

    @Test("The first few levels arrive quickly")
    func earlyLevelsAreCheap() {
        // A single completed Pomodoro should be worth a level early on, so the
        // very first session visibly moves something.
        #expect(UserProgress.xpRequired(forLevel: 2) == 50)
        #expect(UserProgress.xpRequired(forLevel: 3) == 150)
    }

    @Test("level(forXP:) is the inverse of xpRequired(forLevel:)")
    func levelRoundTrips() {
        for level in 1...30 {
            let exact = UserProgress.xpRequired(forLevel: level)
            #expect(UserProgress.level(forXP: exact) == level)

            // One XP short of the threshold is still the previous level.
            if level > 1 {
                #expect(UserProgress.level(forXP: exact - 1) == level - 1)
            }
        }
    }

    @Test("Negative or zero XP never produces a level below 1")
    func levelNeverGoesBelowOne() {
        #expect(UserProgress.level(forXP: 0) == 1)
        #expect(UserProgress.level(forXP: -500) == 1)
    }

    @Test("Level progress stays inside 0...1")
    func levelProgressIsClamped() {
        for xp in stride(from: 0, through: 5000, by: 37) {
            var progress = UserProgress()
            progress.xp = xp
            #expect(progress.levelProgress >= 0)
            #expect(progress.levelProgress <= 1)
        }
    }

    @Test("A user starts the month with two streak freezes")
    func freezeBudget() {
        let progress = UserProgress()
        #expect(progress.freezesRemaining == 2)
        #expect(progress.freezesUsedThisMonth == 0)
        #expect(UserProgress.freezesPerMonth == 2)
    }
}

@Suite("Rating")
struct RatingTests {

    @Test("Values outside 1...5 are rejected")
    func rejectsOutOfRange() {
        #expect(Rating(rawValue: 0) == nil)
        #expect(Rating(rawValue: 6) == nil)
        #expect(Rating(rawValue: 3)?.rawValue == 3)
    }

    @Test("Clamping never fails")
    func clampsInsteadOfFailing() {
        #expect(Rating(clamping: -10).rawValue == 1)
        #expect(Rating(clamping: 99).rawValue == 5)
        #expect(Rating(clamping: 4).rawValue == 4)
    }
}
