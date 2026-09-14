import Foundation
import Observation

@MainActor
@Observable
final class InsightsModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    /// How far back Insights looks. Long enough for a pattern, short enough
    /// that a habit from last spring does not outvote this month.
    static let windowDays = 90
    static let calendarWeeks = 5

    private(set) var hasEnoughHistory = false
    private(set) var daysOfHistory = 0
    private(set) var buckets: [TimeOfDayBucket] = []
    private(set) var insight: TimeOfDayInsight?
    /// Onboarding's "when do you work best?", held up against the history.
    private(set) var preferenceSentence: String?
    private(set) var calendarDays: [CalendarDay] = []
    private(set) var recentSessions: [FocusSession] = []
    private(set) var medication: MedicationObservation?
    private(set) var progress = UserProgress()
    private(set) var calibration = EstimateCalibration.unknown
    private(set) var totalFocusMinutes = 0
    private(set) var completedCount = 0
    private(set) var error: String?

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        self.repositories = repositories
        self.clock = clock
    }

    var hasQualityData: Bool {
        buckets.contains { $0.averageFocusQuality != nil }
    }

    var daysUntilPatterns: Int {
        max(0, InsightsCalculator.minimumHistoryDays - daysOfHistory)
    }

    func load(includeMedication: Bool, preferredWorkTime: TimeOfDay? = nil) async {
        do {
            let now = clock.now
            let windowStart = now.addingTimeInterval(-Double(Self.windowDays) * 86_400)
            let range = windowStart..<now.addingTimeInterval(86_400)

            async let sessionsFetch = repositories.sessions.sessions(in: range)
            async let checkInsFetch = repositories.checkIns.checkIns(in: range)
            async let progressFetch = repositories.progress.progress()
            async let tasksFetch = repositories.tasks.tasks(includeCompleted: true)

            let sessions = try await sessionsFetch
            let checkIns = try await checkInsFetch
            progress = try await progressFetch
            calibration = EstimateCalibrator.calibrate(try await tasksFetch)

            let countable = InsightsCalculator.countable(sessions)
            hasEnoughHistory = InsightsCalculator.hasEnoughHistory(sessions, now: now)
            daysOfHistory = countable.map(\.startedAt).min().map { clock.dayDifference(from: $0, to: now) } ?? 0

            buckets = InsightsCalculator.timeOfDayBuckets(sessions: sessions, checkIns: checkIns, clock: clock)
            insight = hasEnoughHistory ? InsightsCalculator.timeOfDayInsight(buckets) : nil
            preferenceSentence = InsightsCalculator.preferenceSentence(preferred: preferredWorkTime, insight: insight)

            completedCount = countable.filter(\.wasCompleted).count
            totalFocusMinutes = countable.filter(\.wasCompleted).reduce(0) { $0 + $1.actualMinutes }
            recentSessions = Array(countable.sorted { $0.startedAt > $1.startedAt }.prefix(20))

            try await loadCalendar(now: now)

            if includeMedication {
                let logs = try await repositories.medication.logs(in: range)
                medication = InsightsCalculator.medicationObservation(sessions: sessions, logs: logs, clock: clock)
            } else {
                medication = nil
            }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// The calendar needs the frozen days, which only the streak walk knows.
    private func loadCalendar(now: Date) async throws {
        let since = now.addingTimeInterval(-Double(StreakCalculator.maximumLookbackDays) * 86_400)
        let days = try await repositories.sessions.completedSessionDays(since: since)

        let streak = StreakCalculator.evaluate(
            completedDays: days,
            today: now,
            previousLongest: progress.longestStreak,
            clock: clock
        )

        calendarDays = InsightsCalculator.calendar(
            completedDays: days,
            frozenDays: streak.frozenDays,
            today: now,
            weeks: Self.calendarWeeks,
            clock: clock
        )
    }
}
