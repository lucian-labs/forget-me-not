import SwiftUI

/// Every task, active and not — grouped by state. The main list only shows active loops;
/// this surfaces dormant follow-ups, paused tasks, and completed ones too. Tap any to open it.
struct AllTasksView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(\.dismiss) private var dismiss
    @State private var detailTask: TaskDTO?

    private var groups: [(title: String, tasks: [TaskDTO])] {
        var active: [TaskDTO] = [], paused: [TaskDTO] = [], dormant: [TaskDTO] = [], done: [TaskDTO] = []
        for t in store.tasks {
            if t.status == .done { done.append(t) }
            else if t.status == .archived || t.status == .cancelled { continue }
            else if t.status == .blocked { paused.append(t) }
            else if store.isDormantFollowUp(t) { dormant.append(t) }
            else { active.append(t) }
        }
        active.sort { Urgency.ratio($0) > Urgency.ratio($1) }
        dormant.sort { $0.title < $1.title }
        done.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return [("ACTIVE", active), ("FOLLOW-UPS · DORMANT", dormant), ("PAUSED", paused), ("DONE", done)]
            .filter { !$0.1.isEmpty }
    }

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("ALL TASKS").font(WL.mono(15, .bold)).tracking(3).foregroundStyle(WL.text)
                        Spacer()
                        Text("\(store.tasks.count)").font(WL.mono(12, .bold)).foregroundStyle(WL.muted)
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }
                    ForEach(groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.accent)
                            ForEach(group.tasks) { row($0) }
                        }
                    }
                    if store.tasks.isEmpty {
                        Text("NO TASKS").font(WL.mono(12, .bold)).tracking(2).foregroundStyle(WL.muted)
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $detailTask) { t in
            TaskDetailView(taskId: t.id).environment(store).environment(icons)
        }
    }

    private func row(_ task: TaskDTO) -> some View {
        Button { detailTask = task } label: {
            HStack(spacing: 10) {
                Image(systemName: leadingIcon(task))
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(leadingColor(task))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title.capitalized).font(WL.mono(13, .semibold)).foregroundStyle(WL.text).lineLimit(1)
                    if !task.domain.isEmpty {
                        Text(task.domain.uppercased()).font(WL.mono(8, .bold)).tracking(1).foregroundStyle(WL.muted)
                    }
                }
                Spacer(minLength: 6)
                if task.status != .done, task.recurring || task.dueDate != nil {
                    let r = Urgency.ratio(task)
                    Text("\(Int(min(r, 9.99) * 100))%")
                        .font(WL.mono(10, .bold)).foregroundStyle(WL.urgencyColor(Urgency.tier(for: r)))
                }
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .wlPanel(fill: WL.surface, border: WL.border)
        }
        .buttonStyle(.plain)
    }

    private func leadingIcon(_ t: TaskDTO) -> String {
        if t.status == .done { return "checkmark.circle.fill" }
        if t.status == .blocked { return "pause.circle" }
        if t.recurring { return "arrow.triangle.2.circlepath" }
        if store.isDormantFollowUp(t) { return "circle" }
        return "circle.fill"
    }
    private func leadingColor(_ t: TaskDTO) -> Color {
        if t.status == .done { return WL.green }
        if t.status == .blocked || store.isDormantFollowUp(t) { return WL.muted }
        return WL.accent
    }
}
