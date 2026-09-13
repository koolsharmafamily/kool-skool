import Foundation

/// Coarse times of day.
///
/// The spec asks for focus quality "by hour of day". With one person's sessions
/// that is twenty-four mostly empty bars and a lot of noise — two sessions at
/// 3pm is not a pattern. Five named blocks give each bar enough in it to mean
/// something, and read as a sentence rather than a histogram.
enum TimeOfDay: Int, CaseIterable, Sendable, Identifiable, Comparable {
    case early
    case morning
    case afternoon
    case evening
    case late

    var id: Int { rawValue }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.rawValue < rhs.rawValue }

    static func of(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<8: .early
        case 8..<12: .morning
        case 12..<17: .afternoon
        case 17..<21: .evening
        default: .late
        }
    }

    var displayName: String {
        switch self {
        case .early: "Early"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .late: "Late"
        }
    }

    var hoursLabel: String {
        switch self {
        case .early: "5–8am"
        case .morning: "8am–12"
        case .afternoon: "12–5pm"
        case .evening: "5–9pm"
        case .late: "9pm–5am"
        }
    }

    /// For the sentence, lower-cased and made to sit after "your".
    var phrase: String { displayName.lowercased() }
}

struct TimeOfDayBucket: Identifiable, Equatable, Sendable {
    var block: TimeOfDay
    var sessions: Int = 0
    var completed: Int = 0
    var qualityTotal: Int = 0
    var qualityCount: Int = 0

    var id: Int { block.rawValue }

    var completionRate: Double {
        sessions > 0 ? Double(completed) / Double(sessions) : 0
    }

    var averageFocusQuality: Double? {
        qualityCount > 0 ? Double(qualityTotal) / Double(qualityCount) : nil
    }
}

struct TimeOfDayInsight: Equatable, Sendable {
    var block: TimeOfDay
    /// 0.4 means sessions in `block` complete 40% more often than the rest.
    var lift: Double
    /// False when there is no meaningful difference — which is worth saying too.
    var isPattern: Bool
    var sentence: String
}

struct MedicationObservation: Equatable, Sendable {
    var daysWithLog: Int
    var daysWithoutLog: Int
    var completionWithLog: Double
    var completionWithoutLog: Double

    /// Arithmetic about the user's own log, and nothing else. Never a reason, a
    /// cause, or a recommendation — that line is the whole of the privacy and
    /// safety story for this feature.
    var sentence: String {
        let with = Int((completionWithLog * 100).rounded())
        let without = Int((completionWithoutLog * 100).rounded())
        return "On days you logged it, you completed \(with)% of sessions. On days you didn't, \(without)%."
    }
}

enum CalendarDayState: Sendable, Equatable {
    case active
    /// Missed, but a freeze kept the streak alive.
    case frozen
    case missed
    case future
    /// Before the first ever session — not a miss, just before the start.
    case beforeHistory
}

struct CalendarDay: Identifiable, Equatable, Sendable {
    var date: Date
    var state: CalendarDayState
    var isToday: Bool
    var id: Date { date }
}

/// Everything Insights says, computed from history with no state of its own.
///
/// The rule for every function here: say nothing until there is enough to say
/// something true. Two weeks, ten sessions, five per bucket, seven days per
/// group. Below those, a "pattern" is the app making things up about someone.
enum InsightsCalculator {

    static let minimumHistoryDays = 14
    static let minimumSessionsForPatterns = 10
    static let minimumSessionsPerBlock = 5
    /// Below this the difference is called "about the same" rather than
    /// dressed up as a finding.
    static let meaningfulLift = 0.15
    static let minimumDaysPerMedicationGroup = 7

    // MARK: Which sessions count

    /// Finished sessions whose outcome is actually known.
    ///
    /// A session capped after its heartbeat is excluded: nobody confirmed what
    /// happened, and counting it as a failure would bias the chart toward
    /// whenever the user tends to leave the app running.
    static func countable(_ sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { session in
            session.endedAt != nil
                && !session.isDeleted
                && session.endReason != .cappedAfterHeartbeat
        }
    }

    // MARK: History gate

    static func hasEnoughHistory(_ sessions: [FocusSession], now: Date) -> Bool {
        let finished = countable(sessions)
        guard finished.count >= minimumSessionsForPatterns else { return false }
        guard let first = finished.map(\.startedAt).min() else { return false }
        return now.timeIntervalSince(first) >= Double(minimumHistoryDays) * 86_400
    }

    // MARK: Time of day

    static func timeOfDayBuckets(
        sessions: [FocusSession],
        checkIns: [CheckIn],
        clock: any DateProvider
    ) -> [TimeOfDayBucket] {
        var calendar = clock.calendar
        calendar.timeZone = clock.timeZone

        var buckets = Dictionary(uniqueKeysWithValues: TimeOfDay.allCases.map { ($0, TimeOfDayBucket(block: $0)) })
        var blockBySession: [UUID: TimeOfDay] = [:]

        for session in countable(sessions) {
            let hour = calendar.component(.hour, from: session.startedAt)
            let block = TimeOfDay.of(hour: hour)
            blockBySession[session.id] = block
            buckets[block, default: TimeOfDayBucket(block: block)].sessions += 1
            if session.wasCompleted {
                buckets[block, default: TimeOfDayBucket(block: block)].completed += 1
            }
        }

        for checkIn in checkIns where checkIn.phase == .post && !checkIn.isDeleted {
            guard let quality = checkIn.focusQuality,
                  let sessionID = checkIn.sessionID,
                  let block = blockBySession[sessionID]
            else { continue }
            buckets[block, default: TimeOfDayBucket(block: block)].qualityTotal += quality.rawValue
            buckets[block, default: TimeOfDayBucket(block: block)].qualityCount += 1
        }

        return TimeOfDay.allCases.compactMap { buckets[$0] }
    }

    /// The one sentence the spec asks for: "your sessions before noon complete
    /// 40% more often."
    ///
    /// Compares the best-performing block against every other session pooled,
    /// not against the next-best block, because "more often than the rest" is
    /// the comparison a person actually means.
    static func timeOfDayInsight(_ buckets: [TimeOfDayBucket]) -> TimeOfDayInsight? {
        let eligible = buckets.filter { $0.sessions >= minimumSessionsPerBlock }
        guard let best = eligible.max(by: { $0.completionRate < $1.completionRate }) else { return nil }

        let rest = buckets.filter { $0.block != best.block }
        let restSessions = rest.reduce(0) { $0 + $1.sessions }
        let restCompleted = rest.reduce(0) { $0 + $1.completed }

        guard restSessions >= minimumSessionsPerBlock else { return nil }

        let restRate = Double(restCompleted) / Double(restSessions)
        guard restRate > 0 else { return nil }

        let lift = best.completionRate / restRate - 1
        let roundedPercent = Int((lift * 100 / 5).rounded() * 5)

        guard lift >= meaningfulLift, roundedPercent > 0 else {
            return TimeOfDayInsight(
                block: best.block,
                lift: max(0, lift),
                isPattern: false,
                sentence: "Your sessions complete about as often whatever the time of day."
            )
        }

        return TimeOfDayInsight(
            block: best.block,
            lift: lift,
            isPattern: true,
            sentence: "Your \(best.block.phrase) sessions complete about \(roundedPercent)% more often than the rest."
        )
    }

    // MARK: Medication

    /// Completion on days with a medication log against days without one.
    ///
    /// "Days without a log" is not "days it wasn't taken" — someone can take it
    /// and not log it — so the sentence says exactly what was measured and no
    /// more.
    static func medicationObservation(
        sessions: [FocusSession],
        logs: [MedicationLog],
        clock: any DateProvider
    ) -> MedicationObservation? {
        let loggedDays = Set(
            logs
                .filter { $0.taken && !$0.isDeleted }
                .map { clock.startOfDay(for: $0.timestamp) }
        )

        var withSessions = 0, withCompleted = 0
        var withoutSessions = 0, withoutCompleted = 0
        var withDays = Set<Date>(), withoutDays = Set<Date>()

        for session in countable(sessions) {
            let day = clock.startOfDay(for: session.startedAt)
            if loggedDays.contains(day) {
                withDays.insert(day)
                withSessions += 1
                if session.wasCompleted { withCompleted += 1 }
            } else {
                withoutDays.insert(day)
                withoutSessions += 1
                if session.wasCompleted { withoutCompleted += 1 }
            }
        }

        guard withDays.count >= minimumDaysPerMedicationGroup,
              withoutDays.count >= minimumDaysPerMedicationGroup,
              withSessions > 0, withoutSessions > 0
        else { return nil }

        return MedicationObservation(
            daysWithLog: withDays.count,
            daysWithoutLog: withoutDays.count,
            completionWithLog: Double(withCompleted) / Double(withSessions),
            completionWithoutLog: Double(withoutCompleted) / Double(withoutSessions)
        )
    }

    // MARK: Calendar

    /// Whole weeks ending with the one that contains today, so the grid lines up
    /// under weekday headings rather than starting on an arbitrary day.
    static func calendar(
        completedDays: [Date],
        frozenDays: [Date],
        today: Date,
        weeks: Int,
        clock: any DateProvider
    ) -> [CalendarDay] {
        var calendar = clock.calendar
        calendar.timeZone = clock.timeZone

        let startOfToday = clock.startOfDay(for: today)
        let active = Set(completedDays.map { clock.startOfDay(for: $0) })
        let frozen = Set(frozenDays.map { clock.startOfDay(for: $0) })
        let earliest = active.min()

        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start,
              let firstWeek = calendar.date(byAdding: .weekOfYear, value: -(max(1, weeks) - 1), to: thisWeek)
        else { return [] }

        var days: [CalendarDay] = []
        var cursor = clock.startOfDay(for: firstWeek)

        for _ in 0..<(max(1, weeks) * 7) {
            let state: CalendarDayState
            if cursor > startOfToday {
                state = .future
            } else if active.contains(cursor) {
                state = .active
            } else if frozen.contains(cursor) {
                state = .frozen
            } else if let earliest, cursor < earliest {
                state = .beforeHistory
            } else if earliest == nil {
                state = .beforeHistory
            } else if cursor == startOfToday {
                // Today is not over, so it is not a miss yet.
                state = .future
            } else {
                state = .missed
            }

            days.append(CalendarDay(date: cursor, state: state, isToday: cursor == startOfToday))

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = clock.startOfDay(for: next)
        }

        return days
    }
}
