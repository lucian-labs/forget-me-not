import SwiftUI

@main
struct ForgetMeNotApp: App {
    @State private var store = TaskStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PanelView()
                    .navigationDestination(for: String.self) { taskId in
                        TaskDetailView(taskId: taskId)
                    }
            }
            .environment(store)
            .tint(store.theme.accent)
            .preferredColorScheme(store.theme.isDark ? .dark : .light)
        }
    }
}
