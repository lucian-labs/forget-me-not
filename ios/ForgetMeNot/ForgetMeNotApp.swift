import SwiftUI

@main
struct ForgetMeNotApp: App {
    @State private var store: AppStore

    init() {
        let container = FMNModelContainer.resolve()
        _store = State(initialValue: AppStore(repository: SwiftDataTaskRepository(container: container)))
    }

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environment(store)
        }
    }
}
