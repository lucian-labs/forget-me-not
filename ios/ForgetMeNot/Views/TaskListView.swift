import SwiftUI

/// The main panel — waveloop-styled. Slide a card right to open its pocket and drop a
/// snack (reset); tap a card for detail; header buttons = new / insights / settings.
/// Nudges escalate at 70/90/100%+; mascots evolve with urgency.
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(CharacterStore.self) private var characters
    @State private var coordinator = NudgeCoordinator()
    @State private var detailTask: TaskDTO?
    @State private var showGlobal = false
    @State private var showCreate = false
    @State private var showSettings = false

    private let insights = Insights.service()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
            characters.evolve(for: store.sortedActive)
        }
        .fullScreenCover(item: $detailTask) { task in
            TaskDetailView(taskId: task.id).environment(store).environment(characters)
        }
        .sheet(isPresented: $showGlobal) {
            InsightView(title: "All loops") { await insights.overview(store.sortedActive) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreate) {
            CreateTaskView().environment(store)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(store)
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
                Button { showGlobal = true } label: {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 15, weight: .semibold)).foregroundStyle(WL.accent)
                }
                .accessibilityLabel("Overall insights")
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
        if store.sortedActive.isEmpty {
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
                    ForEach(store.sortedActive) { task in
                        TaskCardView(
                            task: task,
                            nudge: coordinator.nudge(for: task.id),
                            character: characters.image(for: task.id),
                            onTap: { detailTask = task },
                            onReset: { reset(task) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
    }

    private func reset(_ task: TaskDTO) {
        coordinator.clear(task.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            store.reset(id: task.id)   // re-sorts to the bottom; rows slide up
        }
    }
}
