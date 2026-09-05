import Foundation
import SwiftData

/// The one SwiftData actor. It owns a single `ModelContext` and conforms to
/// every repository protocol, split across the `KoolSkoolStore+*` files.
///
/// One actor rather than one per repository, deliberately: a single context
/// means a write made through `TaskRepository` is immediately visible to a read
/// through `SessionRepository`, with no cross-context staleness to reason about.
///
/// `@ModelActor` moves all of this off the main thread. Nothing in here touches
/// UI, and no `SD*` object escapes — every method maps to a `Sendable` domain
/// value before returning.
@ModelActor
actor KoolSkoolStore {
    /// Injected so streak, must-of-the-day, and reflection maths can be tested
    /// against a fixed clock, including across DST and timezone changes.
    var clock: any DateProvider = SystemDateProvider()

    func setClock(_ clock: any DateProvider) {
        self.clock = clock
    }

    // MARK: Shared helpers

    var now: Date { clock.now }

    func startOfDay(_ date: Date) -> Date { clock.startOfDay(for: date) }

    /// The half-open range covering the local day containing `date`.
    func dayRange(containing date: Date) -> Range<Date> {
        let start = startOfDay(date)
        let end = start.addingTimeInterval(86_400)
        return start..<end
    }

    func fetchFirst<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = []
    ) throws -> T? {
        var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchAll<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        if let limit { descriptor.fetchLimit = limit }
        return try modelContext.fetch(descriptor)
    }

    func persist() throws {
        guard modelContext.hasChanges else { return }
        try modelContext.save()
    }

    /// Collapses a list of instants into the distinct local days they fall on,
    /// most recent first. Used by both streaks and the Insights calendar.
    func distinctDays(from dates: [Date]) -> [Date] {
        var seen = Set<Date>()
        var result: [Date] = []
        for date in dates {
            let day = startOfDay(date)
            if seen.insert(day).inserted {
                result.append(day)
            }
        }
        return result.sorted(by: >)
    }
}
