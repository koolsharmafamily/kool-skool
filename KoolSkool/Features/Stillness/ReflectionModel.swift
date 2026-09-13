import Foundation
import Observation

/// The day's intention and close.
///
/// One row per day, matched on the day rather than by id, so the morning line
/// and the evening close land in the same record even though they are written
/// hours apart from different screens.
///
/// Every write sends the whole row, so the model keeps the loaded copy and
/// mutates it — saving only the fields being edited would blank the others.
@MainActor
@Observable
final class ReflectionModel {
    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    private(set) var today = Reflection()
    private(set) var recent: [Reflection] = []
    private(set) var lastError: String?

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        self.repositories = repositories
        self.clock = clock
        today.day = clock.today
    }

    var hasMorning: Bool { today.hasMorning }
    var hasEvening: Bool { today.hasEvening }

    var morningIntention: String { today.morningIntention }

    func load() async {
        do {
            let day = clock.today
            if let stored = try await repositories.reflections.reflection(on: day) {
                today = stored
            } else {
                var fresh = Reflection()
                fresh.day = day
                today = fresh
            }

            // Enough for the "what did I say last week" glance, no more.
            let since = day.addingTimeInterval(-14 * 86_400)
            recent = try await repositories.reflections.reflections(in: since..<day.addingTimeInterval(86_400))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// One line, set once a day. Framed as an intention, not a task — nothing
    /// ever marks it done or holds it against anyone.
    func setMorningIntention(_ text: String) async {
        var draft = today
        draft.morningIntention = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await save(draft)
    }

    /// The thirty-second close. Any field may be left empty; an entirely empty
    /// close writes nothing at all rather than an empty row.
    func setEvening(wentWell: String, wasHard: String, gratitude: String) async {
        var draft = today
        draft.eveningWentWell = wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.eveningWasHard = wasHard.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.gratitude = gratitude.trimmingCharacters(in: .whitespacesAndNewlines)
        await save(draft)
    }

    private func save(_ draft: Reflection) async {
        // Nothing to say is a valid answer, and it should leave no trace.
        guard draft.hasMorning || draft.hasEvening else {
            today = draft
            return
        }

        do {
            var stamped = draft
            stamped.day = clock.today
            today = try await repositories.reflections.upsert(stamped)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
