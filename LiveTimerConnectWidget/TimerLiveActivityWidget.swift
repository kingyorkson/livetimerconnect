import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

enum WidgetPalette {
    static let background = Color(red: 0.045, green: 0.048, blue: 0.08)
    static let orange = Color(red: 1.0, green: 0.58, blue: 0.18)
    static let blue = Color(red: 0.35, green: 0.66, blue: 1.0)
    static let green = Color(red: 0.30, green: 0.86, blue: 0.55)
    static let red = Color(red: 1.0, green: 0.34, blue: 0.36)
    static let secondary = Color.white.opacity(0.56)
}

/// The app updates a finished Live Activity to the completed state when it is
/// running. If the app is not running, the activity becomes stale at its
/// `endDate`; treating a stale or expired running activity as completed keeps
/// the Lock Screen card useful (Restart and X) without a server push.
private func displayState(for context: ActivityViewContext<TimerActivityAttributes>) -> TimerState {
    if context.state.state == .completed {
        return .completed
    }
    if context.state.state == .running,
       let endDate = context.state.endDate,
       endDate <= .now {
        return .completed
    }
    if context.isStale {
        return .completed
    }
    return context.state.state
}

struct TimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            TimerLockScreenView(context: context)
                .activityBackgroundTint(WidgetPalette.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WidgetPalette.orange)
                        Text(context.attributes.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ActivityStatusBadge(state: displayState(for: context))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 10) {
                        CountdownText(context: context, size: 24)
                        Spacer(minLength: 8)
                        ActivityControls(context: context, size: 32)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetPalette.orange)
            } compactTrailing: {
                CompactCountdown(context: context)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetPalette.orange)
            }
            .keylineTint(WidgetPalette.orange)
        }
    }
}

private struct TimerLockScreenView: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetPalette.orange)

                Text(context.attributes.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 6)

                ActivityStatusBadge(state: displayState(for: context))
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if displayState(for: context) == .completed {
                        Text("Has ended")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        CountdownText(context: context, size: 38)
                    }

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                ActivityControls(context: context, size: 38)
            }
        }
        .padding(16)
    }

    private var subtitle: String {
        switch displayState(for: context) {
        case .running:
            if let endDate = context.state.endDate {
                return "Ends at \(endDate.formatted(date: .omitted, time: .shortened))"
            }
            return "Counting down"
        case .paused:
            return "Paused with \(DurationFormatter.clockString(context.state.remaining)) remaining"
        case .completed:
            return "\(context.attributes.title) has ended."
        }
    }
}

private struct CountdownText: View {
    let context: ActivityViewContext<TimerActivityAttributes>
    let size: CGFloat

    var body: some View {
        let now = Date()
        Group {
            switch displayState(for: context) {
            case .running:
                if let endDate = context.state.endDate, endDate > now {
                    Text(timerInterval: now...endDate, countsDown: true)
                } else {
                    Text("00:00")
                }
            case .paused:
                Text(DurationFormatter.clockString(context.state.remaining))
            case .completed:
                Text("00:00")
            }
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }
}

private struct CompactCountdown: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        let now = Date()
        Group {
            switch displayState(for: context) {
            case .running:
                if let endDate = context.state.endDate, endDate > now {
                    Text(timerInterval: now...endDate, countsDown: true)
                } else {
                    Text("0:00")
                }
            case .paused:
                Text(DurationFormatter.clockString(context.state.remaining))
            case .completed:
                Text("Ended")
            }
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: 58)
    }
}

private struct ActivityStatusBadge: View {
    let state: TimerState

    private var label: String {
        switch state {
        case .running: return "LIVE"
        case .paused: return "PAUSED"
        case .completed: return "ENDED"
        }
    }

    private var tint: Color {
        switch state {
        case .running: return WidgetPalette.orange
        case .paused: return WidgetPalette.blue
        case .completed: return WidgetPalette.red
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}

private struct ActivityControls: View {
    let context: ActivityViewContext<TimerActivityAttributes>
    let size: CGFloat

    private var timerID: String {
        context.attributes.timerID.uuidString
    }

    var body: some View {
        HStack(spacing: 8) {
            if displayState(for: context) == .completed {
                ActivityIntentButton(
                    systemName: "arrow.counterclockwise",
                    tint: WidgetPalette.orange,
                    size: size,
                    intent: RestartTimerIntent(timerID: timerID)
                )

                ActivityIntentButton(
                    systemName: "xmark",
                    tint: WidgetPalette.red,
                    size: size,
                    intent: DismissTimerIntent(timerID: timerID)
                )
            } else {
                ActivityIntentButton(
                    systemName: displayState(for: context) == .running ? "pause.fill" : "play.fill",
                    tint: displayState(for: context) == .running ? WidgetPalette.blue : WidgetPalette.green,
                    size: size,
                    intent: ToggleTimerPauseIntent(timerID: timerID)
                )

                ActivityIntentButton(
                    systemName: "stop.fill",
                    tint: WidgetPalette.red,
                    size: size,
                    intent: StopTimerIntent(timerID: timerID)
                )
            }
        }
    }
}

private struct ActivityIntentButton<Intent: AppIntent>: View {
    let systemName: String
    let tint: Color
    let size: CGFloat
    let intent: Intent

    var body: some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(tint.opacity(0.17)))
                .overlay(Circle().stroke(tint.opacity(0.23), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
