import Foundation
import SwiftUI
import Combine
import UIKit
import UserNotifications
import ActivityKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: SharedSnapshot
    @Published private(set) var now = Date()
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var liveActivitiesEnabled = false
    @Published private(set) var criticalAlertsEnabled = false
    @Published var toast: String?

    let sync = CloudSyncManager()

    private let store = SharedStore.shared
    private let notifications = NotificationManager.shared
    private var ticker: Timer?
    private var darwinToken: UUID?
    private var toastTask: Task<Void, Never>?
    private var hasStarted = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        snapshot = store.load()

        // Settings reads sync details directly from CloudSyncManager, so forward
        // its change notifications through AppModel's ObservableObject publisher.
        sync.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        notifications.configure()
        notifications.onTimerAction = { [weak self] timerID, action in
            Task { @MainActor in
                guard let self else { return }
                switch action {
                case .restart:
                    self.restartTimer(timerID)
                case .stop:
                    self.stopTimer(timerID)
                }
            }
        }
    }

    deinit {
        ticker?.invalidate()
        if let darwinToken {
            DarwinNotificationCenter.shared.remove(darwinToken, name: AppConstants.darwinStateChanged)
        }
        toastTask?.cancel()
    }

    // MARK: - Derived data

    var activeTimers: [TimerItem] { snapshot.activeTimers }
    var endedTimers: [TimerItem] { snapshot.endedTimers }
    var customQuickTimers: [QuickTimer] { snapshot.visibleQuickTimers }
    var alarms: [AlarmItem] { snapshot.visibleAlarms }

    var runningTimerCount: Int {
        snapshot.timers.filter { !$0.isDeleted && $0.state == .running }.count
    }

    var notificationsAuthorized: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var deviceName: String {
        UIDevice.current.name
    }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        normalizeTimers()
        store.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        sync.onRemoteSnapshot = { [weak self] remote in
            Task { @MainActor in
                self?.mergeRemote(remote)
            }
        }

        // Read the iCloud copy before pushing anything, so launching the app on
        // a second device never overwrites an existing remote snapshot with an
        // empty local one.
        let remote = sync.start()
        startTicker()

        if let remote {
            mergeRemote(remote)
        } else if !snapshot.timers.isEmpty || !snapshot.quickTimers.isEmpty || !snapshot.alarms.isEmpty {
            sync.push(snapshot)
        }

        notifications.reconcile(snapshot)

        darwinToken = DarwinNotificationCenter.shared.observe(AppConstants.darwinStateChanged) { [weak self] in
            Task { @MainActor in
                self?.reloadFromSharedStore()
            }
        }

        Task {
            await refreshNotificationStatus(requestIfNeeded: true)
            await LiveActivityManager.shared.reconcile(snapshot.timers)
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            now = .now
            if normalizeTimers() {
                commit()
            } else {
                store.save(snapshot)
                notifications.reconcile(snapshot)
                sync.refreshAvailability()
                Task {
                    await refreshNotificationStatus()
                    await LiveActivityManager.shared.reconcile(snapshot.timers)
                }
            }
        case .background:
            store.save(snapshot)
            sync.flush(snapshot)
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        now = .now
        guard completeExpiredTimers(in: &snapshot, now: now) else { return }

        store.save(snapshot)
        notifications.reconcile(snapshot)
        sync.push(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            await LiveActivityManager.shared.reconcile(snapshot.timers, now: now)
        }
    }

    @discardableResult
    private func normalizeTimers() -> Bool {
        var changed = false
        let currentTime = Date()

        for index in snapshot.timers.indices {
            var timer = snapshot.timers[index]

            if timer.state == .running && timer.endDate == nil {
                timer.state = .paused
                timer.remainingAtPause = max(0, timer.remainingAtPause)
                timer.updatedAt = currentTime
                changed = true
            }

            if timer.state == .running, let endDate = timer.endDate, endDate <= currentTime {
                timer.state = .completed
                timer.endDate = nil
                timer.completedAt = endDate
                timer.remainingAtPause = 0
                timer.updatedAt = currentTime
                changed = true
            }

            if timer.state == .completed && timer.completedAt == nil {
                timer.completedAt = timer.updatedAt
                changed = true
            }

            snapshot.timers[index] = timer
        }

        if changed {
            snapshot.updatedAt = currentTime
        }
        snapshot.prune(now: currentTime)
        return changed
    }

    @discardableResult
    private func completeExpiredTimers(in snapshot: inout SharedSnapshot, now: Date) -> Bool {
        var changed = false

        for index in snapshot.timers.indices {
            var timer = snapshot.timers[index]
            guard timer.state == .running, let endDate = timer.endDate, endDate <= now else { continue }
            timer.state = .completed
            timer.endDate = nil
            timer.completedAt = endDate
            timer.remainingAtPause = 0
            timer.updatedAt = now
            snapshot.timers[index] = timer
            changed = true
        }

        if changed {
            snapshot.updatedAt = now
        }
        return changed
    }

    private func commit() {
        now = Date()
        snapshot.updatedAt = now
        snapshot.prune(now: now)
        store.save(snapshot)
        notifications.reconcile(snapshot)
        sync.push(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        let timers = snapshot.timers
        let currentTime = now
        Task {
            await LiveActivityManager.shared.reconcile(timers, now: currentTime)
        }
    }

    private func mergeRemote(_ remote: SharedSnapshot) {
        var merged = snapshot.merged(with: remote)
        let expiredChanged = completeExpiredTimers(in: &merged, now: .now)
        merged.prune(now: .now)

        let localChanged = !merged.hasSameContent(as: snapshot)
        if localChanged || expiredChanged {
            snapshot = merged
            store.save(snapshot)
            notifications.reconcile(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            Task {
                await LiveActivityManager.shared.reconcile(snapshot.timers)
            }
        }

        if !merged.hasSameContent(as: remote) {
            sync.push(merged, force: true)
        }
    }

    private func reloadFromSharedStore() {
        let loaded = store.load()
        guard !loaded.hasSameContent(as: snapshot) else { return }

        snapshot = loaded
        now = .now
        normalizeTimers()
        store.save(snapshot)
        notifications.reconcile(snapshot)
        sync.push(snapshot, force: true)
        WidgetCenter.shared.reloadAllTimelines()

        Task {
            await LiveActivityManager.shared.reconcile(snapshot.timers)
        }
    }

    // MARK: - Timers

    func startTimer(duration: TimeInterval) {
        let safeDuration = min(max(1, duration.rounded()), AppConstants.maxTimerDuration)
        let currentTime = Date()
        let timer = TimerItem(
            totalDuration: safeDuration,
            state: .running,
            endDate: currentTime.addingTimeInterval(safeDuration),
            startedAt: currentTime,
            updatedAt: currentTime
        )

        snapshot.timers.insert(timer, at: 0)
        commit()
        showToast("\(timer.displayName) started")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func togglePause(_ id: UUID) {
        guard let index = snapshot.timers.firstIndex(where: { $0.id == id }) else { return }
        var timer = snapshot.timers[index]
        let currentTime = Date()

        switch timer.state {
        case .running:
            timer.remainingAtPause = timer.remaining(at: currentTime)
            timer.state = .paused
            timer.endDate = nil
            showToast("\(timer.displayName) paused")
        case .paused:
            let remaining = max(1, timer.remainingAtPause)
            timer.state = .running
            timer.endDate = currentTime.addingTimeInterval(remaining)
            timer.remainingAtPause = 0
            showToast("\(timer.displayName) resumed")
        case .completed:
            return
        }

        timer.updatedAt = currentTime
        snapshot.timers[index] = timer
        commit()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func stopTimer(_ id: UUID) {
        guard let index = snapshot.timers.firstIndex(where: { $0.id == id }) else { return }
        let currentTime = Date()

        notifications.cancelTimer(id: id)
        snapshot.timers[index].isDeleted = true
        snapshot.timers[index].state = .completed
        snapshot.timers[index].endDate = nil
        snapshot.timers[index].completedAt = currentTime
        snapshot.timers[index].remainingAtPause = 0
        snapshot.timers[index].updatedAt = currentTime
        commit()
        showToast("Timer stopped")
    }

    func dismissTimer(_ id: UUID) {
        guard let index = snapshot.timers.firstIndex(where: { $0.id == id }) else { return }
        let currentTime = Date()

        notifications.cancelTimer(id: id)
        snapshot.timers[index].isDeleted = true
        snapshot.timers[index].updatedAt = currentTime
        commit()
    }

    func restartTimer(_ id: UUID) {
        guard let index = snapshot.timers.firstIndex(where: { $0.id == id }) else { return }
        let currentTime = Date()
        let timer = snapshot.timers[index]

        notifications.cancelTimer(id: id)
        snapshot.timers[index].state = .running
        snapshot.timers[index].startedAt = currentTime
        snapshot.timers[index].endDate = currentTime.addingTimeInterval(timer.totalDuration)
        snapshot.timers[index].remainingAtPause = 0
        snapshot.timers[index].completedAt = nil
        snapshot.timers[index].isDeleted = false
        snapshot.timers[index].updatedAt = currentTime
        commit()
        showToast("\(timer.displayName) restarted")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Quick timers

    func addQuickTimer(duration: TimeInterval) {
        let safeDuration = min(max(1, duration.rounded()), AppConstants.maxTimerDuration)
        let currentTime = Date()
        let timer = QuickTimer(
            duration: safeDuration,
            createdAt: currentTime,
            updatedAt: currentTime
        )
        snapshot.quickTimers.append(timer)
        commit()
        showToast("Added \(timer.displayName)")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func deleteQuickTimer(_ id: UUID) {
        guard let index = snapshot.quickTimers.firstIndex(where: { $0.id == id }) else { return }
        snapshot.quickTimers[index].isDeleted = true
        snapshot.quickTimers[index].updatedAt = .now
        commit()
        showToast("Quick timer removed")
    }

    // MARK: - Alarms

    func addAlarm(hour: Int, minute: Int, label: String, repeatsDaily: Bool) {
        let safeHour = min(max(0, hour), 23)
        let safeMinute = min(max(0, minute), 59)
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentTime = Date()

        let alarm = AlarmItem(
            hour: safeHour,
            minute: safeMinute,
            label: cleanLabel.isEmpty ? "Alarm" : cleanLabel,
            isEnabled: true,
            repeatsDaily: repeatsDaily,
            createdAt: currentTime,
            updatedAt: currentTime
        )
        snapshot.alarms.append(alarm)
        commit()
        showToast("\(alarm.timeText) alarm added")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func setAlarmEnabled(_ id: UUID, enabled: Bool) {
        guard let index = snapshot.alarms.firstIndex(where: { $0.id == id }) else { return }
        snapshot.alarms[index].isEnabled = enabled
        snapshot.alarms[index].updatedAt = .now
        if !enabled {
            notifications.cancelAlarm(id: id)
        }
        commit()
        showToast(enabled ? "Alarm on" : "Alarm off")
    }

    func deleteAlarm(_ id: UUID) {
        guard let index = snapshot.alarms.firstIndex(where: { $0.id == id }) else { return }
        notifications.cancelAlarm(id: id)
        snapshot.alarms[index].isDeleted = true
        snapshot.alarms[index].updatedAt = .now
        commit()
        showToast("Alarm deleted")
    }

    // MARK: - Settings

    func syncNow() {
        guard sync.isAvailable else {
            showToast("Sign in to iCloud to sync")
            return
        }

        if let remote = sync.readRemote() {
            mergeRemote(remote)
            showToast("Synced with iCloud")
        } else {
            sync.push(snapshot, force: true)
            showToast("Syncing with iCloud")
        }
    }

    func refreshNotificationStatus(requestIfNeeded: Bool = false) async {
        if requestIfNeeded {
            notificationStatus = await notifications.requestAuthorization()
        } else {
            notificationStatus = await notifications.authorizationStatus()
        }
        criticalAlertsEnabled = notifications.criticalAlertsAuthorized
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

        // The cached critical-alert state may have changed, so reschedule with
        // the critical sound or the standard fallback now.
        notifications.reconcile(snapshot)
    }

    func requestNotifications() {
        Task {
            notificationStatus = await notifications.requestAuthorization(requestCritical: true)
            criticalAlertsEnabled = notifications.criticalAlertsAuthorized
            notifications.reconcile(snapshot)
        }
    }

    func playSoundPreview() {
        notifications.playSoundPreview()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func clearEverything() {
        let currentTime = Date()

        for index in snapshot.timers.indices {
            notifications.cancelTimer(id: snapshot.timers[index].id)
            snapshot.timers[index].isDeleted = true
            snapshot.timers[index].state = .completed
            snapshot.timers[index].endDate = nil
            snapshot.timers[index].updatedAt = currentTime
        }
        for index in snapshot.quickTimers.indices {
            snapshot.quickTimers[index].isDeleted = true
            snapshot.quickTimers[index].updatedAt = currentTime
        }
        for index in snapshot.alarms.indices {
            notifications.cancelAlarm(id: snapshot.alarms[index].id)
            snapshot.alarms[index].isDeleted = true
            snapshot.alarms[index].updatedAt = currentTime
        }

        commit()
        Task {
            await LiveActivityManager.shared.endAll()
        }
        showToast("All timers and alarms cleared")
    }

    // MARK: - Toast

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = message
        }

        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.toast = nil
                }
            }
        }
    }
}
