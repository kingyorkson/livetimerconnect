import ActivityKit
import Foundation
import WidgetKit

enum TimerAction: String {
    case togglePause
    case stop
    case restart
    case dismiss
}

enum TimerActionHandler {
    @discardableResult
    static func perform(_ action: TimerAction, timerID: String, now: Date = .now) -> Bool {
        guard let uuid = UUID(uuidString: timerID) else { return false }

        var didChange = false
        SharedStore.shared.update { snapshot in
            guard let index = snapshot.timers.firstIndex(where: { $0.id == uuid }) else { return }
            var timer = snapshot.timers[index]

            switch action {
            case .togglePause:
                switch timer.state {
                case .running:
                    timer.remainingAtPause = timer.remaining(at: now)
                    timer.state = .paused
                    timer.endDate = nil
                case .paused:
                    let remaining = max(1, timer.remainingAtPause)
                    timer.state = .running
                    timer.endDate = now.addingTimeInterval(remaining)
                    timer.remainingAtPause = 0
                case .completed:
                    return
                }

            case .stop, .dismiss:
                timer.isDeleted = true
                timer.state = .completed
                timer.endDate = nil
                timer.completedAt = now
                timer.remainingAtPause = 0

            case .restart:
                timer.state = .running
                timer.startedAt = now
                timer.endDate = now.addingTimeInterval(timer.totalDuration)
                timer.remainingAtPause = 0
                timer.completedAt = nil
                timer.isDeleted = false
            }

            timer.updatedAt = now
            snapshot.timers[index] = timer
            snapshot.updatedAt = now
            didChange = true
        }

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
            DarwinNotificationCenter.shared.post(AppConstants.darwinStateChanged)
        }
        return didChange
    }

    /// Mutates the shared store and then updates the matching Live Activity.
    /// LiveActivityIntent runs in the app process even when the app is closed,
    /// so this keeps the Lock Screen controls responsive without waiting for
    /// the full SwiftUI app to come to the foreground.
    static func performAndRefresh(_ action: TimerAction, timerID: String) async {
        guard perform(action, timerID: timerID),
              let uuid = UUID(uuidString: timerID) else { return }
        await refreshLiveActivities(timerID: uuid)
    }

    private static func refreshLiveActivities(timerID: UUID) async {
        let snapshot = SharedStore.shared.load()
        guard let timer = snapshot.timers.first(where: { $0.id == timerID }) else { return }

        let state = TimerActivityAttributes.ContentState(
            state: timer.state,
            endDate: timer.endDate,
            remaining: timer.state == .paused ? timer.remainingAtPause : 0,
            totalDuration: timer.totalDuration,
            completedAt: timer.completedAt
        )
        let content = ActivityContent(
            state: state,
            staleDate: timer.state == .running ? timer.endDate : nil
        )
        let activities = Activity<TimerActivityAttributes>.activities
            .filter { $0.attributes.timerID == timerID }

        if timer.isDeleted {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        guard timer.state != .completed else {
            for activity in activities {
                await activity.end(content, dismissalPolicy: .default)
            }
            return
        }

        if let current = activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) {
            await current.update(content)
            for extra in activities where extra.id != current.id {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        // Restarting an ended timer needs a fresh activity. LiveActivityIntent
        // is allowed to start one without bringing the app to the foreground.
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity<TimerActivityAttributes>.request(
            attributes: TimerActivityAttributes(
                timerID: timer.id,
                title: timer.displayName,
                totalDuration: timer.totalDuration
            ),
            content: content,
            pushType: nil
        )
    }
}
