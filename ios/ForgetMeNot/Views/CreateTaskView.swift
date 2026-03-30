import SwiftUI

struct CreateTaskView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var isRecurring = true
    @State private var cadence: Double = 86400
    @State private var domain = ""
    @State private var priority: TaskPriority = .normal
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var tags = ""
    @State private var notes = ""
    @State private var followUps: [FollowUp] = []
    @State private var prompts: [String] = []
    @State private var newFollowUpTitle = ""
    @State private var newFollowUpCadence: Double = 86400
    @State private var newPrompt = ""
    @State private var showAdvanced = false
    @State private var createdTasks: [FMNTask] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleRow
                cadenceAndCategory
                followUpsSection
                remindersSection
                advancedSection
                createButton

                if !createdTasks.isEmpty {
                    createdList
                }
            }
            .padding()
        }
        .background(store.theme.bg.ignoresSafeArea())
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear { titleFocused = true }
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack(spacing: 12) {
            TextField("What needs doing...", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)

            Toggle(isOn: $isRecurring) {
                Text(isRecurring ? "repeats" : "once")
                    .font(.caption)
                    .foregroundStyle(store.theme.dim)
            }
            .toggleStyle(.switch)
            .labelsHidden()

            Text(isRecurring ? "repeats" : "once")
                .font(.caption)
                .foregroundStyle(store.theme.dim)
        }
    }

    // MARK: - Cadence + Category

    private var cadenceAndCategory: some View {
        HStack(spacing: 16) {
            if isRecurring {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every").font(.caption).foregroundStyle(store.theme.dim)
                    Picker("", selection: $cadence) {
                        ForEach(cadenceOptions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Category").font(.caption).foregroundStyle(store.theme.dim)
                Picker("", selection: $domain) {
                    Text("\u{2014}").tag("")
                    ForEach(store.settings.domains, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: - Follow-ups

    private var followUpsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Follow-ups").font(.caption).foregroundStyle(store.theme.dim)

            if !followUps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(followUps.enumerated()), id: \.offset) { idx, fu in
                            if idx > 0 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(store.theme.dim)
                            }
                            HStack(spacing: 4) {
                                Text("\(fu.title) (\(formatCadence(fu.cadenceSeconds)))")
                                    .font(.caption)
                                Button { followUps.remove(at: idx) } label: {
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
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Next step...", text: $newFollowUpTitle)
                    .font(.system(size: 13))
                    .textFieldStyle(.roundedBorder)

                Picker("", selection: $newFollowUpCadence) {
                    ForEach(cadenceOptions, id: \.value) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Button {
                    let trimmed = newFollowUpTitle.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    followUps.append(FollowUp(title: trimmed, cadenceSeconds: newFollowUpCadence))
                    newFollowUpTitle = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(store.theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminders").font(.caption).foregroundStyle(store.theme.dim)

            ForEach(Array(prompts.enumerated()), id: \.offset) { idx, prompt in
                HStack {
                    Text(prompt).font(.caption)
                    Spacer()
                    Button { prompts.remove(at: idx) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(store.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            TextField("e.g. Did you check the pockets?", text: $newPrompt)
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let trimmed = newPrompt.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    prompts.append(trimmed)
                    newPrompt = ""
                }
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        DisclosureGroup("More options", isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if !isRecurring {
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("", selection: $dueDate)
                            .labelsHidden()
                    }
                }

                TextField("Tags (comma separated)", text: $tags)
                    .textFieldStyle(.roundedBorder)

                TextField("Notes", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            .padding(.top, 4)
        }
        .tint(store.theme.dim)
    }

    // MARK: - Create

    private var createButton: some View {
        Button {
            createTask()
        } label: {
            Text("Create")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Created list

    private var createdList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Created (\(createdTasks.count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(store.theme.dim)

            ForEach(createdTasks.reversed()) { task in
                HStack {
                    Text(task.title)
                        .font(.system(size: 14))
                        .foregroundStyle(store.theme.text)
                    Spacer()
                    if task.recurring, let cadence = task.cadenceSeconds {
                        Text("every \(formatCadence(cadence))")
                            .font(.caption)
                            .foregroundStyle(store.theme.accent)
                    }
                    if !task.domain.isEmpty {
                        Text(task.domain)
                            .font(.caption)
                            .foregroundStyle(store.theme.cyan)
                    }
                }
                .padding(10)
                .background(store.theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: store.theme.borderRadius))
            }
        }
    }

    // MARK: - Logic

    private func createTask() {
        let tagsList = tags.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let task = FMNTask(
            title: title.trimmingCharacters(in: .whitespaces),
            description: notes,
            domain: domain,
            tags: tagsList,
            priority: priority,
            dueDate: (!isRecurring && hasDueDate) ? dueDate : nil,
            startedAt: (!isRecurring && hasDueDate) ? Date() : nil,
            recurring: isRecurring,
            cadenceSeconds: isRecurring ? cadence : nil,
            followUps: followUps,
            prompts: prompts
        )

        store.createTask(task)
        createdTasks.append(task)

        // Reset form, keep sticky state (isRecurring, domain, cadence)
        title = ""
        followUps = []
        prompts = []
        notes = ""
        tags = ""
        titleFocused = true
    }
}
