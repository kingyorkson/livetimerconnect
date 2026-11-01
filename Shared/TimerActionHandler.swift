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
}
