import Foundation

/// Small, thread-safe store shared by the app and the Live Activity extension.
/// Uses the App Group when entitlements are available, and falls back to the
/// standard defaults so the app still works while unsigned or in a preview.
final class SharedStore {
    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    private init() {
        // UserDefaults(suiteName:) can still return an object when the App Group
        // entitlement is missing. Check the container first so an unsigned or
        // locally signed build reliably falls back to standard defaults.
        if FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) != nil, let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupID) {
            defaults = groupDefaults
        } else {
            defaults = .standard
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func load() -> SharedSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    func save(_ snapshot: SharedSnapshot) {
        lock.lock()
        defer { lock.unlock() }
        saveLocked(snapshot)
    }

    @discardableResult
    func update(_ body: (inout SharedSnapshot) -> Void) -> SharedSnapshot {
        lock.lock()
        defer { lock.unlock() }
        var snapshot = loadLocked()
        body(&snapshot)
        saveLocked(snapshot)
        return snapshot
    }

    var hasStoredSnapshot: Bool {
        lock.lock()
        defer { lock.unlock() }
        return defaults.data(forKey: AppConstants.snapshotKey) != nil
    }

    private func loadLocked() -> SharedSnapshot {
        guard let data = defaults.data(forKey: AppConstants.snapshotKey),
              let snapshot = try? decoder.decode(SharedSnapshot.self, from: data) else {
            return SharedSnapshot()
        }
        return snapshot
    }

    private func saveLocked(_ snapshot: SharedSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: AppConstants.snapshotKey)
        defaults.synchronize()
    }
}
