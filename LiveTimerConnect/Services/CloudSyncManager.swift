import Foundation
import Combine

@MainActor
final class CloudSyncManager: ObservableObject {
    enum Status: Equatable {
        case checking
        case syncing
        case synced(Date)
        case unavailable
        case error(String)

        var shortText: String {
            switch self {
            case .checking: return "Checking iCloud"
            case .syncing: return "Syncing"
            case .synced: return "Synced"
            case .unavailable: return "Local only"
            case .error: return "Sync issue"
            }
        }

        var symbolName: String {
            switch self {
            case .checking: return "icloud"
            case .syncing: return "arrow.triangle.2.circlepath.icloud"
            case .synced: return "checkmark.icloud.fill"
            case .unavailable: return "icloud.slash"
            case .error: return "exclamationmark.icloud"
            }
        }

        var detailText: String {
            switch self {
            case .checking:
                return "Looking for your iCloud account…"
            case .syncing:
                return "Sending your timers and alarms to iCloud…"
            case .synced(let date):
                return "Last synced \(date.formatted(date: .omitted, time: .shortened))"
            case .unavailable:
                return "Sign in to iCloud in Settings to sync between devices."
            case .error(let message):
                return message
            }
        }
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var isAvailable = false
    @Published private(set) var lastSyncedAt: Date?

    var onRemoteSnapshot: ((SharedSnapshot) -> Void)?

    private let store = NSUbiquitousKeyValueStore.default
    private var externalObserver: NSObjectProtocol?
    private var identityObserver: NSObjectProtocol?
    private var pushTask: Task<Void, Never>?
    private var lastPushedData: Data?

    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    init() {
        externalObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleExternalChange(notification)
            }
        }

        identityObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAvailability()
            }
        }
    }

    deinit {
        if let externalObserver {
            NotificationCenter.default.removeObserver(externalObserver)
        }
        if let identityObserver {
            NotificationCenter.default.removeObserver(identityObserver)
        }
    }

    /// Reads the current iCloud snapshot, if there is one. The caller merges it
    /// before pushing local changes, which prevents an empty install from
    /// replacing data that already exists on another device.
    @discardableResult
    func start() -> SharedSnapshot? {
        refreshAvailability()
        guard isAvailable else { return nil }

        status = .checking
        store.synchronize()

        guard let remote = readRemote() else {
            status = .synced(.now)
            return nil
        }

        lastSyncedAt = .now
        status = .synced(.now)
        return remote
    }

    func refreshAvailability() {
        let available = FileManager.default.ubiquityIdentityToken != nil
        isAvailable = available
        if available {
            if case .unavailable = status {
                status = .checking
            }
        } else {
            status = .unavailable
        }
    }

    func readRemote() -> SharedSnapshot? {
        guard let data = store.data(forKey: AppConstants.iCloudSnapshotKey) else { return nil }
        do {
            return try decoder.decode(SharedSnapshot.self, from: data)
        } catch {
            status = .error("The iCloud copy could not be read. It will be replaced on the next sync.")
            return nil
        }
    }

    func push(_ snapshot: SharedSnapshot, force: Bool = false) {
        refreshAvailability()
        guard isAvailable else {
            status = .unavailable
            return
        }

        status = .syncing
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self?.performPush(snapshot, force: force)
        }
    }

    func flush(_ snapshot: SharedSnapshot) {
        guard isAvailable else { return }
        pushTask?.cancel()
        performPush(snapshot, force: true)
    }

    private func performPush(_ snapshot: SharedSnapshot, force: Bool) {
        guard let data = try? encoder.encode(snapshot) else {
            status = .error("Could not prepare the iCloud update.")
            return
        }

        if !force, data == lastPushedData {
            if case .syncing = status {
                status = .synced(.now)
            }
            return
        }

        store.set(data, forKey: AppConstants.iCloudSnapshotKey)
        _ = store.synchronize()

        lastPushedData = data
        lastSyncedAt = .now
        status = .synced(.now)
    }

    private func handleExternalChange(_ notification: Notification) {
        refreshAvailability()
        guard isAvailable else { return }

        if let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int {
            switch reason {
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                status = .error("Your synced data is too large for iCloud.")
                return
            case NSUbiquitousKeyValueStoreAccountChange:
                refreshAvailability()
            default:
                break
            }
        }

        guard let remote = readRemote() else { return }
        lastSyncedAt = .now
        status = .synced(.now)
        onRemoteSnapshot?(remote)
    }
}
