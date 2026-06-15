import SwiftUI

/// The main panel — waveloop-styled: dark grid backdrop, monospaced uppercase header,
/// a stack of square task panels. Swipe a task right to RESET its cycle. On-device
/// nudges appear as it crosses 80/90/100%. Tap a card for its insight; tap the header
/// chart for the global read.
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @State private var coordinator = NudgeCoordinator()
    @State private var detailTask: TaskDTO?
    @State private var showGlobal = false
    @State private var showCreate = false

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
        }
        .fullScreenCover(item: $detailTask) { task in
            TaskDetailView(taskId: task.id).environment(store)
        }
        .sheet(isPresented: $showGlobal) {
            InsightView(title: "All loops") { await insights.overview(store.sortedActive) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCreate) {
            CreateTaskView().environment(store)
        }
    }

    private var header: some View {
        HStack {
            Text("FORGET ME NOT")
                .font(WL.mono(17, .bold)).tracking(3).foregroundStyle(WL.text)
            Spacer()
            HStack(spacing: 18) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(WL.accent)
                }
                .accessibilityLabel("New task")
                Button { showGlobal = true } label: {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WL.accent)
                }
                .accessibilityLabel("Overall insights")
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
            List {
                ForEach(store.sortedActive) { task in
                    TaskCardView(task: task, nudge: coordinator.nudge(for: task.id))
                        .contentShape(Rectangle())
                        .onTapGesture { detailTask = task }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.reset(id: task.id)
                                coordinator.clear(task.id)
                            } label: {
                                Label("RESET", systemImage: "arrow.counterclockwise")
                            }
                            .tint(WL.accent)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
