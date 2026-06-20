import SwiftUI
import UIKit

/// Full task panel — reads live from the store by id so actions reflect immediately.
/// Waveloop-styled. RESET / COMPLETE / LOG / DELETE + a per-task on-device insight,
/// plus the task's generated icon (from its title/description).
struct TaskDetailView: View {
    let taskId: String

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var descDraft = ""
    @State private var insightTask: TaskDTO?
    @State private var fuTitle = ""
    @State private var fuCadence: Double = 3600
    @State private var reminderDraft = ""
    /// In-detail navigation: tapping a follow-up pushes its id; back pops (or dismisses
    /// at the root). The shown task is the top of the stack.
    @State private var navStack: [String] = []

    private var currentId: String { navStack.last ?? taskId }
    private var task: TaskDTO? { store.task(currentId) }

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            if let task {
                ScrollView { body(task) }
                    .simultaneousGesture(swipeBack)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $insightTask) { t in
            InsightView(title: t.title) { await Insights.service().insight(for: t) }
                .presentationDetents([.medium, .large])
        }
        .onChange(of: navStack) { _, _ in descDraft = store.task(currentId)?.description ?? "" }
    }

    /// Open a follow-up's detail in place (save the current draft first).
    private func open(_ id: String) {
        store.setDescription(id: currentId, descDraft)
        navStack.append(id)
    }

    /// Back: pop to the parent task, or dismiss at the root. Saves the draft either way.
    private func back() {
        store.setDescription(id: currentId, descDraft)
        if navStack.isEmpty { dismiss() } else { navStack.removeLast() }
    }

    /// Left-edge swipe-right to go back (fullScreenCover has no built-in back gesture).
    /// Simultaneous so the ScrollView keeps scrolling; gated to a deliberate, mostly-
    /// horizontal drag that starts at the very left edge.
    private var swipeBack: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 24,
                      value.translation.width > 80,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5
                else { return }
                back()
            }
    }

    private func body(_ task: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // header
            HStack {
                Button { back() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WL.muted)
                }
                Spacer()
                Button { insightTask = task } label: {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WL.accent)
                }
            }

            Text(task.title.capitalized)
                .font(WL.mono(22, .bold)).tracking(1).foregroundStyle(WL.text)
                .fixedSize(horizontal: false, vertical: true)
            if !task.domain.isEmpty {
                Text(task.domain.uppercased()).font(WL.mono(11)).tracking(2).foregroundStyle(WL.muted)
            }

            // live meter
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let ratio = Urgency.ratio(task, now: ctx.date)
                VStack(alignment: .leading, spacing: 6) {
                    UrgencyBarView(ratio: ratio)
                    HStack {
                        Text(task.recurring ? "EVERY \(Format.duration(task.baseCadenceSeconds ?? 0).uppercased())" : "ONE-TIME")
                            .font(WL.mono(10)).tracking(1).foregroundStyle(WL.muted)
                        Spacer()
                        Text("\(Int(min(ratio, 9.99) * 100))%")
                            .font(WL.mono(11, .bold)).foregroundStyle(WL.urgencyColor(Urgency.tier(for: ratio)))
                    }
                }
            }

            section("DETAILS") {
                TextField("what is this? (flavors the icon + nudges)", text: $descDraft, axis: .vertical)
                    .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .lineLimit(1...4)
                    .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    .onSubmit { store.setDescription(id: task.id, descDraft) }
            }

            remindersSection(task)

            followUpsSection(task)

            // active switch (off = paused; the creature sleeps)
            HStack {
                Text("ACTIVE").font(WL.mono(12, .bold)).tracking(1).foregroundStyle(WL.text)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { task.status == .open },
                    set: { store.setActive(id: task.id, $0) }
                ))
                .labelsHidden()
                .tint(WL.accent)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .wlPanel(fill: WL.surface, border: WL.border)

            // quick log
            section("LOG A NOTE") {
                HStack(spacing: 8) {
                    TextField("what did you do?", text: $note)
                        .font(WL.mono(13)).foregroundStyle(WL.text)
                        .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    Button {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.addNote(id: task.id, note: trimmed); note = ""
                    } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(WL.bg)
                            .frame(width: 40, height: 40).background(WL.accent)
                    }
                }
            }

            if !task.actionLog.isEmpty {
                section("HISTORY") {
                    ForEach(Array(task.actionLog.suffix(12).reversed().enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.action.rawValue.uppercased())
                                .font(WL.mono(9, .bold)).tracking(1)
                                .foregroundStyle(actionColor(entry.action))
                                .frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                if !entry.note.isEmpty {
                                    Text(entry.note).font(WL.mono(12)).foregroundStyle(WL.text)
                                }
                                Text(entry.at.formatted(date: .abbreviated, time: .shortened))
                                    .font(WL.mono(9)).foregroundStyle(WL.muted)
                            }
                        }
                    }
                }
            }

            Button(role: .destructive) {
                store.delete(id: task.id); dismiss()
            } label: {
                Text("DELETE").font(WL.mono(11, .bold)).tracking(2)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(WL.red).overlay(Rectangle().stroke(WL.red.opacity(0.5), lineWidth: 1))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .onAppear { descDraft = task.description }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Editable tag list of reminder phrases (the rotating nudge prompts).
    @ViewBuilder
    private func remindersSection(_ task: TaskDTO) -> some View {
        section("REMINDERS") {
            VStack(alignment: .leading, spacing: 10) {
                if !task.prompts.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(task.prompts.enumerated()), id: \.offset) { idx, p in
                            HStack(spacing: 6) {
                                Text(p).font(WL.mono(11)).foregroundStyle(WL.text)
                                Button { store.removeReminder(id: task.id, at: idx) } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(WL.muted)
                                }
                            }
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .wlPanel(fill: WL.surface, border: WL.border)
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("add a reminder", text: $reminderDraft)
                        .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                        .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                        .onSubmit { addReminder(task) }
                    Button { addReminder(task) } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(WL.bg)
                            .frame(width: 40, height: 40).background(WL.accent)
                    }
                }
            }
        }
    }

    private func addReminder(_ task: TaskDTO) {
        store.addReminder(id: task.id, reminderDraft)
        reminderDraft = ""
    }

    /// Follow-ups are real, non-repeating CHILD tasks. Each row opens that task's own detail
    /// (configure it, give it its own follow-ups). They stay dormant — tucked away here, off
    /// the main list — until the chain is launched (right swipe on the list).
    @ViewBuilder
    private func followUpsSection(_ task: TaskDTO) -> some View {
        section("FOLLOW-UPS") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.children(of: task.id)) { child in
                    HStack(spacing: 8) {
                        Button { open(child.id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: followUpIcon(child))
                                    .font(.system(size: 11, weight: .bold)).foregroundStyle(followUpColor(child))
                                Text(child.title.capitalized).font(WL.mono(12)).foregroundStyle(WL.text).lineLimit(1)
                                Spacer(minLength: 6)
                                if store.isDormantFollowUp(child) {
                                    Text("· \(CadenceOptions.label(child.baseCadenceSeconds ?? 0))")
                                        .font(WL.mono(9)).foregroundStyle(WL.muted)
                                }
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity)
                            .wlPanel(fill: WL.surface, border: WL.border)
                        }
                        .buttonStyle(.plain)
                        Button { store.delete(id: child.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                                .frame(width: 30, height: 30).overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("add a follow-up", text: $fuTitle)
                        .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                        .autocorrectionDisabled()
                        .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    Menu {
                        ForEach(CadenceOptions.all, id: \.value) { opt in
                            Button(opt.label) { fuCadence = opt.value }
                        }
                    } label: {
                        Text(CadenceOptions.label(fuCadence)).font(WL.mono(11, .bold)).foregroundStyle(WL.accent)
                            .frame(minWidth: 60).padding(.vertical, 11).padding(.horizontal, 8)
                            .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                    }
                    Button {
                        store.addFollowUp(parentId: task.id, title: fuTitle, cadenceSeconds: fuCadence)
                        fuTitle = ""
                    } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(WL.bg)
                            .frame(width: 40, height: 40).background(WL.accent)
                    }
                }

                Text("each follow-up is its own non-repeating task — tap to open it (and give it follow-ups). They stay tucked away until you mark this task DONE (right swipe in the list); left swipe just resets the timer without firing them.")
                    .font(WL.mono(9)).foregroundStyle(WL.muted)
            }
        }
    }

    private func followUpIcon(_ t: TaskDTO) -> String {
        if t.status == .done { return "checkmark.circle.fill" }
        return store.isDormantFollowUp(t) ? "circle" : "circle.fill"
    }
    private func followUpColor(_ t: TaskDTO) -> Color {
        if t.status == .done { return WL.green }
        return store.isDormantFollowUp(t) ? WL.muted : WL.accent
    }

    private func actionColor(_ a: ActionType) -> Color {
        switch a {
        case .reset: WL.accent
        case .complete, .done: WL.green
        case .lapsed: WL.red
        case .note: WL.muted
        case .skipped: WL.cyan
        }
    }
}
