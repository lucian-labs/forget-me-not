import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var descriptionText = ""
    @State private var newPrompt = ""
    @State private var newFollowUpTitle = ""
    @State private var newFollowUpCadence: Double = 86400
    @State private var newNote = ""
    @State private var showMore = false

    private var task: FMNTask? {
        store.tasks.first { $0.id == taskId }
    }

    var body: some View {
        let _ = store.tick

        Group {
            if let task {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        taskHeader(task)
                        statusBadges(task)
                        descriptionSection(task)
                        remindersSection(task)
                        followUpsSection(task)
                        actionsRow(task)
                        moreSection(task)
                    }
                    .padding()
                }
                .background(store.theme.bg.ignoresSafeArea())
            } else {
                ContentUnavailableView("Task not found", systemImage: "questionmark.circle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let task {
                titleText = task.title
                descriptionText = task.description
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func taskHeader(_ task: FMNTask) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if editingTitle {
                TextField("Title", text: $titleText)
                    .font(store.theme.header(size: 22, weight: .bold))
                    .foregroundStyle(store.theme.accent)
                    .onSubmit {
                        store.updateTask(id: task.id) { $0.title = titleText }
                        editingTitle = false
                    }
            } else {
                Text(task.title)
                    .font(store.theme.header(size: 22, weight: .bold))
                    .foregroundStyle(store.theme.accent)
                    .onTapGesture { editingTitle = true }
            }

            Spacer()

            if !task.domain.isEmpty {
                Text(task.domain)
                    .font(.caption)
                    .foregroundStyle(store.theme.cyan)
            }
        }
    }

    // MARK: - Status

    @ViewBuilder
    private func statusBadges(_ task: FMNTask) -> some View {
        HStack(spacing: 8) {
            if task.recurring {
                badge("recurring", color: store.theme.accent)
                if let cadence = task.cadenceSeconds {
                    Text("every \(formatCadence(cadence))")
                        .font(.caption)
                        .foregroundStyle(store.theme.dim)
                }
                if let lastReset = task.lastResetAt, let cadence = task.cadenceSeconds {
                    let elapsed = Date().timeIntervalSince(lastReset)
                    let remaining = cadence - elapsed
                    let text = remaining > 0 ? "\(formatTime(remaining)) left" : "\(formatTime(abs(remaining))) over"
                    Text(text)
                        .font(.caption.bold())
                        .foregroundStyle(urgencyColor(task.urgencyRatio))
                }
            } else {
                Menu {
                    ForEach([TaskStatus.open, .inProgress, .blocked, .done, .cancelled], id: \.self) { status in
                        Button(status.label) {
                            store.updateTask(id: task.id) { $0.status = status }
                        }
                    }
                } label: {
                    badge(task.status.label, color: store.theme.accent)
                }
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionSection(_ task: FMNTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Description")
            TextEditor(text: $descriptionText)
                .font(.system(size: 14))
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(store.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: store.theme.borderRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: store.theme.borderRadius)
                        .stroke(store.theme.border, lineWidth: 1)
                )
                .onChange(of: descriptionText) { _, val in
                    store.updateTask(id: task.id) { $0.description = val }
                }
        }
    }

    // MARK: - Reminders

    @ViewBuilder
    private func remindersSection(_ task: FMNTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Reminders")

            ForEach(Array(task.prompts.enumerated()), id: \.offset) { idx, prompt in
                HStack(spacing: 6) {
                    Text(prompt)
                        .font(.system(size: 13))
                        .foregroundStyle(store.theme.text)
                    Spacer()
                    Button {
                        store.updateTask(id: task.id) { $0.prompts.remove(at: idx) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(store.theme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            TextField("Add a reminder...", text: $newPrompt)
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let trimmed = newPrompt.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.updateTask(id: task.id) { $0.prompts.append(trimmed) }
                    newPrompt = ""
                }
        }
    }

    // MARK: - Follow-ups

    @ViewBuilder
    private func followUpsSection(_ task: FMNTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Follow-up Chain")

            if !task.followUps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(task.followUps.enumerated()), id: \.offset) { idx, fu in
                            if idx > 0 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(store.theme.dim)
                            }
                            HStack(spacing: 4) {
                                Text("\(fu.title) (\(formatCadence(fu.cadenceSeconds)))")
                                    .font(.caption)
                                Button {
                                    store.updateTask(id: task.id) { $0.followUps.remove(at: idx) }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(store.theme.dim)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(store.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(store.theme.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Follow-up title...", text: $newFollowUpTitle)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)

                Picker("", selection: $newFollowUpCadence) {
                    ForEach(cadenceOptions, id: \.value) { opt in
                        Text(opt.label).tag(opt.value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Button {
                    let trimmed = newFollowUpTitle.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.updateTask(id: task.id) {
                        $0.followUps.append(FollowUp(title: trimmed, cadenceSeconds: newFollowUpCadence))
                    }
                    newFollowUpTitle = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(store.theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsRow(_ task: FMNTask) -> some View {
        HStack(spacing: 12) {
            if task.recurring {
                Button("Reset") {
                    store.resetTask(id: task.id, note: "")
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Complete") {
                store.completeTask(id: task.id, note: "")
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Archive") {
                store.archiveTask(id: task.id)
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Spacer()
        }
    }

    // MARK: - More

    @ViewBuilder
    private func moreSection(_ task: FMNTask) -> some View {
        DisclosureGroup("More", isExpanded: $showMore) {
            VStack(alignment: .leading, spacing: 16) {
                // Category
                HStack {
                    label("Category")
                    Picker("", selection: Binding(
                        get: { task.domain },
                        set: { val in store.updateTask(id: task.id) { $0.domain = val } }
                    )) {
                        Text("\u{2014}").tag("")
                        ForEach(store.settings.domains, id: \.self) { d in
                            Text(d).tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Type
                HStack {
                    label("Type")
                    Picker("", selection: Binding(
                        get: { task.recurring },
                        set: { val in
                            store.updateTask(id: task.id) {
                                $0.recurring = val
                                if val && $0.lastResetAt == nil { $0.lastResetAt = Date() }
                            }
                        }
                    )) {
                        Text("Recurring").tag(true)
                        Text("One-time").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // Cadence
                if task.recurring {
                    HStack {
                        label("Every")
                        Picker("", selection: Binding(
                            get: { task.cadenceSeconds ?? 86400 },
                            set: { val in store.updateTask(id: task.id) { $0.cadenceSeconds = val } }
                        )) {
                            ForEach(cadenceOptions, id: \.value) { Text($0.label).tag($0.value) }
                        }
                        .pickerStyle(.menu)
                    }

                    // Cadence variance (randomizes on reset)
                    HStack {
                        label("Less (min)")
                        TextField("0", value: Binding(
                            get: { Int((task.cadenceLess ?? 0) / 60) },
                            set: { val in store.updateTask(id: task.id) { $0.cadenceLess = Double(val) * 60 } }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }
                    HStack {
                        label("More (min)")
                        TextField("0", value: Binding(
                            get: { Int((task.cadenceMore ?? 0) / 60) },
                            set: { val in store.updateTask(id: task.id) { $0.cadenceMore = Double(val) * 60 } }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    }
                }

                // Priority
                HStack {
                    label("Priority")
                    Picker("", selection: Binding(
                        get: { task.priority },
                        set: { val in store.updateTask(id: task.id) { $0.priority = val } }
                    )) {
                        ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Info
                detailRow("Tags", task.tags.isEmpty ? "\u{2014}" : task.tags.joined(separator: ", "))
                detailRow("Created", timeAgo(task.createdAt))
                detailRow("Updated", timeAgo(task.updatedAt))
                if let due = task.dueDate { detailRow("Due", due.formatted()) }

                if let parentId = task.parentTaskId {
                    HStack {
                        label("Parent")
                        NavigationLink(value: parentId) {
                            Text("View parent")
                                .font(.caption)
                                .foregroundStyle(store.theme.accent)
                        }
                    }
                }

                // Action log
                actionLog(task)
            }
            .padding(.top, 8)
        }
        .tint(store.theme.dim)
    }

    // MARK: - Action Log

    @ViewBuilder
    private func actionLog(_ task: FMNTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Action Log")

            if task.actionLog.isEmpty {
                Text("No actions yet.")
                    .font(.caption)
                    .foregroundStyle(store.theme.dim)
            } else {
                ForEach(task.actionLog.reversed()) { entry in
                    HStack(spacing: 8) {
                        Text(entry.action.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(logColor(entry.action).opacity(0.15))
                            .foregroundStyle(logColor(entry.action))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text(entry.note.isEmpty ? "\u{2014}" : entry.note)
                            .font(.caption)
                            .foregroundStyle(store.theme.text)
                            .lineLimit(1)

                        Spacer()

                        Text(timeAgo(entry.at))
                            .font(.system(size: 10))
                            .foregroundStyle(store.theme.dim)
                    }
                }
            }

            TextField("Add a note...", text: $newNote)
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let trimmed = newNote.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    store.addNote(id: task.id, note: trimmed)
                    newNote = ""
                }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(store.theme.dim)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(store.theme.dim)
            .frame(width: 80, alignment: .leading)
    }

    private func detailRow(_ lbl: String, _ value: String) -> some View {
        HStack {
            label(lbl)
            Text(value).font(.caption)
            Spacer()
        }
    }

    private func urgencyColor(_ ratio: Double) -> Color {
        if ratio < 0.75 { return store.theme.green }
        if ratio < 0.95 { return store.theme.orange }
        return store.theme.red
    }

    private func logColor(_ action: ActionType) -> Color {
        switch action {
        case .reset: store.theme.accent
        case .complete: store.theme.green
        case .note: store.theme.dim
        }
    }
}
