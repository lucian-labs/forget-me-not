import SwiftUI

struct TaskCardView: View {
    let task: FMNTask
    @Environment(TaskStore.self) private var store
    @State private var captureMode: CaptureMode?
    @State private var captureText = ""
    @State private var autoSubmitWork: DispatchWorkItem?

    enum CaptureMode {
        case check, note
    }

    private var ratio: Double { task.urgencyRatio }

    private var urgencyColor: Color {
        if ratio < 0.75 { return store.theme.green }
        if ratio < 0.95 { return store.theme.orange }
        return store.theme.red
    }

    private var overduePrompt: String? {
        guard task.isOverdue, !task.prompts.isEmpty else { return nil }
        let period = Int(Date().timeIntervalSince1970 / 10)
        let index = abs((task.id.hashValue &+ period)) % task.prompts.count
        return task.prompts[index]
    }

    var body: some View {
        let _ = store.tick

        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 10) {
                Button { toggleCapture(.check) } label: {
                    Image(systemName: captureMode == .check ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(store.theme.accent)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(store.theme.body(size: store.theme.fontSize, weight: .medium))
                    .foregroundStyle(store.theme.text)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if task.priority == .high || task.priority == .critical {
                    Text(task.priority.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.priority == .critical ? store.theme.red.opacity(0.2) : store.theme.orange.opacity(0.2))
                        .foregroundStyle(task.priority == .critical ? store.theme.red : store.theme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button { toggleCapture(.note) } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(store.theme.dim)
                }
                .buttonStyle(.plain)

                if task.recurring {
                    Button {
                        withAnimation { store.snoozeTask(id: task.id) }
                    } label: {
                        Text("zz")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation { store.archiveTask(id: task.id) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Meta
            if let meta = metaText {
                Text(meta)
                    .font(.system(size: 11))
                    .foregroundStyle(store.theme.dim)
            }

            // Urgency bar
            UrgencyBar(ratio: ratio, color: urgencyColor)

            // Overdue prompt
            if let prompt = overduePrompt {
                Text("? \(prompt)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(store.theme.orange)
            }

            // Quick capture
            if let mode = captureMode {
                HStack(spacing: 8) {
                    TextField(
                        mode == .note ? "what did you do?" : "quick note (auto-submits)...",
                        text: $captureText
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { executeCapture() }
                    .onChange(of: captureText) {
                        if mode == .check { scheduleAutoSubmit() }
                    }

                    Button { dismissCapture() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(store.theme.dim)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    if mode == .check { scheduleAutoSubmit() }
                }
            }
        }
        .padding(12)
        .background(store.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: store.theme.borderRadius))
        .overlay(
            RoundedRectangle(cornerRadius: store.theme.borderRadius)
                .stroke(task.isOverdue ? store.theme.red.opacity(0.4) : store.theme.border, lineWidth: 1)
        )
        .onAppear { checkAlert() }
        .onChange(of: store.tick) { checkAlert() }
    }

    // MARK: - Meta text

    private var metaText: String? {
        var parts: [String] = []
        if task.recurring, let cadence = task.cadenceSeconds, let lastReset = task.lastResetAt {
            let elapsed = Date().timeIntervalSince(lastReset)
            let remaining = cadence - elapsed
            parts.append(remaining > 0 ? "\(formatTime(remaining)) left" : "\(formatTime(abs(remaining))) over")
            parts.append("every \(formatCadence(cadence))")
        } else if let due = task.dueDate {
            let remaining = due.timeIntervalSinceNow
            parts.append(remaining > 0 ? "\(formatTime(remaining)) left" : "\(formatTime(abs(remaining))) over")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Capture

    private func toggleCapture(_ mode: CaptureMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if captureMode == mode {
                dismissCapture()
            } else {
                autoSubmitWork?.cancel()
                captureMode = mode
                captureText = ""
            }
        }
    }

    private func dismissCapture() {
        autoSubmitWork?.cancel()
        captureMode = nil
        captureText = ""
    }

    private func scheduleAutoSubmit() {
        autoSubmitWork?.cancel()
        let work = DispatchWorkItem { [self] in
            DispatchQueue.main.async { executeCapture() }
        }
        autoSubmitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func executeCapture() {
        autoSubmitWork?.cancel()
        let note = captureText.trimmingCharacters(in: .whitespaces)

        withAnimation {
            if captureMode == .note {
                if !note.isEmpty { store.addNote(id: task.id, note: note) }
            } else {
                if task.recurring {
                    store.resetTask(id: task.id, note: note)
                } else {
                    store.completeTask(id: task.id, note: note)
                }
            }
            captureMode = nil
            captureText = ""
        }
    }

    // MARK: - Alerts

    private func checkAlert() {
        if task.isOverdue {
            SoundManager.shared.playAlert(for: task.id, settings: store.settings)
        } else {
            SoundManager.shared.clearAlert(for: task.id)
        }
    }
}
