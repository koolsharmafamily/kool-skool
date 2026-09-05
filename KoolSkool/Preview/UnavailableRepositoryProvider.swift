import Foundation

/// Every method fails with `RepositoryError.storeUnavailable`.
///
/// Two jobs. It is the last-resort fallback when neither the on-disk nor the
/// in-memory store can be opened, so launch can report a problem instead of
/// crashing. And it is the provider to use in a preview that wants to see an
/// error state.
struct UnavailableRepositoryProvider: RepositoryProvider {
    var reason: String = "The local store could not be opened."

    private var store: UnavailableStore { UnavailableStore(reason: reason) }

    var tasks: any TaskRepository { store }
    var sessions: any SessionRepository { store }
    var checkIns: any CheckInRepository { store }
    var medication: any MedicationRepository { store }
    var progress: any ProgressRepository { store }
    var collection: any CollectionRepository { store }
    var stillness: any StillnessRepository { store }
    var reflections: any ReflectionRepository { store }
    var settings: any SettingsRepository { store }
}

private struct UnavailableStore: Sendable {
    let reason: String

    func fail<T>() throws -> T {
        throw RepositoryError.storeUnavailable(reason)
    }

    func fail() throws {
        throw RepositoryError.storeUnavailable(reason)
    }
}

extension UnavailableStore: TaskRepository {
    func tasks(includeCompleted: Bool) async throws -> [FocusTask] { try fail() }
    func task(id: UUID) async throws -> FocusTask? { try fail() }
    func musts(on day: Date) async throws -> [FocusTask] { try fail() }
    func upsert(_ task: FocusTask) async throws -> FocusTask { try fail() }
    func captureFromBrainDump(_ text: String) async throws -> FocusTask { try fail() }
    func softDelete(taskID: UUID) async throws { try fail() }
    func complete(taskID: UUID, at date: Date, actualMinutes: Int?) async throws { try fail() }
    func reopen(taskID: UUID) async throws { try fail() }
    func setMust(taskID: UUID, day: Date?) async throws { try fail() }
    func upsertStep(_ step: TaskStep) async throws -> TaskStep { try fail() }
    func softDeleteStep(stepID: UUID) async throws { try fail() }
    func replaceSteps(taskID: UUID, titles: [String]) async throws { try fail() }
}

extension UnavailableStore: SessionRepository {
    func session(id: UUID) async throws -> FocusSession? { try fail() }
    func activeSession() async throws -> FocusSession? { try fail() }
    func sessions(in range: Range<Date>) async throws -> [FocusSession] { try fail() }
    func recentSessions(limit: Int) async throws -> [FocusSession] { try fail() }
    func completedSessionDays(since: Date) async throws -> [Date] { try fail() }
    func completedSessionCount(in range: Range<Date>) async throws -> Int { try fail() }
    func upsert(_ session: FocusSession) async throws -> FocusSession { try fail() }
    func softDelete(sessionID: UUID) async throws { try fail() }
}

extension UnavailableStore: CheckInRepository {
    func checkIns(in range: Range<Date>) async throws -> [CheckIn] { try fail() }
    func checkIns(forSessionID sessionID: UUID) async throws -> [CheckIn] { try fail() }
    func upsert(_ checkIn: CheckIn) async throws -> CheckIn { try fail() }
    func softDelete(checkInID: UUID) async throws { try fail() }
}

extension UnavailableStore: MedicationRepository {
    func logs(in range: Range<Date>) async throws -> [MedicationLog] { try fail() }
    func mostRecentLog() async throws -> MedicationLog? { try fail() }
    func upsert(_ log: MedicationLog) async throws -> MedicationLog { try fail() }
    func softDelete(logID: UUID) async throws { try fail() }
}

extension UnavailableStore: ProgressRepository {
    func progress() async throws -> UserProgress { try fail() }
    func update(_ progress: UserProgress) async throws -> UserProgress { try fail() }
}

extension UnavailableStore: CollectionRepository {
    func unlockables() async throws -> [Unlockable] { try fail() }
    func unlockable(key: String) async throws -> Unlockable? { try fail() }
    func upsert(_ unlockable: Unlockable) async throws -> Unlockable { try fail() }
    func seedIfNeeded(_ catalogue: [Unlockable]) async throws { try fail() }
    func equip(key: String) async throws { try fail() }
}

extension UnavailableStore: StillnessRepository {
    func practices() async throws -> [Practice] { try fail() }
    func practice(id: UUID) async throws -> Practice? { try fail() }
    func seedPracticesIfNeeded(_ practices: [Practice]) async throws { try fail() }
    func sits(in range: Range<Date>) async throws -> [StillnessSession] { try fail() }
    func recentSits(limit: Int) async throws -> [StillnessSession] { try fail() }
    func completedSitCount() async throws -> Int { try fail() }
    func completedSitDays(since: Date) async throws -> [Date] { try fail() }
    func upsert(_ sit: StillnessSession) async throws -> StillnessSession { try fail() }
    func softDelete(sitID: UUID) async throws { try fail() }
}

extension UnavailableStore: ReflectionRepository {
    func reflection(on day: Date) async throws -> Reflection? { try fail() }
    func reflections(in range: Range<Date>) async throws -> [Reflection] { try fail() }
    func upsert(_ reflection: Reflection) async throws -> Reflection { try fail() }
}

extension UnavailableStore: SettingsRepository {
    func settings() async throws -> AppSettings { try fail() }
    func update(_ settings: AppSettings) async throws -> AppSettings { try fail() }
}
