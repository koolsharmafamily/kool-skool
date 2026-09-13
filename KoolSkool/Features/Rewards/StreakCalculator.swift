import Foundation

struct StreakOutcome: Equatable, Sendable {
    var current: Int
    var longest: Int
    var freezesRemaining: Int
    var freezesUsedThisMonth: Int
    /// The days a freeze covered, most recent first. The Insights calendar in
    /// Milestone 7 draws these differently from both active and missed days.
    var frozenDays: [Date]
    var lastActiveDay: Date?

    static let empty = StreakOutcome(
        current: 0,
        longest: 0,
        freezesRemaining: UserProgress.freezesPerMonth,
        freezesUsedThisMonth: 0,
        frozenDays: [],
        lastActiveDay: nil
    )
}

/// Streaks, with mercy.
///
/// Recomputed from history every time rather than incremented, which makes it
/// idempotent and self-healing: a missed update, a restore from backup, or a
/// clock that jumped cannot leave a wrong number stuck in the store.
///
/// Freezes fall out of the same walk. Nothing about them is stored, so they
/// cannot drift out of step with the history they are supposed to describe —
/// "applied automatically and retroactively" is the only way they are applied.
enum StreakCalculator {

    /// Two years is far past any streak worth walking, and it stops a corrupt
    /// date from turning the walk into a hang.
    static let maximumLookbackDays = 730

    /// - Parameters:
    ///   - completedDays: any instants on days with at least one completed
    ///     session. Order and duplicates do not matter.
    ///   - today: now.
    ///   - previousLongest: the stored record, so a longest streak is never
    ///     lost even if history is trimmed.
    ///   - freezeBudget: freezes available per calendar month. The calm streak
    ///     passes zero: it has no freezes because it has no failure state to
    ///     rescue — a day without a sit simply does not appear.
    static func evaluate(
        completedDays: [Date],
        today: Date,
        previousLongest: Int,
        clock: any DateProvider,
        freezeBudget: Int = UserProgress.freezesPerMonth
    ) -> StreakOutcome {
        let active = Set(completedDays.map { clock.startOfDay(for: $0) })

        guard let earliest = active.min() else {
            return StreakOutcome(
                current: 0,
                longest: previousLongest,
                freezesRemaining: freezeBudget,
                freezesUsedThisMonth: 0,
                frozenDays: [],
                lastActiveDay: nil
            )
        }

        let startOfToday = clock.startOfDay(for: today)

        var calendar = clock.calendar
        calendar.timeZone = clock.timeZone

        var current = 0
        var oldestCounted: Date?
        var provisionalFreezes: [Date] = []
        var usageByMonth: [Date: Int] = [:]

        // Today is neither counted nor held against anyone until it has a
        // session — the day is not over yet.
        var cursor = startOfToday
        if active.contains(cursor) {
            current += 1
            oldestCounted = cursor
        }

        var steps = 0
        while steps < maximumLookbackDays {
            steps += 1

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            // Re-normalised because a handful of timezones have skipped midnight
            // on a DST day, and an un-normalised cursor would stop matching.
            cursor = clock.startOfDay(for: previous)

            // Nothing older than the first ever session can extend anything.
            guard cursor >= earliest else { break }

            if active.contains(cursor) {
                current += 1
                oldestCounted = cursor
                continue
            }

            guard freezeBudget > 0 else { break }
            guard let month = monthStart(of: cursor, clock: clock) else { break }
            let used = usageByMonth[month, default: 0]
            guard used < freezeBudget else { break }

            usageByMonth[month] = used + 1
            provisionalFreezes.append(cursor)
        }

        // A freeze only counts if it actually bridged a gap inside the surviving
        // streak. Ones spent past the last day that survived kept nothing alive,
        // so they are handed back rather than silently burned.
        let frozenDays: [Date]
        if let oldestCounted {
            frozenDays = provisionalFreezes.filter { $0 > oldestCounted }
        } else {
            frozenDays = []
        }

        let thisMonth = monthStart(of: startOfToday, clock: clock)
        let usedThisMonth = frozenDays.filter { monthStart(of: $0, clock: clock) == thisMonth }.count

        return StreakOutcome(
            current: current,
            longest: max(previousLongest, current),
            freezesRemaining: max(0, freezeBudget - usedThisMonth),
            freezesUsedThisMonth: usedThisMonth,
            frozenDays: frozenDays.sorted(by: >),
            lastActiveDay: active.max()
        )
    }

    /// Midnight on the first of the month containing `date`. Freezes are budgeted
    /// per calendar month, and the month that matters is the missed day's.
    static func monthStart(of date: Date, clock: any DateProvider) -> Date? {
        var calendar = clock.calendar
        calendar.timeZone = clock.timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }
}

extension UserProgress {
    /// Folds a freshly computed streak into the progress row.
    func applying(_ outcome: StreakOutcome) -> UserProgress {
        var updated = self
        updated.currentStreak = outcome.current
        updated.longestStreak = max(longestStreak, outcome.longest)
        updated.freezesRemaining = outcome.freezesRemaining
        updated.freezesUsedThisMonth = outcome.freezesUsedThisMonth
        updated.lastSessionDay = outcome.lastActiveDay
        return updated
    }

    /// Folds a freshly computed calm streak into the progress row.
    ///
    /// Deliberately touches none of the freeze fields: the calm streak has no
    /// freezes, and borrowing the focus streak's budget would quietly spend it.
    func applyingCalm(_ outcome: StreakOutcome) -> UserProgress {
        var updated = self
        updated.calmStreak = outcome.current
        updated.longestCalmStreak = max(longestCalmStreak, outcome.current)
        updated.lastSitDay = outcome.lastActiveDay
        return updated
    }

    /// Never "you lost 47 days". A broken streak is a fresh start, and the copy
    /// says so everywhere it appears.
    var streakLabel: String {
        currentStreak == 0 ? "Fresh start" : "Day \(currentStreak)"
    }
}
