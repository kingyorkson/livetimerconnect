import Foundation

// MARK: - Timer state

enum TimerState: String, Codable, CaseIterable, Hashable {
    case running
    case paused
    case completed
}

// MARK: - Sync protocol

protocol SyncableItem: Identifiable, Codable, Equatable where ID == UUID {
    var updatedAt: Date { get }
    var isDeleted: Bool { get }
}

// MARK: - Live timer

struct TimerItem: SyncableItem, Hashable {
    var id: UUID
    var totalDuration: TimeInterval
    var state: TimerState
    var endDate: Date?
    var remainingAtPause: TimeInterval
    var startedAt: Date
    var completedAt: Date?
    var updatedAt: Date
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        totalDuration: TimeInterval,
        state: TimerState = .running,
        endDate: Date? = nil,
        remainingAtPause: TimeInterval = 0,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.totalDuration = totalDuration
        self.state = state
        self.endDate = endDate
        self.remainingAtPause = remainingAtPause
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    var displayName: String {
        DurationFormatter.timerName(for: totalDuration)
    }

    var isActive: Bool {
        !isDeleted && (state == .running || state == .paused)
    }

    var isEnded: Bool {
        !isDeleted && state == .completed
    }

    func remaining(at date: Date) -> TimeInterval {
        switch state {
        case .running:
            guard let endDate else { return 0 }
            return max(0, endDate.timeIntervalSince(date))
        case .paused:
            return max(0, remainingAtPause)
        case .completed:
            return 0
        }
    }

    func progress(at date: Date) -> Double {
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / totalDuration))
    }
}

// MARK: - Quick timer preset

struct QuickTimer: SyncableItem, Hashable {
    var id: UUID
    var duration: TimeInterval
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        duration: TimeInterval,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.duration = duration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    var displayName: String {
        DurationFormatter.timerName(for: duration)
    }
}

// MARK: - Alarm

struct AlarmItem: SyncableItem, Hashable {
    var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var isEnabled: Bool
    var repeatsDaily: Bool
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        label: String = "Alarm",
        isEnabled: Bool = true,
        repeatsDaily: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = isEnabled
        self.repeatsDaily = repeatsDaily
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    var timeText: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Alarm" : trimmed
    }

    var repeatText: String {
        repeatsDaily ? "Every day" : "Once"
    }

    var minutesSinceMidnight: Int {
        (hour * 60) + minute
    }
}

// MARK: - Synced snapshot

struct SharedSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var timers: [TimerItem]
    var quickTimers: [QuickTimer]
    var alarms: [AlarmItem]
    var updatedAt: Date

    init(
        schemaVersion: Int = 1,
        timers: [TimerItem] = [],
        quickTimers: [QuickTimer] = [],
        alarms: [AlarmItem] = [],
        updatedAt: Date = .distantPast
    ) {
        self.schemaVersion = schemaVersion
        self.timers = timers
        self.quickTimers = quickTimers
        self.alarms = alarms
        self.updatedAt = updatedAt
    }

    var activeTimers: [TimerItem] {
        timers
            .filter(\.isActive)
            .sorted { $0.startedAt > $1.startedAt }
    }

    var endedTimers: [TimerItem] {
        timers
            .filter(\.isEnded)
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    var visibleQuickTimers: [QuickTimer] {
        quickTimers
            .filter { !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var visibleAlarms: [AlarmItem] {
        alarms
            .filter { !$0.isDeleted }
            .sorted { $0.minutesSinceMidnight < $1.minutesSinceMidnight }
    }

    func hasSameContent(as other: SharedSnapshot) -> Bool {
        Self.sortedByID(timers) == Self.sortedByID(other.timers)
            && Self.sortedByID(quickTimers) == Self.sortedByID(other.quickTimers)
            && Self.sortedByID(alarms) == Self.sortedByID(other.alarms)
    }

    private static func sortedByID<T: SyncableItem>(_ items: [T]) -> [T] {
        items.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func merged(with incoming: SharedSnapshot) -> SharedSnapshot {
        SharedSnapshot(
            schemaVersion: max(schemaVersion, incoming.schemaVersion),
            timers: Self.mergeItems(timers, incoming.timers),
            quickTimers: Self.mergeItems(quickTimers, incoming.quickTimers),
            alarms: Self.mergeItems(alarms, incoming.alarms),
            updatedAt: max(updatedAt, incoming.updatedAt)
        )
    }

    mutating func prune(now: Date = .now) {
        let tombstoneCutoff = now.addingTimeInterval(-7 * 86_400)
        let completedCutoff = now.addingTimeInterval(-2 * 86_400)

        timers.removeAll { timer in
            (timer.isDeleted && timer.updatedAt < tombstoneCutoff)
                || (timer.state == .completed && !timer.isDeleted && (timer.completedAt ?? timer.updatedAt) < completedCutoff)
        }
        quickTimers.removeAll { $0.isDeleted && $0.updatedAt < tombstoneCutoff }
        alarms.removeAll { $0.isDeleted && $0.updatedAt < tombstoneCutoff }

        // Keep the synced payload comfortably below iCloud's 1 MB key-value limit.
        if timers.count > 120 {
            timers = Array(timers.sorted { $0.updatedAt > $1.updatedAt }.prefix(120))
        }
        if quickTimers.count > 60 {
            quickTimers = Array(quickTimers.sorted { $0.createdAt > $1.createdAt }.prefix(60))
        }
        if alarms.count > 60 {
            alarms = Array(alarms.sorted { $0.updatedAt > $1.updatedAt }.prefix(60))
        }
    }

    private static func mergeItems<T: SyncableItem>(_ current: [T], _ incoming: [T]) -> [T] {
        var byID: [UUID: T] = [:]
        for item in current {
            byID[item.id] = item
        }
        for item in incoming {
            if let existing = byID[item.id] {
                if item.updatedAt > existing.updatedAt {
                    byID[item.id] = item
                }
            } else {
                byID[item.id] = item
            }
        }
        // Dictionary order is not stable. Sort by ID so merging the same data
        // twice produces an identical snapshot and does not cause sync churn.
        return byID.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

// MARK: - Formatting

enum DurationFormatter {
    /// Produces names like "1-minute timer", "5-hour timer", or
    /// "1-day 2-hour 3-minute timer", matching the names used by notifications.
    static func timerName(for duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        if total == 0 {
            return "0-second timer"
        }

        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)-day") }
        if hours > 0 { parts.append("\(hours)-hour") }
        if minutes > 0 { parts.append("\(minutes)-minute") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)-second") }

        return parts.joined(separator: " ") + " timer"
    }

    static func compactName(for duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        if total % 86_400 == 0, total >= 86_400 {
            return "\(total / 86_400) day"
        }
        if total % 3_600 == 0, total >= 3_600 {
            return "\(total / 3_600) hr"
        }
        if total % 60 == 0, total >= 60 {
            return "\(total / 60) min"
        }
        return "\(total) sec"
    }

    static func clockString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        if days > 0 {
            return String(format: "%d:%02d:%02d:%02d", days, hours, minutes, seconds)
        }
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func totalDurationString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }
}
