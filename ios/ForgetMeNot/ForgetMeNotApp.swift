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
    @State private var mcp: MCPServer?
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
                .task {
                    wireIcons()         // persist generated icons onto tasks (so they sync)
                    startMCP()          // expose tools to MCP clients on a local port
                    reconcileOnOpen()   // render icons + quotes from current state
                    healIconsOnce()     // drop pre-downscale oversized icons that jammed sync
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

    /// Stage a task's synced icon to a temp PNG for notification attachments.
    @MainActor private func iconURL(for id: String) -> URL? {
        guard let data = store.task(id)?.iconImageData else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("fmn-notif-\(id).png")
        try? data.write(to: tmp)
        return tmp
    }

    /// Both the icon images and the nudge quotes render from each task's current urgency
    /// when the app opens, rather than ticking/queuing over the session. Reloads first so
    /// changes made by Siri / Shortcuts while backgrounded are picked up.
    @MainActor private func reconcileOnOpen() {
        store.load()
        let active = store.sortedActive
        icons.evolve(for: active)
        coordinator.evaluate(active, now: Date())
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

    @MainActor private func startMCP() {
        guard mcp == nil else { return }
        let server = MCPServer(store: store, icons: icons)
        server.start()
        mcp = server
    }
}
