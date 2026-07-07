import SwiftUI
import UIKit
import UserNotifications

/// Registers for remote notifications (CloudKit pushes) and receives notification ACTIONS —
/// swipe/long-press a reminder to Done / Reset / Snooze the task without opening the app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    // NOTE: deliberately do NOT implement didReceiveRemoteNotification. Handling the silent push
    // and returning .newData intercepted CloudKit's push before NSPersistentCloudKitContainer
    // could run its fetch, which stalled imports on BOTH devices (export kept working, so nothing
    // synced either way). Letting the container own push handling restores live foreground sync.
    // Background import to a suspended device is an OS-throttled problem to revisit separately.

    /// Show reminders even while the app is foregrounded.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Apply the tapped action (Done / Reset / Snooze) to the task.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.notification.request.content.userInfo["taskId"] as? String
        let action = response.actionIdentifier
        // UN delegate callbacks run on the main thread, so apply the change synchronously.
        MainActor.assumeIsolated {
            if let id { NotificationActions.handle(action, taskId: id) }
        }
        completionHandler()
    }
}

@main
struct ForgetMeNotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store: AppStore
    @State private var icons = IconStore()
    @State private var coordinator = NudgeCoordinator()
    @State private var sounder = AlertSounder()
    #if DEBUG
    @State private var mcp: MCPServer?   // dev-only: local server is compiled out of Release
    #endif
    @Environment(\.scenePhase) private var scenePhase
    private let scheduler = ReminderScheduler()

    init() {
        let container = FMNModelContainer.resolve()
        _store = State(initialValue: AppStore(repository: SwiftDataTaskRepository(container: container)))
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environment(store)
                .environment(icons)
                .environment(coordinator)
                .environment(sounder)
                .task {
                    wireIcons()         // persist generated icons onto tasks (so they sync)
                    #if DEBUG
                    startMCP()          // dev-only: expose tools to MCP clients on a local port
                    #endif
                    reconcileOnOpen()   // render icons + quotes from current state
                    healIconsOnce()     // drop pre-downscale oversized icons that jammed sync
                    refreshIconStyleOnce()  // re-render existing icons in the new gold-ink look
                    await scheduler.requestAuthorization()
                    await scheduler.sync(store.sortedActive, characterURL: { iconURL(for: $0) })
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                reconcileOnOpen()   // and again whenever it returns to foreground
                Task { await scheduler.sync(store.sortedActive, characterURL: { iconURL(for: $0) }) }
            }
        }
    }

    /// Persist generated icons onto the task (→ CloudKit) so other devices show them.
    @MainActor private func wireIcons() {
        icons.onGenerated = { [store] id, data in store.setIconImage(id: id, data) }
        icons.onCleared = { [store] id in store.setIconImage(id: id, nil) }
    }

    /// The reminder image: the task's gold-ink icon on black, or the app monogram when it has
    /// none — never blank (NotificationArt handles the compositing + fallback).
    @MainActor private func iconURL(for id: String) -> URL? {
        NotificationArt.file(taskIcon: store.task(id)?.iconImageData, key: id)
    }

    /// Both the icon images and the nudge quotes render from each task's current urgency
    /// when the app opens, rather than ticking/queuing over the session. Reloads first so
    /// changes made by Siri / Shortcuts while backgrounded are picked up.
    @MainActor private func reconcileOnOpen() {
        store.load()
        let active = store.sortedActive
        icons.evolve(for: active)
        coordinator.evaluate(active, now: Date())
        sounder.evaluate(active, config: store.soundConfig)
    }

    /// One-time repair: early builds stored full-size icon PNGs on the task; at 1.5–1.8MB they
    /// exceeded CloudKit's ~1MB per-record limit and silently jammed ALL sync (0 records ever
    /// exported, both directions). Clear the oversized ones so the export queue drains — they
    /// regenerate downscaled. Runs once per device.
    @MainActor private func healIconsOnce() {
        guard !UserDefaults.standard.bool(forKey: "fmn.iconHealV1") else { return }
        UserDefaults.standard.set(true, forKey: "fmn.iconHealV1")
        for task in store.tasks where (task.iconImageData?.count ?? 0) > 900_000 {
            store.setIconImage(id: task.id, nil)   // shrink the synced record
            icons.forget(task.id)                  // drop the cached copy → regenerates downscaled
        }
        icons.evolve(for: store.sortedActive)
    }

    /// One-time: the icon style changed to gold-ink (GoldInk + .sketch), so clear the old
    /// cartoon icons and regenerate every active task's icon in the new look. Runs once per
    /// device; each device generates its own (last write wins on sync).
    @MainActor private func refreshIconStyleOnce() {
        guard !UserDefaults.standard.bool(forKey: "fmn.iconDefaultRestoreV1") else { return }
        UserDefaults.standard.set(true, forKey: "fmn.iconDefaultRestoreV1")
        icons.regenerateAll(for: store.sortedActive)
    }

    #if DEBUG
    @MainActor private func startMCP() {
        guard mcp == nil else { return }
        let server = MCPServer(store: store, icons: icons)
        server.start()
        mcp = server
    }
    #endif
}
