import AppIntents
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Configuration entity

struct QuickTimerEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Quick Timer")
    static var defaultQuery = QuickTimerEntityQuery()

    let id: String
    let duration: TimeInterval
    let title: String
    let isBuiltIn: Bool

    init(id: String, duration: TimeInterval, title: String, isBuiltIn: Bool) {
        self.id = id
        self.duration = duration
        self.title = title
        self.isBuiltIn = isBuiltIn
    }

    var displayRepresentation: DisplayRepresentation {
        if isBuiltIn {
            return DisplayRepresentation(title: "\(title)", subtitle: "Built-in preset")
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "Saved quick timer")
    }

    static func all() -> [QuickTimerEntity] {
        var result: [QuickTimerEntity] = []

        for duration in AppConstants.builtInQuickTimerDurations {
            result.append(
                QuickTimerEntity(
                    id: "builtin-\(Int(duration))",
                    duration: duration,
                    title: DurationFormatter.compactName(for: duration),
                    isBuiltIn: true
                )
            )
        }

        let snapshot = SharedStore.shared.load()
        for preset in snapshot.visibleQuickTimers {
            result.append(
                QuickTimerEntity(
                    id: "custom-\(preset.id.uuidString)",
                    duration: preset.duration,
                    title: DurationFormatter.compactName(for: preset.duration),
                    isBuiltIn: false
                )
            )
        }

        return result
    }

    static func defaultEntity() -> QuickTimerEntity {
        let entities = all()
        return entities.first(where: { abs($0.duration - 300) < 0.5 })
            ?? entities.first
            ?? QuickTimerEntity(id: "builtin-300", duration: 300, title: "5 min", isBuiltIn: true)
    }
}

struct QuickTimerEntityQuery: EntityQuery {
    typealias Entity = QuickTimerEntity

    func entities(for identifiers: [QuickTimerEntity.ID]) async throws -> [QuickTimerEntity] {
        let byID = Dictionary(uniqueKeysWithValues: QuickTimerEntity.all().map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    func suggestedEntities() async throws -> [QuickTimerEntity] {
        QuickTimerEntity.all()
    }

    func defaultResult() async -> QuickTimerEntity? {
        QuickTimerEntity.defaultEntity()
    }
}

struct QuickTimerConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Quick Timer"
    static var description = IntentDescription("Choose which saved quick timer this widget starts.")

    @Parameter(title: "Quick Timer")
    var quickTimer: QuickTimerEntity?

    init() {}
}

// MARK: - Timeline

struct QuickTimerEntry: TimelineEntry {
    let date: Date
    let configuration: QuickTimerConfigurationIntent
    let preset: QuickTimerEntity
    let timer: TimerItem?
}

struct QuickTimerProvider: AppIntentTimelineProvider {
    typealias Entry = QuickTimerEntry
    typealias Intent = QuickTimerConfigurationIntent

    func placeholder(in context: Context) -> QuickTimerEntry {
        QuickTimerEntry(
            date: .now,
            configuration: QuickTimerConfigurationIntent(),
            preset: QuickTimerEntity.defaultEntity(),
            timer: nil
        )
    }

    func snapshot(
        for configuration: QuickTimerConfigurationIntent,
        in context: Context
    ) async -> QuickTimerEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(
        for configuration: QuickTimerConfigurationIntent,
        in context: Context
    ) async -> Timeline<QuickTimerEntry> {
        let entry = makeEntry(configuration: configuration)
        var entries = [entry]

        // Queue a completed entry for the exact end time so the widget can flip
        // from the live countdown to Done without opening the app.
        if let timer = entry.timer,
           timer.state == .running,
           let endDate = timer.endDate,
           endDate > .now {
            var completed = timer
            completed.state = .completed
            completed.endDate = nil
            completed.remainingAtPause = 0
            completed.completedAt = endDate
            entries.append(
                QuickTimerEntry(
                    date: endDate.addingTimeInterval(1),
                    configuration: configuration,
                    preset: entry.preset,
                    timer: completed
                )
            )
        }

        return Timeline(entries: entries, policy: .after(Date().addingTimeInterval(300)))
    }

    private func makeEntry(configuration: QuickTimerConfigurationIntent) -> QuickTimerEntry {
        let preset = configuration.quickTimer ?? QuickTimerEntity.defaultEntity()
        let snapshot = SharedStore.shared.load()
        let timer = matchingTimer(in: snapshot, duration: preset.duration)
        return QuickTimerEntry(
            date: .now,
            configuration: configuration,
            preset: preset,
            timer: timer
        )
    }

    private func matchingTimer(
        in snapshot: SharedSnapshot,
        duration: TimeInterval
    ) -> TimerItem? {
        let candidates = snapshot.timers.filter {
            !$0.isDeleted && abs($0.totalDuration - duration) < 0.5
        }

        if let active = candidates
            .filter({ $0.state != .completed })
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first {
            // If the app is not running, the store can still say "running" after
            // the end date. Treat that as done so the widget shows Restart and X
            // instead of a frozen 00:00 countdown.
            if active.state == .running,
               let endDate = active.endDate,
               endDate <= .now {
                var completed = active
                completed.state = .completed
                completed.endDate = nil
                completed.remainingAtPause = 0
                completed.completedAt = endDate
                return completed
            }
            return active
        }

        return candidates
            .filter { $0.state == .completed }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
            .first
    }
}

// MARK: - Widget

struct QuickTimerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: AppConstants.quickTimerWidgetKind,
            intent: QuickTimerConfigurationIntent.self,
            provider: QuickTimerProvider()
        ) { entry in
            QuickTimerWidgetRootView(entry: entry)
        }
        .configurationDisplayName("Quick Timer")
        .description("Start, pause, or stop a saved quick timer.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

private struct QuickTimerWidgetRootView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickTimerEntry

    var body: some View {
        QuickTimerWidgetView(entry: entry)
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    WidgetPalette.background
                }
            }
    }
}

private struct QuickTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickTimerEntry

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                accessoryContent
            } else {
                smallContent
            }
        }
    }

    // MARK: Small Home Screen widget

    @ViewBuilder
    private var smallContent: some View {
        if let timer = entry.timer {
            if timer.state == .completed {
                completedContent(timer)
            } else {
                runningContent(timer)
            }
        } else {
            Button(intent: StartQuickTimerIntent(duration: entry.preset.duration)) {
                idleContent
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header(timer: nil)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(WidgetPalette.orange)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(WidgetPalette.orange.opacity(0.17)))
                    .overlay(Circle().stroke(WidgetPalette.orange.opacity(0.24), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text("TAP TO START")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(WidgetPalette.orange)
                    Text(entry.preset.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func runningContent(_ timer: TimerItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(timer: timer)

            Spacer(minLength: 0)

            countdownText(timer)

            HStack(spacing: 8) {
                controlButton(
                    systemName: timer.state == .running ? "pause.fill" : "play.fill",
                    tint: timer.state == .running ? WidgetPalette.blue : WidgetPalette.green,
                    intent: ToggleTimerPauseIntent(timerID: timer.id.uuidString)
                )

                controlButton(
                    systemName: "stop.fill",
                    tint: WidgetPalette.red,
                    intent: StopTimerIntent(timerID: timer.id.uuidString)
                )

                Spacer(minLength: 0)
            }
        }
    }

    private func completedContent(_ timer: TimerItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(timer: timer)

            Spacer(minLength: 0)

            Text("Done")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                controlButton(
                    systemName: "arrow.counterclockwise",
                    tint: WidgetPalette.orange,
                    intent: RestartTimerIntent(timerID: timer.id.uuidString)
                )

                controlButton(
                    systemName: "xmark",
                    tint: WidgetPalette.red,
                    intent: DismissTimerIntent(timerID: timer.id.uuidString)
                )

                Spacer(minLength: 0)
            }
        }
    }

    private func header(timer: TimerItem?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent(for: timer))

            Text(entry.preset.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            statusPill(for: timer)
        }
    }

    private func statusPill(for timer: TimerItem?) -> some View {
        Text(statusLabel(for: timer))
            .font(.system(size: 7, weight: .black, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(accent(for: timer))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent(for: timer).opacity(0.16)))
    }

    private func statusLabel(for timer: TimerItem?) -> String {
        guard let timer else { return "READY" }
        switch timer.state {
        case .running: return "LIVE"
        case .paused: return "PAUSED"
        case .completed: return "DONE"
        }
    }

    private func accent(for timer: TimerItem?) -> Color {
        guard let timer else { return WidgetPalette.orange }
        switch timer.state {
        case .running: return WidgetPalette.orange
        case .paused: return WidgetPalette.blue
        case .completed: return WidgetPalette.red
        }
    }

    private func countdownText(_ timer: TimerItem, size: CGFloat = 34) -> some View {
        let now = Date()
        return Group {
            if timer.state == .running, let endDate = timer.endDate, endDate > now {
                Text(timerInterval: now...endDate, countsDown: true)
            } else {
                Text(DurationFormatter.clockString(timer.remaining(at: now)))
            }
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
    }

    private func controlButton<Intent: AppIntent>(
        systemName: String,
        tint: Color,
        intent: Intent
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.17)))
                .overlay(Circle().stroke(tint.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Lock Screen accessory

    @ViewBuilder
    private var accessoryContent: some View {
        if let timer = entry.timer {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.preset.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    if timer.state == .completed {
                        Text("Done")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    } else {
                        countdownText(timer, size: 20)
                    }
                }

                Spacer(minLength: 0)

                if timer.state == .completed {
                    controlButton(
                        systemName: "arrow.counterclockwise",
                        tint: WidgetPalette.orange,
                        intent: RestartTimerIntent(timerID: timer.id.uuidString)
                    )
                    controlButton(
                        systemName: "xmark",
                        tint: WidgetPalette.red,
                        intent: DismissTimerIntent(timerID: timer.id.uuidString)
                    )
                } else {
                    controlButton(
                        systemName: timer.state == .running ? "pause.fill" : "play.fill",
                        tint: timer.state == .running ? WidgetPalette.blue : WidgetPalette.green,
                        intent: ToggleTimerPauseIntent(timerID: timer.id.uuidString)
                    )
                    controlButton(
                        systemName: "stop.fill",
                        tint: WidgetPalette.red,
                        intent: StopTimerIntent(timerID: timer.id.uuidString)
                    )
                }
            }
        } else {
            Button(intent: StartQuickTimerIntent(duration: entry.preset.duration)) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .black))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.preset.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Text("Tap to start")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .opacity(0.7)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
