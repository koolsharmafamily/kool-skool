import ActivityKit
import SwiftUI
import WidgetKit

/// The running session on the Lock Screen and in the Dynamic Island.
///
/// Every timer here is rendered by the system from dates. The app pushes nothing
/// while a session runs, so the timer on the Lock Screen cannot disagree with
/// the one in the app — they are computed from the same two facts.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            FocusLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(WidgetPalette.canvasDark.opacity(0.9))
                .activitySystemActionForegroundColor(KSEnergyState.focusing.sharedAccent)
                .widgetURL(DeepLink.session.url)
        } dynamicIsland: { context in
            let accent = FocusActivityStyle.accent(isStale: context.isStale)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.modeName, systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusTimerText(state: context.state, isStale: context.isStale)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let task = context.attributes.taskTitle {
                            Text(task)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        FocusProgressBar(state: context.state, isStale: context.isStale)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(accent)
            } compactTrailing: {
                FocusTimerText(state: context.state, isStale: context.isStale)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
                    .foregroundStyle(accent)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(accent)
            }
            .widgetURL(DeepLink.session.url)
            .keylineTint(accent)
        }
    }
}

enum FocusActivityStyle {
    /// Green while running, coral once the planned end has passed with the app
    /// closed — the same two states the in-app background moves between.
    static func accent(isStale: Bool) -> Color {
        (isStale ? KSEnergyState.overrun : KSEnergyState.focusing).sharedAccent
    }
}

struct FocusLockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(attributes.modeName, systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(FocusActivityStyle.accent(isStale: isStale))

                Spacer()

                FocusTimerText(state: state, isStale: isStale)
                    .font(.title.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            if let task = attributes.taskTitle {
                Text(task)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            FocusProgressBar(state: state, isStale: isStale)
        }
        .padding(16)
    }
}

/// Counts down to the planned end, or up from the start for Flowmodoro.
struct FocusTimerText: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale {
            Text("Time's up")
        } else if state.countsUp {
            Text(state.startedAt, style: .timer)
        } else {
            Text(timerInterval: state.timerRange, countsDown: true)
        }
    }
}

/// The depleting disc, flattened into a bar that drains on its own.
struct FocusProgressBar: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if state.countsUp {
            EmptyView()
        } else if isStale {
            ProgressView(value: 1)
                .tint(KSEnergyState.overrun.sharedAccent)
        } else {
            ProgressView(timerInterval: state.timerRange, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(KSEnergyState.focusing.sharedAccent)
        }
    }
}
