import Foundation

/// Small string prefs — prompts, mascot/nudge styles, theme — mirrored across the user's
/// devices via iCloud key-value storage. Every write hits both UserDefaults (the local read
/// path everything already uses) and NSUbiquitousKeyValueStore (the synced copy). A change
/// made on another device is mirrored back into UserDefaults and announced via `onChange`,
/// so editing a prompt on the phone shows up on the Mac and vice-versa.
enum SyncedPrefs {
    private static let prefix = "fmn."
    @MainActor private static var observer: (any NSObjectProtocol)?
    @MainActor private static var changeHandler: (() -> Void)?

    /// Write (or clear, when nil) a value to both the local defaults and the iCloud store.
    static func set(_ value: String?, forKey key: String) {
        let kvs = NSUbiquitousKeyValueStore.default
        if let value {
            UserDefaults.standard.set(value, forKey: key)
            kvs.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        kvs.synchronize()
    }

    /// Begin mirroring iCloud → local defaults. Pulls whatever has already synced, then watches
    /// for external changes; `onChange` fires on the main actor after each mirror so the UI can
    /// re-read the new values.
    @MainActor static func start(onChange: @escaping () -> Void) {
        changeHandler = onChange
        guard observer == nil else { return }
        let kvs = NSUbiquitousKeyValueStore.default
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs, queue: .main
        ) { note in
            let changed = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
            MainActor.assumeIsolated {
                mirror(changed.isEmpty ? allKeys() : changed)
                changeHandler?()
            }
        }
        mirror(allKeys())   // catch up on anything already in iCloud
        kvs.synchronize()   // ask iCloud to push the latest
    }

    /// Copy the given iCloud keys (only our fmn.* prefs) down into UserDefaults.
    @MainActor private static func mirror(_ keys: [String]) {
        let kvs = NSUbiquitousKeyValueStore.default
        for key in keys where key.hasPrefix(prefix) {
            if let value = kvs.string(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    @MainActor private static func allKeys() -> [String] {
        Array(NSUbiquitousKeyValueStore.default.dictionaryRepresentation.keys)
    }
}
