import SwiftUI
import UIKit

/// Full task panel — reads live from the store by id so actions reflect immediately.
/// Waveloop-styled. RESET / COMPLETE / LOG / DELETE + a per-task on-device insight,
/// plus the task's generated icon (from its title/description).
struct TaskDetailView: View {
    let taskId: String

    @Environment(AppStore.self) private var store
    @Environment(IconStore.self) private var icons
    @Environment(AlertSounder.self) private var sounder
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var descDraft = ""
    @State private var seedDraft = ""
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
        .preferredColorScheme(WL.isLight ? .light : .dark)
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
        VStack(alignment: .leading, spacing: WL.pad(20)) {
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
                .font(WL.header(22, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.text)
                .fixedSize(horizontal: false, vertical: true)
            if !task.domain.isEmpty {
                Text(WL.t(task.domain)).font(WL.body(11)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
            }

            // live meter
            TimelineView(.periodic(from: .now, by: 5)) { ctx in
                let ratio = Urgency.ratio(task, now: ctx.date)
                VStack(alignment: .leading, spacing: 6) {
                    UrgencyBarView(ratio: ratio)
                    HStack {
                        Text(WL.t(task.recurring ? "every \(Format.duration(task.baseCadenceSeconds ?? 0))" : "one-time"))
                            .font(WL.body(10)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                        Spacer()
                        Text("\(Int(min(ratio, 9.99) * 100))%")
                            .font(WL.mono(11, .bold)).foregroundStyle(WL.urgencyColor(Urgency.tier(for: ratio)))
                    }
                }
            }

            sigilSection(task)

            section("Details") {
                TextField("what is this? (flavors the icon + nudges)", text: $descDraft, axis: .vertical)
                    .font(WL.body(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .lineLimit(1...4)
                    .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    .onSubmit { store.setDescription(id: task.id, descDraft) }
            }

            remindersSection(task)

            soundSection(task)

            followUpsSection(task)

            // active switch (off = paused; the creature sleeps)
            HStack {
                Text(WL.t("Active")).font(WL.header(12, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.text)
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
            section("Log a Note") {
                HStack(spacing: 8) {
                    TextField("what did you do?", text: $note)
                        .font(WL.body(13)).foregroundStyle(WL.text)
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

            // snoozed (zz) + restarted (↓) are telemetry-only: logged for cadence
            // analysis but kept out of the user-facing history to preserve the "quiet"
            // feel of both actions.
            let visibleLog = task.actionLog.filter { $0.action != .snoozed && $0.action != .restarted }
            if !visibleLog.isEmpty {
                section("History") {
                    ForEach(Array(visibleLog.suffix(12).reversed().enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(WL.t(entry.action.rawValue))
                                .font(WL.body(9, .bold)).tracking(WL.trk(1))
                                .foregroundStyle(actionColor(entry.action))
                                .frame(width: 64, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                if !entry.note.isEmpty {
                                    Text(entry.note).font(WL.body(12)).foregroundStyle(WL.text)
                                }
                                Text(entry.at.formatted(date: .abbreviated, time: .shortened))
                                    .font(WL.body(9)).foregroundStyle(WL.muted)
                            }
                        }
                    }
                }
            }

            Button(role: .destructive) {
                store.delete(id: task.id); dismiss()
            } label: {
                Text(WL.t("Delete")).font(WL.header(11, .bold)).tracking(WL.trk(2))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(WL.red).wlStroke(WL.red.opacity(0.5))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .onAppear {
            descDraft = task.description
            seedDraft = task.soundSeed ?? ""
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WL.t(title)).font(WL.header(10, .bold)).tracking(WL.trk(2)).foregroundStyle(WL.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// This task's generative ringtone: hear it, see the seed it grows from, or plant a
    /// custom one. Empty seed = the task's id (shown as the placeholder).
    @ViewBuilder
    private func soundSection(_ task: TaskDTO) -> some View {
        section("Sound") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    // Commit the seed draft first — otherwise a typed-but-not-submitted
                    // seed would replay the old tune (the "seed didn't change it" bug).
                    store.setTaskSoundSeed(id: task.id, seedDraft)
                    if let fresh = store.task(task.id) {
                        sounder.preview(fresh, config: store.soundConfig)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 13, weight: .bold))
                        Text(WL.t("Hear Its Tune")).font(WL.header(12, .bold)).tracking(WL.trk(1))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(WL.bg).background(WL.accent)
                }
                HStack(spacing: 8) {
                    Text(WL.t("Seed")).font(WL.header(9, .bold)).tracking(WL.trk(1)).foregroundStyle(WL.muted)
                    TextField(task.id, text: $seedDraft)
                        .font(WL.body(11)).foregroundStyle(WL.text).tint(WL.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            store.setTaskSoundSeed(id: task.id, seedDraft)
                            if let t = store.task(task.id) { sounder.preview(t, config: store.soundConfig) }
                        }
                        .padding(8).wlPanel(fill: WL.surface, border: WL.border)
                }
                Text("Its tune grows from this seed — type any word to give it a new one, blank uses its id.")
                    .font(WL.body(9)).foregroundStyle(WL.muted)
            }
        }
    }

    /// The task's gold-ink sigil + a regenerate control. Shows the current glyph, a spinner
    /// while conjuring, or a placeholder; the button re-rolls it (fresh prompt each time).
    @ViewBuilder
    private func sigilSection(_ task: TaskDTO) -> some View {
        section("Sigil") {
            VStack(spacing: 12) {
                ZStack {
                    if let img = icons.image(for: task.id) {
                        Image(uiImage: img).resizable().scaledToFit().padding(12)
                    } else if icons.isGenerating(task.id) {
                        ProgressView().tint(WL.accent)
                    } else if icons.didFail(task.id) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundStyle(WL.muted.opacity(0.5))
                    } else {
                        Image(systemName: "sparkles").font(.system(size: 28)).foregroundStyle(WL.muted.opacity(0.35))
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .wlPanel(fill: WL.surface, border: WL.border)

                if icons.available {
                    Button {
                        Task { await icons.generate(for: task) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 13, weight: .bold))
                            Text(icons.isGenerating(task.id) ? "CONJURING…" : "REGENERATE SIGIL")
                                .font(WL.body(11, .bold)).tracking(WL.trk(1))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .foregroundStyle(WL.accent)
                    }
                    .wlStroke(WL.accent)
                    .disabled(icons.isGenerating(task.id))
                }
            }
        }
    }

    /// Editable tag list of reminder phrases (the rotating nudge prompts).
    @ViewBuilder
    private func remindersSection(_ task: TaskDTO) -> some View {
        section("Reminders") {
            VStack(alignment: .leading, spacing: 10) {
                if !task.prompts.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(task.prompts.enumerated()), id: \.offset) { idx, p in
                            HStack(spacing: 6) {
                                Text(p).font(WL.body(11)).foregroundStyle(WL.text)
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
                        .font(WL.body(13)).foregroundStyle(WL.text).tint(WL.accent)
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
        section("Follow-Ups") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.children(of: task.id)) { child in
                    HStack(spacing: 8) {
                        Button { open(child.id) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: followUpIcon(child))
                                    .font(.system(size: 11, weight: .bold)).foregroundStyle(followUpColor(child))
                                Text(child.title.capitalized).font(WL.body(12)).foregroundStyle(WL.text).lineLimit(1)
                                Spacer(minLength: 6)
                                if store.isDormantFollowUp(child) {
                                    Text("· \(CadenceOptions.label(child.baseCadenceSeconds ?? 0))")
                                        .font(WL.body(9)).foregroundStyle(WL.muted)
                                }
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 9).frame(maxWidth: .infinity)
                            .wlPanel(fill: WL.surface, border: WL.border)
                        }
                        .buttonStyle(.plain)
                        Button { store.delete(id: child.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                                .frame(width: 30, height: 30).wlStroke(WL.border)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("add a follow-up", text: $fuTitle)
                        .font(WL.body(13)).foregroundStyle(WL.text).tint(WL.accent)
                        .autocorrectionDisabled()
                        .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    Menu {
                        ForEach(CadenceOptions.all, id: \.value) { opt in
                            Button(opt.label) { fuCadence = opt.value }
                        }
                    } label: {
                        Text(CadenceOptions.label(fuCadence)).font(WL.body(11, .bold)).foregroundStyle(WL.accent)
                            .frame(minWidth: 60).padding(.vertical, 11).padding(.horizontal, 8)
                            .wlStroke(WL.border)
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
                    .font(WL.body(9)).foregroundStyle(WL.muted)
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
        case .snoozed, .restarted: WL.muted   // telemetry-only, not rendered
        }
    }
}
