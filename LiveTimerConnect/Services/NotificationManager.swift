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
    private(set) var criticalAlertsAuthorized = false

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

    // MARK: - Authorization

    func requestAuthorization(requestCritical: Bool = false) async -> UNAuthorizationStatus {
        let current = await center.notificationSettings()
        if current.authorizationStatus == .notDetermined {
            var granted = false
            do {
                granted = try await center.requestAuthorization(
                    options: [.alert, .sound, .badge, .timeSensitive, .criticalAlert]
                )
            } catch {
                granted = false
            }

            if !granted {
                // A sideloaded build can lose the critical-alerts entitlement.
                // Standard notifications still work, so ask for those instead.
                _ = try? await center.requestAuthorization(
                    options: [.alert, .sound, .badge, .timeSensitive]
                )
            }
        } else if requestCritical && current.criticalAlertSetting != .enabled {
            // Existing installs may already have standard notifications. The
            // Settings button makes one explicit attempt to add critical alerts.
            _ = try? await center.requestAuthorization(options: [.criticalAlert])
        }

        let settings = await center.notificationSettings()
        updateCriticalSetting(settings)
        return settings.authorizationStatus
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        updateCriticalSetting(settings)
        return settings.authorizationStatus
    }

    private func updateCriticalSetting(_ settings: UNNotificationSettings) {
        let enabled = settings.criticalAlertSetting == .enabled
        criticalAlertsAuthorized = enabled
        NotificationSupport.criticalAlertsAuthorized = enabled
    }

    // MARK: - Reconciliation

    func reconcile(_ snapshot: SharedSnapshot) {
        let now = Date()

        for timer in snapshot.timers {
            if timer.isDeleted {
                NotificationSupport.cancelTimer(timer.id)
            } else if timer.state == .paused {
                NotificationSupport.cancelTimer(timer.id, includeDelivered: false)
            } else if timer.state == .running,
                      let endDate = timer.endDate,
                      endDate > now {
                NotificationSupport.scheduleTimer(timer, now: now)
            }
            // Completed timers keep the notification and follow-up ring that
            // were scheduled before they ended. Stop/dismiss cancels them.
        }

        for alarm in snapshot.alarms {
            if alarm.isDeleted || !alarm.isEnabled {
                NotificationSupport.cancelAlarm(id: alarm.id)
            } else {
                scheduleAlarm(alarm)
            }
        }
    }

    func cancelTimer(id: UUID) {
        NotificationSupport.cancelTimer(id)
    }

    func cancelAlarm(id: UUID) {
        NotificationSupport.cancelAlarm(id)
    }

    // MARK: - Scheduling

    private func scheduleAlarm(_ alarm: AlarmItem) {
        let baseIdentifier = AppConstants.alarmNotificationPrefix + alarm.id.uuidString
        let ringIdentifiers = NotificationSupport.alarmRingIdentifiers(for: alarm.id)

        // Replacing the base request is fine, but never remove a delivered
        // alarm while reconciliation runs. That would clear a ringing alert
        // just because the app came to the foreground.
        center.removePendingNotificationRequests(withIdentifiers: [baseIdentifier] + ringIdentifiers)

        let content = NotificationSupport.alarmContent(
            label: alarm.displayLabel,
            timeText: alarm.timeText,
            alarmID: alarm.id,
            body: "\(alarm.timeText) alarm is ringing."
        )
        let next = nextFireDate(for: alarm)
        let interval = max(1, next.timeIntervalSinceNow)

        if alarm.repeatsDaily {
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            components.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(
                identifier: baseIdentifier,
                content: content,
                trigger: trigger
            ))
        } else {
            let baseTrigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            center.add(UNNotificationRequest(
                identifier: baseIdentifier,
                content: content,
                trigger: baseTrigger
            ))
        }

        // A few extra rings make the alarm feel like a native alarm that keeps
        // going until it is stopped. The long custom sound covers each 30-second
        // gap. Stopping or snoozing cancels the remaining rings without
        // touching a repeating alarm's request for tomorrow.
        for (index, identifier) in ringIdentifiers.enumerated() {
            let ringContent = NotificationSupport.alarmContent(
                label: alarm.displayLabel,
                timeText: alarm.timeText,
                alarmID: alarm.id,
                body: "\(alarm.timeText) alarm is still ringing."
            )
            let delay = AppConstants.notificationRingDelay * TimeInterval(index + 1)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval + delay,
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: identifier,
                content: ringContent,
                trigger: trigger
            ))
        }
    }

    private func nextFireDate(for alarm: AlarmItem) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: .now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0
        var next = calendar.date(from: components) ?? .now
        if next <= .now {
            next = calendar.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86_400)
        }
        return next
    }

    private func scheduleSnooze(userInfo: [AnyHashable: Any]) {
        guard let alarmIDString = userInfo["alarmID"] as? String,
              let alarmID = UUID(uuidString: alarmIDString) else { return }

        let label = userInfo["alarmLabel"] as? String ?? "Alarm"
        let timeText = userInfo["alarmTime"] as? String ?? "Snoozed"
        let content = NotificationSupport.alarmContent(
            label: label,
            timeText: timeText,
            alarmID: alarmID,
            body: "Snoozed alarm is ringing."
        )

        let identifier = NotificationSupport.snoozeIdentifier(for: alarmID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: AppConstants.alarmSnoozeInterval,
            repeats: false
        )
        center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        ))
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
            title: "Snooze 9 minutes"
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
                NotificationSupport.cancelTimer(timerID)
                onTimerAction?(timerID, .restart)
            case ActionID.timerStop:
                NotificationSupport.cancelTimer(timerID)
                onTimerAction?(timerID, .stop)
            default:
                break
            }
        } else if userInfo["kind"] as? String == "alarm",
                  let alarmIDString = userInfo["alarmID"] as? String,
                  let alarmID = UUID(uuidString: alarmIDString) {
            switch response.actionIdentifier {
            case ActionID.alarmSnooze:
                NotificationSupport.stopAlarmDelivered(alarmID)
                NotificationSupport.stopAlarmRing(alarmID)
                scheduleSnooze(userInfo: userInfo)
            case ActionID.alarmStop:
                NotificationSupport.stopAlarmDelivered(alarmID)
                NotificationSupport.stopAlarmRing(alarmID)
            default:
                break
            }
        }

        completionHandler()
    }
}
