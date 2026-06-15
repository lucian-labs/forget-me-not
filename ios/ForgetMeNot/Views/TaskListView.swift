import SwiftUI

/// The main panel: active tasks, most urgent first, each with a live urgency bar.
/// `TimelineView` ticks every second so the bars advance without manual timers.
struct TaskListView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                List {
                    ForEach(store.sortedActive) { task in
                        row(task, now: context.date)
                    }
                }
            }
            .navigationTitle("forget me not")
            .overlay {
                if store.sortedActive.isEmpty {
                    ContentUnavailableView("All clear", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private func row(_ task: TaskDTO, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title).font(.headline)
                Spacer()
                if task.recurring {
                    Image(systemName: "repeat")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !task.domain.isEmpty {
                Text(task.domain).font(.caption).foregroundStyle(.secondary)
            }
            UrgencyBarView(ratio: Urgency.ratio(task, now: now))
        }
        .padding(.vertical, 4)
    }
}
