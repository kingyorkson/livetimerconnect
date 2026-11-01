import AppIntents
import Foundation

// These intents power the buttons on the Live Activity. LiveActivityIntent
// performs the work in the app without bringing it to the foreground.

struct ToggleTimerPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Timer"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(timerID: String) {
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        _ = TimerActionHandler.perform(.togglePause, timerID: timerID)
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(timerID: String) {
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        _ = TimerActionHandler.perform(.stop, timerID: timerID)
        return .result()
    }
}

struct RestartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Restart Timer"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(timerID: String) {
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        _ = TimerActionHandler.perform(.restart, timerID: timerID)
        return .result()
    }
}

struct DismissTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss Timer"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(timerID: String) {
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        _ = TimerActionHandler.perform(.dismiss, timerID: timerID)
        return .result()
    }
}
