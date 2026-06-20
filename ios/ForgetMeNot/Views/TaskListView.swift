import SwiftUI

/// The main panel — waveloop-styled. Swipe a card right to drop a SNACK (reset); tap for
/// detail; header buttons = new / loops data / settings. (List handles vertical scroll +
/// swipe natively — a custom drag was stealing the scroll, so the physical pocket is
/// shelved for a UIKit pass.)
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(NudgeCoordinator.self) private var coordinator
    @State private var detailTask: TaskDTO?
    @State private var showLoops = false
    @State private var showCreate = false
    @State private var showSettings = false
    @State private var showAllTasks = false
    @State private var now = Date()
    @State private var orderKey: [String] = []

    /// Drives live re-sorting + nudge re-evaluation. 10s (was 2s) — order/nudge changes are
    /// slow, so waking every 2s just to re-sort the same list wasted battery. Icons reconcile
    /// only on open.
    private let ticker = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            WLBackground()
            VStack(spacing: 0) {
                header
                Rectangle().fill(WL.line).frame(height: 1)
                content
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in
            store.load()                       // poll: surface another device's swipe/reset live
            icons.evolve(for: store.sortedActive)   // ...and decode any icons it synced over
            coordinator.evaluate(store.sortedActive, now: Date())
            // Only re-render the list when the SORT ORDER actually changes — re-rendering
            // every tick collapsed in-progress swipe drawers (a row wouldn't reset).
            let t = Date()
            let key = store.activeSorted(now: t).map(\.id)
            if key != orderKey {
                orderKey = key
                withAnimation(.easeInOut(duration: 0.45)) { now = t }
            }
        }
        .fullScreenCover(item: $detailTask) { task in
            TaskDetailView(taskId: task.id).environment(store).environment(icons)
        }
        .fullScreenCover(isPresented: $showLoops) {
            LoopsView().environment(store)
        }
        .fullScreenCover(isPresented: $showAllTasks) {
            AllTasksView().environment(store).environment(icons)
        }
        .sheet(isPresented: $showCreate) {
            CreateTaskView().environment(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store).environment(icons)
        }
    }

    private var header: some View {
        HStack {
            Text("FORGET ME NOT")
                .font(WL.mono(17, .bold)).tracking(3).foregroundStyle(WL.text)
            Spacer()
            HStack(spacing: 18) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(WL.accent)
                }
                .accessibilityLabel("New task")
                Button { showAllTasks = true } label: {
                    Image(systemName: "list.bullet").font(.system(size: 15, weight: .semibold)).foregroundStyle(WL.accent)
                }
                .accessibilityLabel("All tasks")
                Button { showLoops = true } label: {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 15, weight: .semibold)).foregroundStyle(WL.accent)
                }
                .accessibilityLabel("Loops data")
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold)).foregroundStyle(WL.accent)
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder private var content: some View {
        let active = store.activeSorted(now: now)
        if active.isEmpty {
            VStack {
                Spacer()
                Text("ALL CLEAR")
                    .font(WL.mono(14, .bold)).tracking(2).foregroundStyle(WL.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach(active) { task in
                    Button { detailTask = task } label: {
                        TaskCardView(task: task,
                                     nudge: coordinator.nudge(for: task.id),
                                     icon: icons.image(for: task.id),
                                     symbol: task.iconSymbol)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(WL.bg)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // Left swipe = SKIP: restart the timer, no follow-ups (logged "skipped").
                        Button { skip(task) } label: {
                            Label("SKIP", systemImage: "arrow.counterclockwise")
                        }
                        .tint(WL.cyan)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        // Right swipe = DONE: reset + fire follow-ups (logged "done").
                        Button { markDone(task) } label: {
                            Label("DONE", systemImage: "checkmark.circle.fill")
                        }
                        .tint(WL.green)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 10, for: .scrollContent)
        }
    }

    private func skip(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.skip(id: task.id)
        }
    }

    private func markDone(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.markDone(id: task.id)   // reset (recurring) or complete (one-time) + fire follow-ups
        }
    }
}
