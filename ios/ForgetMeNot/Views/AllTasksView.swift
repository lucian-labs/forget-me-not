import SwiftUI

/// Every task, active and not. The main list only shows active loops; this surfaces dormant
/// follow-ups and inactive (paused / done) tasks too. Drag an inactive or dormant task up
/// into ACTIVE to put it back into action; tap any row to open its detail.
struct AllTasksView: View {
    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(AlertSounder.self) private var sounder
    @Environment(\.dismiss) private var dismiss
    @State private var detailTask: TaskDTO?
    @State private var dropTargeted = false

    private var active: [TaskDTO] {
        store.tasks.filter { $0.status == .open || $0.status == .inProgress }
            .filter { !store.isDormantFollowUp($0) }
            .sorted { Urgency.ratio($0) > Urgency.ratio($1) }
    }
    private var dormant: [TaskDTO] {
        store.tasks.filter { store.isDormantFollowUp($0) }.sorted { $0.title < $1.title }
    }
    private var inactive: [TaskDTO] {
        store.tasks.filter { $0.status == .done || $0.status == .blocked }
            .sorted { ($0.updatedAt) > ($1.updatedAt) }
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

                    // ACTIVE — the drop target. Drag inactive/dormant rows here to activate.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVE").font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.accent)
                        if active.isEmpty {
                            Text("drop a task here to activate it")
                                .font(WL.mono(9)).foregroundStyle(WL.muted)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                        } else {
                            ForEach(active) { row($0) }
                        }
                    }
                    .padding(8)
                    .background(dropTargeted ? WL.accent.opacity(0.12) : Color.clear)
                    .overlay(Rectangle().stroke(dropTargeted ? WL.accent : Color.clear, lineWidth: 1))
                    .dropDestination(for: String.self) { ids, _ in
                        ids.forEach { store.reactivate(id: $0) }
                        return !ids.isEmpty
                    } isTargeted: { dropTargeted = $0 }

                    if !dormant.isEmpty { group("FOLLOW-UPS · DORMANT", dormant) }
                    if !inactive.isEmpty { group("INACTIVE", inactive) }

                    Text("drag a task up into ACTIVE to put it back in action")
                        .font(WL.mono(9)).foregroundStyle(WL.muted)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $detailTask) { t in
            TaskDetailView(taskId: t.id).environment(store).environment(icons).environment(sounder)
        }
    }

    /// A draggable group (dormant + inactive rows can be dragged into ACTIVE).
    @ViewBuilder private func group(_ title: String, _ tasks: [TaskDTO]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            ForEach(tasks) { task in
                row(task).draggable(task.id)
            }
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
