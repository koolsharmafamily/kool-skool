import SwiftUI
import UIKit
import WidgetKit

enum WidgetPalette {
    static let canvasDark = Color(uiColor: UIColor(hex: 0x0A0A0F))

    static let canvas = Color(uiColor: UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? 0x0A0A0F : 0xF7F7FA)
    })
}

struct TodayEntry: TimelineEntry {
    let date: Date
    /// Nil until the App Group is switched on, or before the app's first launch.
    /// The widget is a one-tap launcher in that state, not a broken one.
    let snapshot: WidgetSnapshot?

    var sessionState: WidgetSnapshot.SessionState {
        snapshot?.sessionState(asOf: date) ?? .idle
    }

    var url: URL {
        switch sessionState {
        case .idle: DeepLink.justStart.url
        case .running, .timeUp: DeepLink.session.url
        }
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: WidgetSnapshotStore.read(from: WidgetSnapshotStore.sharedDefaults)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotStore.read(from: WidgetSnapshotStore.sharedDefaults)

        let entries = WidgetTimeline.refreshDates(for: snapshot, now: now, calendar: calendar)
            .map { TodayEntry(date: $0, snapshot: snapshot) }

        completion(Timeline(entries: entries, policy: .after(WidgetTimeline.nextMidnight(after: now, calendar: calendar))))
    }
}

/// Streak, today's three, and a one-tap start.
///
/// Lock Screen sizes show numbers and the timer only — never a task title. A
/// Lock Screen is readable by whoever picks the phone up, and it is always on.
struct TodayWidget: Widget {
    let kind = "com.koolskool.app.today"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.canvas }
        }
        .configurationDisplayName("Today")
        .description("Your streak, today's three, and a one-tap start.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(entry.url)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            CircularTodayView(entry: entry)
        case .accessoryRectangular:
            RectangularTodayView(entry: entry)
        case .accessoryInline:
            InlineTodayView(entry: entry)
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                SmallTodayView(entry: entry)
                MustsColumn(entry: entry)
            }
        default:
            SmallTodayView(entry: entry)
        }
    }
}

// MARK: - Home screen

struct SmallTodayView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let snapshot = entry.snapshot {
                Label(snapshot.streakLabel, systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(KSEnergyState.ready.sharedAccent)

                Text("Level \(snapshot.level)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Kool Skool")
                    .font(.headline)
            }

            Spacer(minLength: 8)

            switch entry.sessionState {
            case let .running(session):
                Text(session.modeName)
                    .font(.subheadline)
                    .foregroundStyle(KSEnergyState.focusing.sharedAccent)
                WidgetTimerText(session: session)
                    .font(.title2.monospacedDigit().weight(.bold))
            case .timeUp:
                Text("Time's up")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(KSEnergyState.overrun.sharedAccent)
            case .idle:
                Label("Just Start", systemImage: "bolt.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(KSEnergyState.ready.sharedAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MustsColumn: View {
    let entry: TodayEntry

    private var musts: [WidgetSnapshot.Must] {
        entry.snapshot?.musts(asOf: entry.date, calendar: .current) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if musts.isEmpty {
                Text(entry.snapshot == nil ? "Open the app to pick today's three." : "Nothing pinned for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(musts.enumerated()), id: \.offset) { _, must in
                    Label {
                        Text(must.title)
                            .font(.subheadline)
                            .strikethrough(must.isDone)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: must.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(KSEnergyState.ready.sharedAccent)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock Screen

struct CircularTodayView: View {
    let entry: TodayEntry

    var body: some View {
        switch entry.sessionState {
        case let .running(session):
            if let end = session.plannedEnd {
                ProgressView(timerInterval: session.startedAt...max(session.startedAt, end), countsDown: true) {
                    Image(systemName: "timer")
                } currentValueLabel: {
                    Image(systemName: "timer")
                }
                .progressViewStyle(.circular)
            } else {
                Image(systemName: "timer")
                    .font(.title2)
            }
        case .timeUp:
            Image(systemName: "bell.fill")
                .font(.title2)
        case .idle:
            if let snapshot = entry.snapshot {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                    Text("\(snapshot.streak)")
                        .font(.headline.monospacedDigit())
                }
            } else {
                Image(systemName: "bolt.fill")
                    .font(.title2)
            }
        }
    }
}

struct RectangularTodayView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch entry.sessionState {
            case let .running(session):
                Text(session.modeName)
                    .font(.headline)
                WidgetTimerText(session: session)
                    .font(.title3.monospacedDigit())
            case let .timeUp(session):
                Text(session.modeName)
                    .font(.headline)
                Text("Time's up")
            case .idle:
                Text(entry.snapshot?.streakLabel ?? "Kool Skool")
                    .font(.headline)
                Text(entry.snapshot.map { "Level \($0.level)" } ?? "Tap to just start")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineTodayView: View {
    let entry: TodayEntry

    var body: some View {
        switch entry.sessionState {
        case let .running(session):
            Label {
                WidgetTimerText(session: session)
            } icon: {
                Image(systemName: "timer")
            }
        case .timeUp:
            Label("Time's up", systemImage: "bell.fill")
        case .idle:
            Label(entry.snapshot?.streakLabel ?? "Just Start", systemImage: entry.snapshot == nil ? "bolt.fill" : "flame.fill")
        }
    }
}

/// Counts itself. No timeline entry per second, no drift.
struct WidgetTimerText: View {
    let session: WidgetSnapshot.Session

    var body: some View {
        if let end = session.plannedEnd {
            Text(timerInterval: session.startedAt...max(session.startedAt, end), countsDown: true)
        } else {
            Text(session.startedAt, style: .timer)
        }
    }
}
