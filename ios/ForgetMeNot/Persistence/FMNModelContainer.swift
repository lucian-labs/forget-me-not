import Foundation
import SwiftData

enum FMNModelContainer {
    /// App container backed by the CloudKit private DB. Use only when an iCloud
    /// account is present (real device); otherwise the mirroring delegate errors.
    @MainActor static func cloudKit() throws -> ModelContainer {
        let config = ModelConfiguration(
            "FMN",
            cloudKitDatabase: .private("iCloud.com.forgetmenot.app")
        )
        return try ModelContainer(for: TaskEntity.self, configurations: config)
    }

    /// Persistent local store with CloudKit explicitly disabled. Fallback for when
    /// no iCloud account is available (e.g. Simulator) so CloudKit never spins up.
    @MainActor static func local() throws -> ModelContainer {
        let config = ModelConfiguration("FMN-local", cloudKitDatabase: .none)
        return try ModelContainer(for: TaskEntity.self, configurations: config)
    }

    /// Test container: in-memory, CloudKit disabled. `cloudKitDatabase: .none` is
    /// required — the default `.automatic` enables mirroring whenever the app holds
    /// the CloudKit entitlement, which then fails on a simulator with no iCloud.
    @MainActor static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: TaskEntity.self, configurations: config)
    }
}
