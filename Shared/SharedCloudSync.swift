import Foundation

/// A small push helper used by Live Activity and widget intents. Those intents
/// run in the app process but may run before the SwiftUI `AppModel` exists, so
/// they cannot rely on `CloudSyncManager` to publish the change.
enum SharedCloudSync {
    static func push(_ snapshot: SharedSnapshot) {
        guard FileManager.default.ubiquityIdentityToken != nil else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return }

        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: AppConstants.iCloudSnapshotKey)
        _ = store.synchronize()
    }
}
