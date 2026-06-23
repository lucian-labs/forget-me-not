import Foundation
import SwiftData

enum FMNModelContainer {
    /// App container backed by the CloudKit private DB. Use only when an iCloud
    /// account is present (real device); otherwise the mirroring delegate errors.
    @MainActor static func cloudKit() throws -> ModelContainer {
        let config = ModelConfiguration(
            "FMN",
            cloudKitDatabase: .private("iCloud.com.lucianlabs.forgetmenot")
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

    /// Process-wide shared container so the app and the App Intents (Siri/Shortcuts) read
    /// and write the SAME store. Multiple containers over one file lag each other.
    @MainActor private static var shared: ModelContainer?

    /// Local persistent store for now. CloudKit (`cloudKit()`) is wired and ready, but
    /// stays off until the iCloud container is provisioned for the App ID — at which
    /// point this becomes: prefer cloudKit() when an iCloud account is signed in.
    /// Flip to true ONCE the iCloud container `iCloud.com.lucianlabs.forgetmenot` is created
    /// + associated to the App ID and the CloudKit/Push entitlements are restored. Until then
    /// the cloudKit() container would crash at init (missing container entitlement), so we
    /// stay on the local store. Everything else (mirroring config, remote-change observer,
    /// push registration) is already wired and waiting on this flag.
    static let cloudKitReady = true

    /// True once resolve() actually picked the CloudKit store (enabled + iCloud signed in).
    @MainActor private(set) static var usingCloudKit = false

    @MainActor static func resolve() -> ModelContainer {
        if let shared { return shared }
        let c: ModelContainer
        // Prefer the CloudKit-mirrored store when enabled + an iCloud account is signed in;
        // fall back to a local store otherwise.
        if cloudKitReady, FileManager.default.ubiquityIdentityToken != nil, let ck = try? cloudKit() {
            c = ck
            usingCloudKit = true
        } else {
            c = (try? local()) ?? (try! inMemory())
        }
        shared = c
        return c
    }
}
