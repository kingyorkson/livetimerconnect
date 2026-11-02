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
        var updatedTimer: TimerItem?
        let snapshot = SharedStore.shared.update { snapshot in
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
            updatedTimer = timer
            didChange = true
        }

        if didChange {
            if let updatedTimer {
                syncNotification(for: updatedTimer)
            }
            SharedCloudSync.push(snapshot)
            #if APP_PROCESS
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            DarwinNotificationCenter.shared.post(AppConstants.darwinStateChanged)
        }
        return didChange
    }

    /// Starts a timer from the Home Screen or Lock Screen widget. This runs as a
    /// LiveActivityIntent in the app process, so it can save the timer, start the
    /// Live Activity, schedule the notification, and publish to iCloud without
    /// bringing the full app UI forward.
    @discardableResult
    static func startTimer(duration: TimeInterval, now: Date = .now) async -> Bool {
        let safeDuration = min(max(1, duration.rounded()), AppConstants.maxTimerDuration)
        let timer = TimerItem(
            totalDuration: safeDuration,
            state: .running,
            endDate: now.addingTimeInterval(safeDuration),
            startedAt: now,
            updatedAt: now
        )

        let snapshot = SharedStore.shared.update { snapshot in
            snapshot.timers.insert(timer, at: 0)
            snapshot.updatedAt = now
        }

        NotificationSupport.scheduleTimer(timer, now: now)
        SharedCloudSync.push(snapshot)
        #if APP_PROCESS
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        DarwinNotificationCenter.shared.post(AppConstants.darwinStateChanged)
        await refreshLiveActivities(timerID: timer.id)
        return true
    }

    /// The intent can run while the SwiftUI app is not active, so it must also
    /// keep the timer's local notification in step with the new state.
    private static func syncNotification(for timer: TimerItem) {
        switch timer.state {
        case .running:
            NotificationSupport.scheduleTimer(timer)
        case .paused:
            NotificationSupport.cancelTimer(timer.id, includeDelivered: false)
        case .completed:
            // A timer that ended naturally leaves its already-scheduled end
            // notification and follow-up ring alone. Stop and dismiss mark the
            // timer deleted and cancel everything.
            if timer.isDeleted {
                NotificationSupport.cancelTimer(timer.id)
            }
        }
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

        // Keep a completed activity active instead of ending it. That is what
        // leaves the "Has ended" card on the Lock Screen with Restart and X
        // until the person explicitly dismisses it.
        if let current = activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) {
            await current.update(content)
            for extra in activities where extra.id != current.id {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            return
        }

        // Do not resurrect a completed activity that the person already swiped
        // away. Running and paused timers can request a fresh activity, which
        // also handles restarting after the card was dismissed.
        guard timer.state != .completed else { return }

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
