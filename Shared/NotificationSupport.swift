import Foundation
import UserNotifications

/// Notification scheduling shared by the app, Live Activity intents, and the
/// widget's start button. Keeping this in one place means a timer started from
/// the Lock Screen or Home Screen gets the same critical alert and loud sound
/// as one started inside the app.
enum NotificationSupport {
    private static let criticalAlertsKey = "liveTimerConnect.criticalAlertsAuthorized"

    /// Cached result of `UNNotificationSettings.criticalAlertSetting`. Critical
    /// alerts need Apple's restricted entitlement. When it is unavailable we
    /// fall back to a normal, time-sensitive notification and the same sound.
    static var criticalAlertsAuthorized: Bool {
        get { UserDefaults.standard.bool(forKey: criticalAlertsKey) }
        set { UserDefaults.standard.set(newValue, forKey: criticalAlertsKey) }
    }

    static func sound() -> UNNotificationSound {
        let name = UNNotificationSoundName(rawValue: AppConstants.customSoundName)
        if criticalAlertsAuthorized {
            return .criticalSoundNamed(name, withAudioVolume: 1.0)
        }
        return UNNotificationSound(named: name)
    }

    static func interruptionLevel() -> UNNotificationInterruptionLevel {
        criticalAlertsAuthorized ? .critical : .timeSensitive
    }

    static func timerIdentifiers(for id: UUID) -> [String] {
        let base = AppConstants.timerNotificationPrefix + id.uuidString
        return [base, base + AppConstants.notificationRingSuffix]
    }

    static func alarmIdentifiers(for id: UUID) -> [String] {
        let base = AppConstants.alarmNotificationPrefix + id.uuidString
        return [base] + alarmRingIdentifiers(for: id)
    }

    static func alarmRingIdentifiers(for id: UUID) -> [String] {
        let base = AppConstants.alarmNotificationPrefix + id.uuidString + AppConstants.notificationRingSuffix
        return (0..<AppConstants.alarmRingCount).map { index in
            index == 0 ? base : base + "-\(index + 1)"
        }
    }

    static func snoozeIdentifier(for id: UUID) -> String {
        "alarm-snooze-" + id.uuidString
    }

    // MARK: - Timers

    static func scheduleTimer(_ timer: TimerItem, now: Date = .now) {
        guard !timer.isDeleted,
              timer.state == .running,
              let endDate = timer.endDate,
              endDate > now else {
            cancelTimer(timer.id, includeDelivered: timer.isDeleted)
            return
        }

        let center = UNUserNotificationCenter.current()
        let identifiers = timerIdentifiers(for: timer.id)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)

        let interval = max(1, endDate.timeIntervalSince(now))
        let first = UNNotificationRequest(
            identifier: identifiers[0],
            content: timerContent(for: timer, body: "\(timer.displayName) has ended"),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        center.add(first)

        // One extra ring keeps the alert going for roughly a minute when the
        // phone is ignored. Stop, dismiss, or restart cancels this follow-up.
        let followUp = UNNotificationRequest(
            identifier: identifiers[1],
            content: timerContent(for: timer, body: "\(timer.displayName) is still ringing"),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval + AppConstants.notificationRingDelay,
                repeats: false
            )
        )
        center.add(followUp)
    }

    static func cancelTimer(_ id: UUID, includeDelivered: Bool = true) {
        let center = UNUserNotificationCenter.current()
        let identifiers = timerIdentifiers(for: id)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        if includeDelivered {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private static func timerContent(
        for timer: TimerItem,
        body: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = timer.displayName
        content.body = body
        content.sound = sound()
        content.categoryIdentifier = AppConstants.timerCategory
        content.threadIdentifier = "timers"
        content.interruptionLevel = interruptionLevel()
        content.relevanceScore = 1
        content.userInfo = [
            "kind": "timer",
            "timerID": timer.id.uuidString
        ]
        return content
    }

    // MARK: - Alarms

    static func cancelAlarm(_ id: UUID, includeDelivered: Bool = true) {
        let center = UNUserNotificationCenter.current()
        let identifiers = alarmIdentifiers(for: id) + [snoozeIdentifier(for: id)]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        if includeDelivered {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    /// Stops the current ring without removing the recurring alarm request that
    /// is already scheduled for tomorrow. The one-shot ring follow-up and any
    /// pending snooze are cancelled.
    static func stopAlarmRing(_ id: UUID) {
        let center = UNUserNotificationCenter.current()
        let rings = alarmRingIdentifiers(for: id)
        let snooze = snoozeIdentifier(for: id)
        center.removeDeliveredNotifications(withIdentifiers: rings)
        center.removePendingNotificationRequests(withIdentifiers: rings + [snooze])
        center.removeDeliveredNotifications(withIdentifiers: [snooze])
    }

    static func stopAlarmDelivered(_ id: UUID) {
        let center = UNUserNotificationCenter.current()
        let base = AppConstants.alarmNotificationPrefix + id.uuidString
        center.removeDeliveredNotifications(withIdentifiers: [base])
    }

    static func alarmContent(
        label: String,
        timeText: String,
        alarmID: UUID,
        body: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = label
        content.body = body
        content.sound = sound()
        content.categoryIdentifier = AppConstants.alarmCategory
        content.threadIdentifier = "alarms"
        content.interruptionLevel = interruptionLevel()
        content.relevanceScore = 1
        content.userInfo = [
            "kind": "alarm",
            "alarmID": alarmID.uuidString,
            "alarmLabel": label,
            "alarmTime": timeText
        ]
        return content
    }
}
