import SwiftUI

@main
struct ForgetMeNotApp: App {
    @State private var store: AppStore
    @State private var characters = CharacterStore()
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
                .environment(characters)
                .task {
                    await scheduler.requestAuthorization()
                    await scheduler.sync(store.sortedActive, characterURL: { characters.imageURL(for: $0) })
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await scheduler.sync(store.sortedActive, characterURL: { characters.imageURL(for: $0) }) }
            }
        }
    }
}
