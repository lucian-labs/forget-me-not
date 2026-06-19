import SwiftUI
import UIKit

/// Full task panel — reads live from the store by id so actions reflect immediately.
/// Waveloop-styled. RESET / COMPLETE / LOG / DELETE + a per-task on-device insight,
/// plus the task's generated alien-animal mascot.
struct TaskDetailView: View {
    let taskId: String

    @Environment(AppStore.self) private var store
    @Environment(CharacterStore.self) private var characters
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var descDraft = ""
    @State private var insightTask: TaskDTO?
    @State private var fuTitle = ""
    @State private var fuCadence: Double = 3600

    private var task: TaskDTO? { store.task(taskId) }

    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            if let task {
                ScrollView { body(task) }
                    .simultaneousGesture(swipeToClose(task))
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $insightTask) { t in
            InsightView(title: t.title) { await Insights.service().insight(for: t) }
                .presentationDetents([.medium, .large])
        }
    }

    /// Save the in-flight description draft, then dismiss.
    private func closeSaving(_ task: TaskDTO) {
        store.setDescription(id: task.id, descDraft)
        dismiss()
    }

    /// Left-edge swipe-right to close (fullScreenCover has no built-in back gesture).
    /// Simultaneous so the ScrollView keeps scrolling; gated to a deliberate, mostly-
    /// horizontal drag that starts at the very left edge.
    private func swipeToClose(_ task: TaskDTO) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 24,
                      value.translation.width > 80,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5
                else { return }
                closeSaving(task)
            }
    }

    private func body(_ task: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // header
            HStack {
                Button { closeSaving(task) } label: {
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

            characterBlock(task)

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
                TextField("what is this? (flavors the mascot + nudges)", text: $descDraft, axis: .vertical)
                    .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                    .lineLimit(1...4)
                    .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    .onSubmit { store.setDescription(id: task.id, descDraft) }
            }

            if !task.prompts.isEmpty {
                section("REMINDERS") {
                    ForEach(task.prompts, id: \.self) { p in
                        Text("· \(p)").font(WL.mono(12)).foregroundStyle(WL.muted)
                    }
                }
            }

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
    private func characterBlock(_ task: TaskDTO) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Group {
                    if let img = characters.image(for: task.id) {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        ZStack {
                            Rectangle().fill(WL.surface)
                            Image(systemName: "sparkle").font(.system(size: 30)).foregroundStyle(WL.muted.opacity(0.4))
                        }
                    }
                }
                .opacity(task.status == .blocked ? 0.5 : 1)
                .grayscale(task.status == .blocked ? 0.9 : 0)
                if task.status == .blocked {
                    Image(systemName: "zzz").font(.system(size: 34, weight: .bold)).foregroundStyle(WL.muted)
                }
            }
            .frame(height: 180).frame(maxWidth: .infinity).clipped()
            .overlay(Rectangle().stroke(WL.border, lineWidth: 1))

            if characters.available {
                Button { Task { await characters.generate(for: task) } } label: {
                    HStack(spacing: 8) {
                        if characters.isGenerating(task.id) {
                            ProgressView().controlSize(.small).tint(WL.bg)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                        }
                        Text(characters.image(for: task.id) == nil ? "GENERATE ANIMAL" : "NEW ANIMAL")
                            .font(WL.mono(12, .bold)).tracking(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .foregroundStyle(WL.bg).background(WL.accent)
                }
                .disabled(characters.isGenerating(task.id))
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WL.mono(10, .bold)).tracking(2).foregroundStyle(WL.muted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let cadenceOptions: [(label: String, value: Double)] = [
        ("15 min", 900), ("30 min", 1800), ("1 hour", 3600), ("1.5 hours", 5400),
        ("2 hours", 7200), ("4 hours", 14400), ("8 hours", 28800),
        ("1 day", 86400), ("2 days", 172800), ("1 week", 604800),
    ]
    private func cadenceLabel(_ v: Double) -> String {
        Self.cadenceOptions.first { $0.value == v }?.label ?? Format.duration(v)
    }

    /// The follow-up chain: queued steps (each spawns on reset/complete), an add row, and
    /// the tasks already spawned from this one. Mirrors the web detail panel.
    @ViewBuilder
    private func followUpsSection(_ task: TaskDTO) -> some View {
        section("FOLLOW-UPS") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(task.followUps.enumerated()), id: \.offset) { idx, fu in
                    HStack(spacing: 8) {
                        Text("\(idx + 1)").font(WL.mono(9, .bold)).foregroundStyle(WL.bg)
                            .frame(width: 18, height: 18).background(WL.accent)
                        Text(fu.title).font(WL.mono(12)).foregroundStyle(WL.text).lineLimit(1)
                        Text("· \(cadenceLabel(fu.cadenceSeconds))").font(WL.mono(10)).foregroundStyle(WL.muted)
                        Spacer(minLength: 6)
                        Button { store.removeFollowUp(id: task.id, at: idx) } label: {
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .wlPanel(fill: WL.surface, border: WL.border)
                }

                HStack(spacing: 8) {
                    TextField("follow-up title", text: $fuTitle)
                        .font(WL.mono(13)).foregroundStyle(WL.text).tint(WL.accent)
                        .padding(10).wlPanel(fill: WL.surface, border: WL.border)
                    Menu {
                        ForEach(Self.cadenceOptions, id: \.value) { opt in
                            Button(opt.label) { fuCadence = opt.value }
                        }
                    } label: {
                        Text(cadenceLabel(fuCadence)).font(WL.mono(11, .bold)).foregroundStyle(WL.accent)
                            .frame(minWidth: 60).padding(.vertical, 11).padding(.horizontal, 8)
                            .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
                    }
                    Button {
                        store.addFollowUp(id: task.id, title: fuTitle, cadenceSeconds: fuCadence)
                        fuTitle = ""
                    } label: {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(WL.bg)
                            .frame(width: 40, height: 40).background(WL.accent)
                    }
                }

                let kids = store.children(of: task.id)
                if !kids.isEmpty {
                    Text("SPAWNED").font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.muted).padding(.top, 4)
                    ForEach(kids) { child in
                        HStack(spacing: 8) {
                            Text(child.title).font(WL.mono(12)).foregroundStyle(WL.accent).lineLimit(1)
                            Spacer(minLength: 6)
                            if !child.followUps.isEmpty {
                                Text("+\(child.followUps.count)").font(WL.mono(9)).foregroundStyle(WL.muted)
                            }
                            Text(child.status.rawValue.uppercased()).font(WL.mono(9, .bold))
                                .foregroundStyle(child.status == .done ? WL.green : WL.muted)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .wlPanel(fill: WL.surface, border: WL.border)
                    }
                }
            }
        }
    }

    private func actionColor(_ a: ActionType) -> Color {
        switch a {
        case .reset: WL.accent
        case .complete: WL.green
        case .lapsed: WL.red
        case .note: WL.muted
        }
    }
}
