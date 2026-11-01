import Foundation
import UserNotifications
import AVFoundation

enum TimerNotificationAction {
    case restart
    case stop
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var onTimerAction: ((UUID, TimerNotificationAction) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var previewPlayer: AVAudioPlayer?

    private enum ActionID {
        static let timerRestart = "TIMER_RESTART"
        static let timerStop = "TIMER_STOP"
        static let alarmSnooze = "ALARM_SNOOZE"
        static let alarmStop = "ALARM_STOP"
    }

    private override init() {
        super.init()
    }

    func configure() {
        center.delegate = self
        registerCategories()
    }

    func requestAuthorization() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
        }
        return await center.notificationSettings().authorizationStatus
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func reconcile(_ snapshot: SharedSnapshot) {
        let now = Date()

        for timer in snapshot.timers {
            let identifier = AppConstants.timerNotificationPrefix + timer.id.uuidString
            if timer.isDeleted || timer.state == .paused {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
            } else if timer.state == .running, let endDate = timer.endDate, endDate > now {
                scheduleTimer(timer)
            }
        }

        for alarm in snapshot.alarms {
            let identifier = AppConstants.alarmNotificationPrefix + alarm.id.uuidString
            if alarm.isDeleted || !alarm.isEnabled {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
            } else {
                scheduleAlarm(alarm)
            }
        }
    }

    func cancelTimer(id: UUID) {
        let identifier = AppConstants.timerNotificationPrefix + id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAlarm(id: UUID) {
        let identifier = AppConstants.alarmNotificationPrefix + id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Scheduling

    private func scheduleTimer(_ timer: TimerItem) {
        guard let endDate = timer.endDate else { return }
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = timer.displayName
        content.body = "\(timer.displayName) has ended"
        content.sound = notificationSound()
        content.categoryIdentifier = AppConstants.timerCategory
        content.threadIdentifier = "timers"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.userInfo = [
            "kind": "timer",
            "timerID": timer.id.uuidString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: AppConstants.timerNotificationPrefix + timer.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func scheduleAlarm(_ alarm: AlarmItem) {
        let content = UNMutableNotificationContent()
        content.title = alarm.displayLabel
        content.body = "\(alarm.timeText) alarm is ringing."
        content.sound = notificationSound()
        content.categoryIdentifier = AppConstants.alarmCategory
        content.threadIdentifier = "alarms"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.userInfo = [
            "kind": "alarm",
            "alarmID": alarm.id.uuidString,
            "alarmLabel": alarm.displayLabel,
            "alarmTime": alarm.timeText
        ]

        let trigger: UNNotificationTrigger
        if alarm.repeatsDaily {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: .now)
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            var next = calendar.date(from: components) ?? .now
            if next <= .now {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86_400)
            }
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, next.timeIntervalSinceNow),
                repeats: false
            )
        }

        let request = UNNotificationRequest(
            identifier: AppConstants.alarmNotificationPrefix + alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func scheduleSnooze(userInfo: [AnyHashable: Any]) {
        let content = UNMutableNotificationContent()
        content.title = userInfo["alarmLabel"] as? String ?? "Alarm"
        content.body = "Snoozed alarm is ringing."
        content.sound = notificationSound()
        content.categoryIdentifier = AppConstants.alarmCategory
        content.threadIdentifier = "alarms"
        content.interruptionLevel = .timeSensitive
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "alarm-snooze-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func notificationSound() -> UNNotificationSound {
        UNNotificationSound(
            named: UNNotificationSoundName(rawValue: AppConstants.customSoundName)
        )
    }

    private func registerCategories() {
        let timerRestart = UNNotificationAction(
            identifier: ActionID.timerRestart,
            title: "Restart"
        )
        let timerStop = UNNotificationAction(
            identifier: ActionID.timerStop,
            title: "Stop",
            options: [.destructive]
        )
        let timerCategory = UNNotificationCategory(
            identifier: AppConstants.timerCategory,
            actions: [timerRestart, timerStop],
            intentIdentifiers: [],
            options: []
        )

        let alarmSnooze = UNNotificationAction(
            identifier: ActionID.alarmSnooze,
            title: "Snooze 5 minutes"
        )
        let alarmStop = UNNotificationAction(
            identifier: ActionID.alarmStop,
            title: "Stop",
            options: [.destructive]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: AppConstants.alarmCategory,
            actions: [alarmStop, alarmSnooze],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([timerCategory, alarmCategory])
    }

    // MARK: - Preview

    func playSoundPreview() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        guard let url = Bundle.main.url(forResource: "ding", withExtension: "wav") else {
            return
        }
        previewPlayer = try? AVAudioPlayer(contentsOf: url)
        previewPlayer?.volume = 1.0
        previewPlayer?.play()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let timerIDString = userInfo["timerID"] as? String,
           let timerID = UUID(uuidString: timerIDString) {
            switch response.actionIdentifier {
            case ActionID.timerRestart:
                center.removeDeliveredNotifications(
                    withIdentifiers: [AppConstants.timerNotificationPrefix + timerID.uuidString]
                )
                onTimerAction?(timerID, .restart)
            case ActionID.timerStop:
                onTimerAction?(timerID, .stop)
            default:
                break
            }
        } else if userInfo["kind"] as? String == "alarm" {
            if response.actionIdentifier == ActionID.alarmSnooze {
                scheduleSnooze(userInfo: userInfo)
            }
        }

        completionHandler()
    }
}
