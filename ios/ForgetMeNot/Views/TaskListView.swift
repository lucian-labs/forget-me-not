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
    @State private var now = Date()
    @State private var orderKey: [String] = []

    /// Drives live re-sorting + nudge re-evaluation. Icons still reconcile only on open.
    private let ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

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
                                     symbol: icons.symbol(for: task.id))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(WL.bg)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // Left swipe (finger moves left) = the primary action: reset a
                        // recurring task's timer, or complete a one-time chain link.
                        if task.recurring {
                            Button { reset(task) } label: {
                                Label("SNACK", systemImage: "fish.fill")
                            }
                            .tint(WL.green)
                        } else {
                            Button { complete(task) } label: {
                                Label("DONE", systemImage: "checkmark.circle.fill")
                            }
                            .tint(WL.green)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        // Right swipe = launch the follow-up chain on demand (reset no longer does).
                        if task.recurring && !task.followUps.isEmpty {
                            Button { store.launchFollowUps(id: task.id) } label: {
                                Label("STEPS", systemImage: "arrow.turn.down.right")
                            }
                            .tint(WL.cyan)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 10, for: .scrollContent)
        }
    }

    private func reset(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.reset(id: task.id)
        }
    }

    private func complete(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.complete(id: task.id)   // marks done + spawns the next chain link
        }
    }
}
