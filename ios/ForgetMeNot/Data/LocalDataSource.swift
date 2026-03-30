import Foundation

final class LocalDataSource: DataSource {
    private let tasksURL: URL
    private let settingsURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        tasksURL = docs.appendingPathComponent("fmn-tasks.json")
        settingsURL = docs.appendingPathComponent("fmn-settings.json")
    }

    func loadTasks() -> [FMNTask] {
        guard let data = try? Data(contentsOf: tasksURL) else { return [] }
        return (try? decoder.decode([FMNTask].self, from: data)) ?? []
    }

    func saveTasks(_ tasks: [FMNTask]) {
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: tasksURL, options: .atomic)
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL) else { return AppSettings() }
        return (try? decoder.decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    func exportAll() -> Data? {
        let export = ExportPayload(
            tasks: loadTasks(),
            settings: loadSettings(),
            exportedAt: Date(),
            version: 1
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(export)
    }

    func importAll(_ data: Data) throws -> Int {
        let imported = try decoder.decode(ExportPayload.self, from: data)
        saveTasks(imported.tasks)
        if let s = imported.settings {
            saveSettings(s)
        }
        return imported.tasks.count
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: tasksURL)
        try? FileManager.default.removeItem(at: settingsURL)
    }
}

private struct ExportPayload: Codable {
    var tasks: [FMNTask]
    var settings: AppSettings?
    var exportedAt: Date
    var version: Int
}
