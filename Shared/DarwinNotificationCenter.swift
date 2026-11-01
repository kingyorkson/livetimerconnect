import Foundation
import CoreFoundation

/// Tiny Darwin-notification bridge used to tell the running app that a Live
/// Activity intent changed the shared snapshot in another process.
final class DarwinNotificationCenter {
    static let shared = DarwinNotificationCenter()

    private var handlers: [String: [UUID: () -> Void]] = [:]
    private var registeredNames = Set<String>()
    private let lock = NSLock()

    private init() {}

    @discardableResult
    func observe(_ name: String, handler: @escaping () -> Void) -> UUID {
        let token = UUID()

        lock.lock()
        handlers[name, default: [:]][token] = handler
        let needsRegistration = !registeredNames.contains(name)
        registeredNames.insert(name)
        lock.unlock()

        if needsRegistration {
            register(name)
        }
        return token
    }

    func remove(_ token: UUID, name: String) {
        lock.lock()
        handlers[name]?.removeValue(forKey: token)
        lock.unlock()
    }

    func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    private func register(_ name: String) {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, notificationName, _, _ in
                guard let observer, let notificationName else { return }
                let center = Unmanaged<DarwinNotificationCenter>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                center.dispatch(notificationName.rawValue as String)
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func dispatch(_ name: String) {
        lock.lock()
        var callbacks: [() -> Void] = []
        if let entries = handlers[name] {
            callbacks = Array(entries.values)
        }
        lock.unlock()

        guard !callbacks.isEmpty else { return }
        DispatchQueue.main.async {
            callbacks.forEach { $0() }
        }
    }
}
