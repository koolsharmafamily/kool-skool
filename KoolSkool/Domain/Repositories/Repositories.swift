import Foundation

// Every repository speaks in the `Sendable` value types from `Domain/Entities`,
// never in SwiftData model objects. That is what keeps SwiftData out of the
// feature code and lets a networked implementation slot in later without any
// view or view model changing.
//
// All methods are `async throws` even where the v1 local implementation could
// answer synchronously, because the eventual remote one cannot.

// MARK: - Tasks

protocol TaskRepository: Sendable {
    /// Live (not soft-deleted) tasks, newest musts first, then by `sortOrder`.
    func tasks(includeCompleted: Bool) async throws -> [FocusTask]
    func task(id: UUID) async throws -> FocusTask?

    /// The at-most-three musts for a given day.
    func musts(on day: Date) async throws -> [FocusTask]

    /// Creates or updates. Returns the stored value with its stamped metadata.
    @discardableResult
    func upsert(_ task: FocusTask) async throws -> FocusTask

    /// One-tap capture from the brain dump. No fields to fill.
    @discardableResult
    func captureFromBrainDump(_ text: String) async throws -> FocusTask

    func softDelete(taskID: UUID) async throws

    func complete(taskID: UUID, at date: Date, actualMinutes: Int?) async throws

    func reopen(taskID: UUID) async throws

    /// Pass `nil` for `day` to clear the must.
    /// Throws `RepositoryError.mustLimitReached` when the day already has
    /// `TaskRules.mustLimit` musts.
    func setMust(taskID: UUID, day: Date?) async throws

    @discardableResult
    func upsertStep(_ step: TaskStep) async throws -> TaskStep
    func softDeleteStep(stepID: UUID) async throws
    /// Replaces a task's steps wholesale — used by the quick templates.
    func replaceSteps(taskID: UUID, titles: [String]) async throws
}

enum TaskRules {
    /// The anti-overwhelm cap. Three, and only three.
    static let mustLimit = 3
}

// MARK: - Focus sessions

protocol SessionRepository: Sendable {
    func session(id: UUID) async throws -> FocusSession?

    /// The session with no `endedAt`, if one exists.
    ///
    /// This is how a running session is recovered after a force quit or a
    /// device restart: the app asks the store, not an in-memory timer.
    func activeSession() async throws -> FocusSession?

    func sessions(in range: Range<Date>) async throws -> [FocusSession]
    func recentSessions(limit: Int) async throws -> [FocusSession]

    /// Distinct local-midnight days that have at least one completed session.
    /// Backs both the streak calculation and the Insights calendar.
    func completedSessionDays(since: Date) async throws -> [Date]

    /// Count of completed sessions, for the long-break cadence and for stats.
    func completedSessionCount(in range: Range<Date>) async throws -> Int

    @discardableResult
    func upsert(_ session: FocusSession) async throws -> FocusSession
    func softDelete(sessionID: UUID) async throws
}

// MARK: - Check-ins and medication

protocol CheckInRepository: Sendable {
    func checkIns(in range: Range<Date>) async throws -> [CheckIn]
    func checkIns(forSessionID sessionID: UUID) async throws -> [CheckIn]
    @discardableResult
    func upsert(_ checkIn: CheckIn) async throws -> CheckIn
    func softDelete(checkInID: UUID) async throws
}

protocol MedicationRepository: Sendable {
    func logs(in range: Range<Date>) async throws -> [MedicationLog]
    func mostRecentLog() async throws -> MedicationLog?
    @discardableResult
    func upsert(_ log: MedicationLog) async throws -> MedicationLog
    func softDelete(logID: UUID) async throws
}

// MARK: - Progress and collection

protocol ProgressRepository: Sendable {
    /// Returns the single progress row, creating it on first access.
    func progress() async throws -> UserProgress
    @discardableResult
    func update(_ progress: UserProgress) async throws -> UserProgress
}

protocol CollectionRepository: Sendable {
    func unlockables() async throws -> [Unlockable]
    func unlockable(key: String) async throws -> Unlockable?
    @discardableResult
    func upsert(_ unlockable: Unlockable) async throws -> Unlockable
    /// Seeds the catalogue on first launch. Existing rows are left alone so
    /// unlock state is never clobbered by an app update.
    func seedIfNeeded(_ catalogue: [Unlockable]) async throws
    /// Equips one item of a type and unequips the rest of that type.
    func equip(key: String) async throws
}

// MARK: - Stillness

protocol StillnessRepository: Sendable {
    func practices() async throws -> [Practice]
    func practice(id: UUID) async throws -> Practice?
    func seedPracticesIfNeeded(_ practices: [Practice]) async throws

    func sits(in range: Range<Date>) async throws -> [StillnessSession]
    func recentSits(limit: Int) async throws -> [StillnessSession]
    func completedSitCount() async throws -> Int
    /// Distinct local-midnight days with a completed sit. Backs the calm streak.
    func completedSitDays(since: Date) async throws -> [Date]

    @discardableResult
    func upsert(_ sit: StillnessSession) async throws -> StillnessSession
    func softDelete(sitID: UUID) async throws
}

protocol ReflectionRepository: Sendable {
    /// The reflection for a given day, if one has been started.
    func reflection(on day: Date) async throws -> Reflection?
    func reflections(in range: Range<Date>) async throws -> [Reflection]
    @discardableResult
    func upsert(_ reflection: Reflection) async throws -> Reflection
}

// MARK: - Settings

protocol SettingsRepository: Sendable {
    /// Returns the single settings row, creating it with defaults on first access.
    func settings() async throws -> AppSettings
    @discardableResult
    func update(_ settings: AppSettings) async throws -> AppSettings
}

// MARK: - Provider

/// The one object features are handed. Swapping the whole persistence stack —
/// for previews, for tests, or for a future networked backend — means swapping
/// this and nothing else.
protocol RepositoryProvider: Sendable {
    var tasks: any TaskRepository { get }
    var sessions: any SessionRepository { get }
    var checkIns: any CheckInRepository { get }
    var medication: any MedicationRepository { get }
    var progress: any ProgressRepository { get }
    var collection: any CollectionRepository { get }
    var stillness: any StillnessRepository { get }
    var reflections: any ReflectionRepository { get }
    var settings: any SettingsRepository { get }
}
