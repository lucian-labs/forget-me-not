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
                    startMCP()          // expose tools to MCP clients on a local port
                    reconcileOnOpen()   // render icons + quotes from current state
                    await scheduler.requestAuthorization()
                    await scheduler.sync(store.sortedActive, characterURL: { icons.imageURL(for: $0) })
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                reconcileOnOpen()   // and again whenever it returns to foreground
                Task { await scheduler.sync(store.sortedActive, characterURL: { icons.imageURL(for: $0) }) }
            }
        }
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

    @MainActor private func startMCP() {
        guard mcp == nil else { return }
        let server = MCPServer(store: store, icons: icons)
        server.start()
        mcp = server
    }
}
