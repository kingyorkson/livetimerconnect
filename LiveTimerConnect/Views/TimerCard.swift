import SwiftUI

struct TimerCard: View {
    @EnvironmentObject private var model: AppModel

    let timer: TimerItem
    let now: Date

    private var remaining: TimeInterval {
        timer.remaining(at: now)
    }

    private var progress: Double {
        timer.progress(at: now)
    }

    private var accent: Color {
        switch timer.state {
        case .running: return AppTheme.orange
        case .paused: return AppTheme.blue
        case .completed: return AppTheme.red
        }
    }

    private var statusText: String {
        switch timer.state {
        case .running: return "RUNNING"
        case .paused: return "PAUSED"
        case .completed: return "ENDED"
        }
    }

    private var detailText: String {
        switch timer.state {
        case .running:
            if let endDate = timer.endDate {
                return "Ends at \(endDate.formatted(date: .omitted, time: .shortened))"
            }
            return "Counting down"
        case .paused:
            return "\(DurationFormatter.clockString(remaining)) left when paused"
        case .completed:
            if let completedAt = timer.completedAt {
                return "Ended at \(completedAt.formatted(date: .omitted, time: .shortened))"
            }
            return "Has ended"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timer.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(DurationFormatter.totalDurationString(timer.totalDuration)) total · \(detailText)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)

                Text(statusText)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent.opacity(0.13)))
                    .overlay(Capsule().stroke(accent.opacity(0.2), lineWidth: 1))
            }

            HStack(alignment: .center, spacing: 12) {
                Text(DurationFormatter.clockString(remaining))
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: timer.state == .running))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                controls
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * progress))
                }
            }
            .frame(height: 6)

            if timer.state == .completed {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(timer.displayName) has ended")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(AppTheme.red.opacity(0.9))
            }
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.10), AppTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 8) {
            if timer.state == .completed {
                CircleIconButton(
                    systemName: "arrow.counterclockwise",
                    tint: AppTheme.orange,
                    background: AppTheme.orange.opacity(0.12)
                ) {
                    model.restartTimer(timer.id)
                }

                CircleIconButton(
                    systemName: "xmark",
                    tint: AppTheme.red,
                    background: AppTheme.red.opacity(0.12)
                ) {
                    model.dismissTimer(timer.id)
                }
            } else {
                CircleIconButton(
                    systemName: timer.state == .running ? "pause.fill" : "play.fill",
                    tint: timer.state == .running ? AppTheme.blue : AppTheme.green,
                    background: (timer.state == .running ? AppTheme.blue : AppTheme.green).opacity(0.12)
                ) {
                    model.togglePause(timer.id)
                }

                CircleIconButton(
                    systemName: "stop.fill",
                    tint: AppTheme.red,
                    background: AppTheme.red.opacity(0.12)
                ) {
                    model.stopTimer(timer.id)
                }
            }
        }
    }
}
