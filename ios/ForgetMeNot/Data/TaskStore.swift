import SwiftUI

@Observable
final class TaskStore {
    var tasks: [FMNTask] = []
    var settings: AppSettings = AppSettings()
    var tick: UInt64 = 0

    private var dataSource: any DataSource
    private var timer: Timer?

    var displayName: String {
        settings.appName.isEmpty ? "forget me not" : settings.appName
    }

    var theme: ThemeColors {
        let base = AppTheme.all.first { $0.name == settings.themePreset } ?? .midnight
        return base.resolve(
            customColors: settings.customColors,
            customRadius: settings.customBorderRadius,
            customFontSize: settings.customFontSize,
            customHeaderFont: settings.customHeaderFont,
            customBodyFont: settings.customBodyFont
        )
    }

    init(dataSource: any DataSource = LocalDataSource()) {
        self.dataSource = dataSource
        load()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Loading

    func load() {
        tasks = dataSource.loadTasks()
        settings = dataSource.loadSettings()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick &+= 1
            }
        }
    }

    // MARK: - Task CRUD

    func createTask(_ task: FMNTask) {
        tasks.append(task)
        dataSource.saveTasks(tasks)
    }

    func updateTask(id: String, _ update: (inout FMNTask) -> Void) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        update(&tasks[idx])
        tasks[idx].updatedAt = Date()
        dataSource.saveTasks(tasks)
    }

    func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        dataSource.saveTasks(tasks)
    }

    func resetTask(id: String, note: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].lastResetAt = Date()
        tasks[idx].actionLog.append(ActionLogEntry(note: note, action: .reset))
        tasks[idx].updatedAt = Date()

        // Randomize cadence within variance range on reset
        if let base = tasks[idx].cadenceSeconds,
           (tasks[idx].cadenceMore != nil || tasks[idx].cadenceLess != nil) {
            let less = tasks[idx].cadenceLess ?? 0
            let more = tasks[idx].cadenceMore ?? 0
            let min = base - less
            let max = base + more
            tasks[idx].cadenceSeconds = (min + Double.random(in: 0...(max - min))).rounded()
        }

        if !tasks[idx].followUps.isEmpty {
            spawnFollowUp(from: tasks[idx])
        }
        dataSource.saveTasks(tasks)
    }

    func completeTask(id: String, note: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].status = .done
        tasks[idx].completedAt = Date()
        tasks[idx].actionLog.append(ActionLogEntry(note: note, action: .complete))
        tasks[idx].updatedAt = Date()

        if !tasks[idx].followUps.isEmpty {
            spawnFollowUp(from: tasks[idx])
        }
        dataSource.saveTasks(tasks)
    }

    func snoozeTask(id: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }),
              let cadence = tasks[idx].cadenceSeconds else { return }
        tasks[idx].lastResetAt = Date(timeIntervalSinceNow: -cadence * 0.75)
        tasks[idx].updatedAt = Date()
        dataSource.saveTasks(tasks)
    }

    func archiveTask(id: String) {
        updateTask(id: id) { $0.status = .archived }
    }

    func addNote(id: String, note: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].actionLog.append(ActionLogEntry(note: note, action: .note))
        tasks[idx].updatedAt = Date()
        dataSource.saveTasks(tasks)
    }

    private func spawnFollowUp(from parent: FMNTask) {
        guard let first = parent.followUps.first else { return }
        let remaining = Array(parent.followUps.dropFirst())
        var task = FMNTask(
            title: first.title,
            domain: first.domain ?? parent.domain,
            dueDate: Date(timeIntervalSinceNow: first.cadenceSeconds),
            startedAt: Date(),
            followUps: remaining,
            parentTaskId: parent.id
        )
        task.tags = parent.tags
        tasks.append(task)
    }

    // MARK: - Settings

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        update(&settings)
        dataSource.saveSettings(settings)
    }

    // MARK: - Data management

    func exportJSON() -> Data? {
        dataSource.exportAll()
    }

    func importJSON(_ data: Data) throws {
        let count = try dataSource.importAll(data)
        load()
        _ = count
    }

    func clearAll() {
        dataSource.clearAll()
        tasks = []
        settings = AppSettings()
    }

    /// Swap the underlying data source (for connecting to a remote backend later)
    func setDataSource(_ newSource: any DataSource) {
        dataSource = newSource
        load()
    }
}
