import Foundation

/// Protocol for task and settings persistence.
/// Implement this to swap between local storage, remote API, or hybrid sync.
protocol DataSource {
    func loadTasks() -> [FMNTask]
    func saveTasks(_ tasks: [FMNTask])
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
    func exportAll() -> Data?
    func importAll(_ data: Data) throws -> Int
    func clearAll()
}
