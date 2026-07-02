import SwiftUI

/// The main panel — waveloop-styled. Cards use SwipeableCard (direct-manipulation pan,
/// velocity-preserving springs, haptic threshold ticks) instead of List swipe actions —
/// the UITableView drawer machinery was the jank. Scroll-vs-swipe is arbitrated in UIKit
/// (horizontal intent only), which is what the old custom drag got wrong.
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(NudgeCoordinator.self) private var coordinator
    @Environment(AlertSounder.self) private var sounder
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
                footer
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(ticker) { _ in
            store.load()                       // poll: surface another device's swipe/reset live
            icons.evolve(for: store.sortedActive)   // ...and decode any icons it synced over
            coordinator.evaluate(store.sortedActive, now: Date())
            sounder.evaluate(store.sortedActive, config: store.soundConfig)   // jingle on tip-over
            // Only bump `now` when the SORT ORDER actually changes; the container's spring
            // animates the reorder (a tick that re-sorts nothing shouldn't touch the tree).
            let t = Date()
            let key = store.activeSorted(now: t).map(\.id)
            if key != orderKey {
                orderKey = key
                now = t
            }
        }
        .fullScreenCover(item: $detailTask) { task in
            TaskDetailView(taskId: task.id).environment(store).environment(icons).environment(sounder)
        }
        .fullScreenCover(isPresented: $showLoops) {
            LoopsView().environment(store)
        }
        .fullScreenCover(isPresented: $showAllTasks) {
            AllTasksView().environment(store).environment(icons).environment(sounder)
        }
        .sheet(isPresented: $showCreate) {
            CreateTaskView().environment(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store).environment(icons).environment(sounder)
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

    private var footer: some View {
        Text(AppVersion.footer)
            .font(WL.mono(9)).tracking(1)
            .foregroundStyle(WL.muted.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.top, 4).padding(.bottom, 6)
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
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(active) { task in
                        row(task)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.92))))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                // One tight spring drives reorders, removals, and post-swipe settling.
                .animation(.spring(response: 0.32, dampingFraction: 0.86), value: active.map(\.id))
            }
        }
    }

    private func row(_ task: TaskDTO) -> some View {
        SwipeableCard(
            // Right swipe = DONE: reset + fire follow-ups (logged "done"). One-time tasks
            // leave the list, so their card flies off; recurring ones stamp + spring home.
            leading: SwipeAction(label: "DONE", icon: "checkmark.circle.fill", color: WL.green,
                                 removesRow: !task.recurring,
                                 handler: { markDone(task) }),
            // Left swipe = SKIP: restart the timer, no follow-ups (logged "skipped").
            trailing: SwipeAction(label: "SKIP", icon: "arrow.counterclockwise", color: WL.cyan,
                                  removesRow: false,
                                  handler: { skip(task) })
        ) {
            TaskCardView(task: task,
                         nudge: coordinator.nudge(for: task.id),
                         icon: icons.image(for: task.id),
                         symbol: task.iconSymbol)
        }
        .onTapGesture { detailTask = task }
        .contextMenu {
            if task.recurring {
                // Web parity (zz): quiet it down for a bit — jumps to 75%, re-alerts soon.
                Button {
                    store.snooze(id: task.id)
                } label: {
                    Label("Snooze", systemImage: "moon.zzz")
                }
                // Web parity (↓): fresh cycle, nothing logged, streaks untouched.
                Button {
                    store.restartCycle(id: task.id)
                } label: {
                    Label("Restart timer quietly", systemImage: "arrow.counterclockwise.circle")
                }
            }
            Button {
                sounder.preview(task, config: store.soundConfig)
            } label: {
                Label("Hear its sound", systemImage: "speaker.wave.2")
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private func skip(_ task: TaskDTO) {
        coordinator.clear(task.id)
        store.skip(id: task.id)
    }

    private func markDone(_ task: TaskDTO) {
        coordinator.clear(task.id)
        store.markDone(id: task.id)   // reset (recurring) or complete (one-time) + fire follow-ups
    }
}
