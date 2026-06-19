import SwiftUI

@main
struct ForgetMeNotApp: App {
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
