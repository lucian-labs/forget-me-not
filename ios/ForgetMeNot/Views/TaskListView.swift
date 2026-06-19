import SwiftUI

/// The main panel — waveloop-styled. Swipe a card right to drop a SNACK (reset); tap for
/// detail; header buttons = new / loops data / settings. (List handles vertical scroll +
/// swipe natively — a custom drag was stealing the scroll, so the physical pocket is
/// shelved for a UIKit pass.)
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(CharacterStore.self) private var characters
    @Environment(NudgeCoordinator.self) private var coordinator
    @State private var detailTask: TaskDTO?
    @State private var showLoops = false
    @State private var showCreate = false
    @State private var showSettings = false
    @State private var now = Date()

    /// Drives live re-sorting + nudge re-evaluation. Mascots still reconcile only on open.
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
            // bump `now` (read in `content`) so the list re-sorts as urgency rises, and
            // re-evaluate nudges so a task crossing a threshold mid-session gets a prompt.
            withAnimation(.easeInOut(duration: 0.45)) { now = Date() }
            coordinator.evaluate(store.sortedActive, now: Date())
        }
        .fullScreenCover(item: $detailTask) { task in
            TaskDetailView(taskId: task.id).environment(store).environment(characters)
        }
        .fullScreenCover(isPresented: $showLoops) {
            LoopsView().environment(store)
        }
        .sheet(isPresented: $showCreate) {
            CreateTaskView().environment(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store).environment(characters)
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
                                     character: characters.image(for: task.id))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(WL.bg)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { reset(task) } label: {
                            Label("SNACK", systemImage: "fish.fill")
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

    private func reset(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.reset(id: task.id)
        }
    }
}
