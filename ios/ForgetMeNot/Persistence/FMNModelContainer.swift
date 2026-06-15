import Foundation
import SwiftData

enum FMNModelContainer {
    /// App container backed by CloudKit private DB.
    @MainActor static func cloudKit() throws -> ModelContainer {
        let config = ModelConfiguration(
            "FMN",
            cloudKitDatabase: .private("iCloud.com.forgetmenot.app")
        )
        return try ModelContainer(for: TaskEntity.self, configurations: config)
    }

    /// Test container, no persistence, no CloudKit.
    @MainActor static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: TaskEntity.self, configurations: config)
    }
}
