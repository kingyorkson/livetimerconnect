import Foundation

enum AppConstants {
    static let appGroupID = "group.com.kingyorkson.LiveTimerConnect"
    static let snapshotKey = "liveTimerConnect.snapshot.v1"
    static let iCloudSnapshotKey = "liveTimerConnect.snapshot.v1"

    static let darwinStateChanged = "com.kingyorkson.LiveTimerConnect.stateChanged"

    static let maxTimerDuration: TimeInterval = 2_591_999
    static let builtInQuickTimerDurations: [TimeInterval] = [60, 120, 180, 300, 600, 1_800]

    static let timerNotificationPrefix = "timer-"
    static let alarmNotificationPrefix = "alarm-"
    static let notificationRingSuffix = "-ring"
    static let notificationRingDelay: TimeInterval = 30
    static let alarmRingCount = 2
    static let alarmSnoozeInterval: TimeInterval = 9 * 60
    static let timerCategory = "TIMER_ENDED"
    static let alarmCategory = "ALARM"
    static let customSoundName = "ding.wav"
    static let quickTimerWidgetKind = "QuickTimerWidget"
    static let appDisplayName = "Live Timer Connect"

    static let repositoryURL = URL(string: "https://github.com/kingyorkson/livetimerconnect")!
}
