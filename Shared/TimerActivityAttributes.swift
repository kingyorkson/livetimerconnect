import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var state: TimerState
        var endDate: Date?
        var remaining: TimeInterval
        var totalDuration: TimeInterval
        var completedAt: Date?
    }

    var timerID: UUID
    var title: String
    var totalDuration: TimeInterval
}
