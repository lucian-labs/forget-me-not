import SwiftUI

/// The main panel — waveloop-styled. Swipe right to RESET: the card shows a success
/// message in place, the mascot flips to success mode, then it fades and the rows
/// slide up as it resets to the bottom. Nudges escalate at 70/90/100%+; tap a card
/// for detail; header buttons = new / insights / settings.
struct TaskListView: View {
    @Environment(AppStore.self) private var store
    @Environment(CharacterStore.self) private var characters
    @State private var coordinator = NudgeCoordinator()
    @State private var detailTask: TaskDTO?
    @State private var showGlobal = false
    @State private var showCreate = false
    @State private var showSettings = false
    @State private var celebrating: [String: String] = [:]
    @State private var messageFaded: Set<String> = []

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
            List {
                ForEach(store.sortedActive) { task in
                    Button { detailTask = task } label: {
                        TaskCardView(task: task,
                                     nudge: coordinator.nudge(for: task.id),
                                     character: characters.image(for: task.id),
                                     celebration: celebrating[task.id],
                                     messageFaded: messageFaded.contains(task.id))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(WL.bg)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { celebrate(task) } label: {
                            Label("RESET", systemImage: "arrow.counterclockwise")
                        }
                        .tint(WL.accent)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 10, for: .scrollContent)
        }
    }

    /// Show a success beat in the card's place, then reset — so the row fades and the
    /// others slide up smoothly.
    private func celebrate(_ task: TaskDTO) {
        coordinator.clear(task.id)
        // 1) front content fades out, revealing the message layer behind
        withAnimation(.easeInOut(duration: 0.3)) { celebrating[task.id] = Celebrations.message() }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            // 2) the revealed message fades out
            withAnimation(.easeInOut(duration: 0.3)) { _ = messageFaded.insert(task.id) }
            try? await Task.sleep(for: .seconds(0.35))
            // 3) reset → the row reorders to the bottom and the others slide up
            withAnimation(.easeInOut(duration: 0.45)) {
                store.reset(id: task.id)
                celebrating[task.id] = nil
                messageFaded.remove(task.id)
            }
        }
    }
}

enum Celebrations {
    private static let lines = [
        "NICE.", "DONE — SEE YOU NEXT CYCLE.", "RESET. GOOD.", "CLEAN.",
        "LOCKED IN.", "FUTURE YOU SAYS THANKS.", "✓ ANOTHER REP.",
    ]
    static func message() -> String { lines.randomElement() ?? "NICE." }
}
