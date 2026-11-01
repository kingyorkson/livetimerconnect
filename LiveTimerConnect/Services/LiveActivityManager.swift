import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activities: [UUID: Activity<TimerActivityAttributes>] = [:]
    private var lastStates: [UUID: TimerActivityAttributes.ContentState] = [:]
    private var endedIDs = Set<UUID>()

    private init() {
        adoptExistingActivities()
    }

    func reconcile(_ timers: [TimerItem], now: Date = .now) async {
        let validTimers = timers.filter { !$0.isDeleted }
        let validIDs = Set(validTimers.map(\.id))

        let removedIDs = activities.keys.filter { !validIDs.contains($0) }
        for id in removedIDs {
            if let activity = activities[id] {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            activities[id] = nil
            lastStates[id] = nil
            endedIDs.remove(id)
        }

        for timer in validTimers {
            let state = contentState(for: timer, now: now)

            switch timer.state {
            case .running, .paused:
                endedIDs.remove(timer.id)

                if let activity = activities[timer.id], activity.activityState == .active || activity.activityState == .stale {
                    if lastStates[timer.id] != state {
                        lastStates[timer.id] = state
                        let content = ActivityContent(
                            state: state,
                            staleDate: timer.state == .running ? timer.endDate : nil
                        )
                        await activity.update(content)
                    }
                } else {
                    activities[timer.id] = nil
                    lastStates[timer.id] = nil
                    await requestActivity(for: timer, state: state)
                }

            case .completed:
                endedIDs.insert(timer.id)
                if let activity = activities[timer.id] {
                    activities[timer.id] = nil
                    lastStates[timer.id] = nil
                    let content = ActivityContent(state: state, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .default)
                }
            }
        }

        endedIDs.formIntersection(validIDs)
    }

    func endAll() async {
        for (_, activity) in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activities.removeAll()
        lastStates.removeAll()
        endedIDs.removeAll()
    }

    private func adoptExistingActivities() {
        for activity in Activity<TimerActivityAttributes>.activities {
            guard activity.activityState == .active || activity.activityState == .stale else { continue }
            activities[activity.attributes.timerID] = activity
        }
    }

    private func requestActivity(
        for timer: TimerItem,
        state: TimerActivityAttributes.ContentState
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TimerActivityAttributes(
            timerID: timer.id,
            title: timer.displayName,
            totalDuration: timer.totalDuration
        )
        let content = ActivityContent(
            state: state,
            staleDate: timer.state == .running ? timer.endDate : nil
        )

        do {
            let activity = try Activity<TimerActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activities[timer.id] = activity
            lastStates[timer.id] = state
        } catch {
            // Live Activities can be disabled per app or unavailable on the
            // current device; timers and notifications continue to work.
            print("Live Activity request failed: \(error.localizedDescription)")
        }
    }

    private func contentState(
        for timer: TimerItem,
        now: Date
    ) -> TimerActivityAttributes.ContentState {
        TimerActivityAttributes.ContentState(
            state: timer.state,
            endDate: timer.endDate,
            remaining: timer.state == .paused ? timer.remainingAtPause : 0,
            totalDuration: timer.totalDuration,
            completedAt: timer.completedAt
        )
    }
}
