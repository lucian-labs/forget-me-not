import AppIntents
import Foundation

/// Siri / Shortcuts / Spotlight / Apple Intelligence integration. Plain App Intents in the
/// main target (no entitlement, no SiriKit string, no Assistant Schema — there's no habit
/// domain). Intents run in-process and mutate the SAME persistent store the app uses, so a
/// Siri reset shows up next time the app foregrounds (AppStore reloads on scene-active).

// MARK: - Shared data access

enum FMNIntentData {
    /// A repository over the process-wide shared container.
    @MainActor static var repo: TaskRepository { SwiftDataTaskRepository(container: FMNModelContainer.resolve()) }

    /// Active tasks, most urgent first (mirrors AppStore.sortedActive).
    @MainActor static func active() -> [TaskDTO] {
        ((try? repo.all()) ?? [])
            .filter { $0.status != .done && $0.status != .archived && $0.status != .cancelled }
            .sorted { Urgency.ratio($0) > Urgency.ratio($1) }
    }
}

enum FMNIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notFound
    var localizedStringResource: LocalizedStringResource {
        switch self { case .notFound: "I couldn't find that task." }
    }
}

// MARK: - Entity

/// A task exposed to Siri/Shortcuts. `id` is the stable task id (baked into saved shortcuts).
struct TaskItemEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static let defaultQuery = TaskItemQuery()

    let id: String
    let title: String
    let area: String

    var displayRepresentation: DisplayRepresentation {
        area.isEmpty
            ? DisplayRepresentation(title: "\(title)")
            : DisplayRepresentation(title: "\(title)", subtitle: "\(area)")
    }

    init(_ t: TaskDTO) { id = t.id; title = t.title; area = t.domain }
}

struct TaskItemQuery: EntityStringQuery {
    func entities(for ids: [String]) async throws -> [TaskItemEntity] {
        let set = Set(ids)
        let matches = await MainActor.run { ((try? FMNIntentData.repo.all()) ?? []).filter { set.contains($0.id) } }
        return matches.map(TaskItemEntity.init)
    }

    func entities(matching string: String) async throws -> [TaskItemEntity] {
        let active = await MainActor.run { FMNIntentData.active() }
        return active.filter { $0.title.localizedCaseInsensitiveContains(string) }.map(TaskItemEntity.init)
    }

    func suggestedEntities() async throws -> [TaskItemEntity] {
        await MainActor.run { FMNIntentData.active() }.map(TaskItemEntity.init)
    }
}

// MARK: - Intents

/// "I did it" — reset a recurring task's cycle.
struct ResetLoopIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset a Task"
    static let description = IntentDescription("Mark a recurring task as just done, restarting its timer.")

    @Parameter(title: "Task", requestValueDialog: "Which task did you do?")
    var task: TaskItemEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repo = FMNIntentData.repo
        guard let dto = repo.get(task.id) else { throw FMNIntentError.notFound }
        var rng = SystemRandomNumberGenerator()
        let result = Lifecycle.reset(dto, note: "via Siri", now: Date(), rng: &rng)
        try repo.upsert(result.task)
        if let spawned = result.spawned { try repo.upsert(spawned) }
        return .result(dialog: "Nice — reset \(dto.title).")
    }
}

/// Mark a task complete (done).
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete a Task"
    static let description = IntentDescription("Mark a task as done.")

    @Parameter(title: "Task", requestValueDialog: "Which task is done?")
    var task: TaskItemEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repo = FMNIntentData.repo
        guard let dto = repo.get(task.id) else { throw FMNIntentError.notFound }
        let r = Lifecycle.complete(dto, note: "via Siri", now: Date())
        try repo.upsert(r.task)
        if let spawned = r.spawned { try repo.upsert(spawned) }
        return .result(dialog: "Marked \(dto.title) complete.")
    }
}

/// Append a note to a task's history.
struct LogNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Note"
    static let description = IntentDescription("Add a note to a task's history.")

    @Parameter(title: "Task", requestValueDialog: "Which task?")
    var task: TaskItemEntity
    @Parameter(title: "Note", requestValueDialog: "What do you want to note?")
    var note: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repo = FMNIntentData.repo
        guard let dto = repo.get(task.id) else { throw FMNIntentError.notFound }
        try repo.upsert(Lifecycle.note(dto, note: note, now: Date()))
        return .result(dialog: "Logged on \(dto.title).")
    }
}

/// Create a new recurring task (defaults to a daily cadence; tweak it in the app).
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Task"
    static let description = IntentDescription("Add a new thing to remember.")

    @Parameter(title: "Title", requestValueDialog: "What should I remember?")
    var title: String
    @Parameter(title: "Area")
    var area: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let day: Double = 86400
        let dto = TaskDTO(
            id: UUID().uuidString, title: title, description: "", domain: area ?? "", tags: [],
            status: .open, priority: .normal, createdAt: now, updatedAt: now, dueDate: nil,
            startedAt: now, completedAt: nil, estimatedHours: nil, recurring: true,
            baseCadenceSeconds: day, cadenceMore: nil, cadenceLess: nil,
            instance: ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: day, snoozed: false),
            followUps: [], parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
        try FMNIntentData.repo.upsert(dto)
        return .result(dialog: "Added \(title).")
    }
}

/// "What am I forgetting" — the due/overdue tasks.
struct OverdueIntent: AppIntent {
    static let title: LocalizedStringResource = "What Am I Forgetting"
    static let description = IntentDescription("List the tasks that are due or overdue.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[TaskItemEntity]> & ProvidesDialog {
        let due = FMNIntentData.active().filter { Urgency.ratio($0) >= 0.9 }
        let entities = due.map(TaskItemEntity.init)
        guard !due.isEmpty else {
            return .result(value: entities, dialog: "You're all caught up — nothing's overdue.")
        }
        let names = due.prefix(5).map(\.title).joined(separator: ", ")
        let tail = due.count > 5 ? ", and more" : ""
        return .result(value: entities, dialog: "\(due.count) need attention: \(names)\(tail).")
    }
}

// MARK: - Shortcuts (auto-discovered; each phrase must contain the app name)

struct FMNShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ResetLoopIntent(), phrases: [
            "I did a task in \(.applicationName)",
            "Reset a task in \(.applicationName)",
            "Reset my \(.applicationName) task",
        ], shortTitle: "Reset Task", systemImageName: "arrow.counterclockwise")

        AppShortcut(intent: OverdueIntent(), phrases: [
            "What am I forgetting in \(.applicationName)",
            "What's overdue in \(.applicationName)",
            "What's due in \(.applicationName)",
        ], shortTitle: "What's Overdue", systemImageName: "exclamationmark.triangle")

        AppShortcut(intent: CompleteTaskIntent(), phrases: [
            "Complete a task in \(.applicationName)",
            "Finish a task in \(.applicationName)",
        ], shortTitle: "Complete Task", systemImageName: "checkmark")

        AppShortcut(intent: AddTaskIntent(), phrases: [
            "Add a task in \(.applicationName)",
            "Remember something with \(.applicationName)",
        ], shortTitle: "Add Task", systemImageName: "plus")

        AppShortcut(intent: LogNoteIntent(), phrases: [
            "Log a note in \(.applicationName)",
        ], shortTitle: "Log Note", systemImageName: "square.and.pencil")
    }
}
