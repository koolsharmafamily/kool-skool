import Foundation
import WidgetKit

/// Hands the widgets a fresh snapshot and asks them to redraw.
protocol WidgetSnapshotPublishing: Sendable {
    func publish(_ snapshot: WidgetSnapshot) async
}

struct AppGroupWidgetPublisher: WidgetSnapshotPublishing {
    init() {}

    func publish(_ snapshot: WidgetSnapshot) async {
        WidgetSnapshotStore.write(snapshot, to: WidgetSnapshotStore.sharedDefaults)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct NoOpWidgetPublisher: WidgetSnapshotPublishing {
    init() {}
    func publish(_ snapshot: WidgetSnapshot) async {}
}

final class RecordingWidgetPublisher: WidgetSnapshotPublishing, @unchecked Sendable {
    private let lock = NSLock()
    private var _published: [WidgetSnapshot] = []

    init() {}

    var published: [WidgetSnapshot] {
        lock.lock(); defer { lock.unlock() }
        return _published
    }

    func publish(_ snapshot: WidgetSnapshot) async {
        lock.lock(); _published.append(snapshot); lock.unlock()
    }
}

extension WidgetSnapshot {
    /// Builds the snapshot from app state.
    ///
    /// Deliberately takes only progress, musts and the running session. Check-
    /// ins, medication and reflections are not parameters, so they cannot leak
    /// onto a home screen by accident.
    static func make(
        progress: UserProgress,
        musts: [FocusTask],
        session: FocusSession?,
        clock: any DateProvider
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: clock.now,
            day: clock.today,
            streak: progress.currentStreak,
            level: progress.level,
            musts: musts.prefix(TaskRules.mustLimit).map { Must(title: $0.title, isDone: $0.isCompleted) },
            session: session.map { running in
                let countsUp = running.mode.defaultProfile.countsUp || running.plannedDuration <= 0
                return Session(
                    startedAt: running.startedAt,
                    plannedEnd: countsUp ? nil : running.startedAt.addingTimeInterval(running.plannedDuration),
                    modeName: running.mode.displayName
                )
            }
        )
    }
}
