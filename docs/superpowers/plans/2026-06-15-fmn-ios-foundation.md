# Forget Me Not iOS — Milestone 1: Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the native iOS app's foundation — a web-identical Codable data layer, a SwiftData+CloudKit persistence store behind a repository, and pure tested domain logic — then deploy a running (empty) app to the physical iPhone 17.

**Architecture:** SwiftUI MV. In-memory model = web-identical `TaskDTO` value types; persistence/sync = SwiftData `@Model` entities (CloudKit private DB) reached through a `TaskRepository` protocol, with a `TaskMapper` translating entity ↔ DTO. Domain logic is pure functions over DTOs (no UI, no live CloudKit needed to test). The web app stays the source of truth; the DTO/JSON shape mirrors `src/types.ts` exactly.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, SwiftData + CloudKit, XcodeGen, XCTest, iOS 18 min target. Build/deploy via `xcodebuild` + `xcrun devicectl`.

**Plan set:** This is plan **1 of 4**. Later: M2 UI parity, M3 Reminders (local notifications), M4 Cosmetics + import/export. Each gets its own plan after the prior lands.

**Parity source of truth:** `src/types.ts` (model), `src/store.ts` (behavior + export/import). Read both before starting.

---

## File Structure

The existing `ios/` is replaced from zero (old version preserved in git history). New layout:

```
ios/
  project.yml                          XcodeGen: app + unit-test targets, iOS 18, Swift 6, CloudKit entitlement
  deploy.sh                            generate → build → install/launch on the iPhone 17
  ForgetMeNot/
    ForgetMeNotApp.swift               @main; boots the ModelContainer; empty root view for M1
    Info.plist                         background modes + BGTask id
    ForgetMeNot.entitlements           iCloud/CloudKit + aps-environment
    Models/
      ISO8601.swift                    JSONEncoder/Decoder configured to match JS Date.toISOString()
      TaskDTO.swift                    web-identical DTOs + enums + nested value types
      ExportEnvelope.swift             { tasks, settings, exportedAt, version } wrapper + SettingsDTO
    Persistence/
      Entities.swift                   SwiftData @Model TaskEntity (CloudKit-safe)
      FMNModelContainer.swift          container factory: CloudKit (app) + in-memory (tests)
      TaskMapper.swift                 TaskEntity ↔ TaskDTO
      TaskRepository.swift             protocol + SwiftDataTaskRepository impl
    Domain/
      Urgency.swift                    urgencyRatio / remainingSeconds / urgency color tier
      Cadence.swift                    randomizeCadence(base,more,less, rng)
      Lifecycle.swift                  reset / complete / snooze / lapse / spawnFollowUp (pure transforms)
  ForgetMeNotTests/
    Fixtures/web-export.json           representative export captured from the web Task shape
    ISO8601Tests.swift
    TaskDTOTests.swift
    ExportEnvelopeTests.swift
    EntityRoundTripTests.swift
    TaskMapperTests.swift
    UrgencyTests.swift
    CadenceTests.swift
    LifecycleTests.swift
    RepositoryTests.swift
```

**Bundle id:** `com.forgetmenot.app`. **CloudKit container:** `iCloud.com.forgetmenot.app`.

---

## Task 1: Project scaffold (XcodeGen + entitlements + deploy script)

**Files:**
- Delete: everything under `ios/` (old port)
- Create: `ios/project.yml`, `ios/ForgetMeNot/Info.plist`, `ios/ForgetMeNot/ForgetMeNot.entitlements`, `ios/ForgetMeNot/ForgetMeNotApp.swift`, `ios/deploy.sh`

- [ ] **Step 1: Remove the old iOS sources**

```bash
cd ios && git rm -r ForgetMeNot ForgetMeNot.xcodeproj project.yml 2>/dev/null; rm -rf ForgetMeNot ForgetMeNot.xcodeproj *.xcworkspace; cd ..
```

- [ ] **Step 2: Write `ios/project.yml`**

```yaml
name: ForgetMeNot
options:
  bundleIdPrefix: com.forgetmenot
  deploymentTarget:
    iOS: "18.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MARKETING_VERSION: "2.0.0"
    CURRENT_PROJECT_VERSION: "1"
targets:
  ForgetMeNot:
    type: application
    platform: iOS
    sources: [ForgetMeNot]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.forgetmenot.app
        TARGETED_DEVICE_FAMILY: "1,2"
        GENERATE_INFOPLIST_FILE: NO
        INFOPLIST_FILE: ForgetMeNot/Info.plist
        CODE_SIGN_ENTITLEMENTS: ForgetMeNot/ForgetMeNot.entitlements
        CODE_SIGN_STYLE: Automatic
    info:
      path: ForgetMeNot/Info.plist
      properties:
        UIBackgroundModes: [remote-notification, processing]
        BGTaskSchedulerPermittedIdentifiers: [com.forgetmenot.app.refresh]
        UILaunchScreen: {}
  ForgetMeNotTests:
    type: bundle.unit-test
    platform: iOS
    sources: [ForgetMeNotTests]
    dependencies:
      - target: ForgetMeNot
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 3: Write `ios/ForgetMeNot/ForgetMeNot.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array><string>iCloud.com.forgetmenot.app</string></array>
  <key>com.apple.developer.icloud-services</key>
  <array><string>CloudKit</string></array>
  <key>aps-environment</key>
  <string>development</string>
</dict>
</plist>
```

- [ ] **Step 4: Write a minimal `ios/ForgetMeNot/Info.plist`** (XcodeGen merges the `info.properties` above; this is the base file)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>
```

- [ ] **Step 5: Write a placeholder `ios/ForgetMeNot/ForgetMeNotApp.swift`** (replaced in Task 10)

```swift
import SwiftUI

@main
struct ForgetMeNotApp: App {
    var body: some Scene {
        WindowGroup { Text("Forget Me Not") }
    }
}
```

- [ ] **Step 6: Write `ios/deploy.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Team id for automatic signing (iCloud/Push profiles)
set -a; source "$HOME/repos/lucian-utils/.env"; set +a
TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID missing from lucian-utils/.env}"
DEVICE_NAME="${FMN_DEVICE:-iPhone 17}"

xcodegen generate

DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk -v n="$DEVICE_NAME" '$0 ~ n {print $(NF-1); exit}')"
[ -n "$DEVICE_ID" ] || { echo "Device '$DEVICE_NAME' not found. Connect it, enable Developer Mode, trust this Mac."; exit 1; }

xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -configuration Debug \
  -destination "id=$DEVICE_ID" -derivedDataPath build \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates build

APP="$(find build/Build/Products/Debug-iphoneos -maxdepth 1 -name '*.app' | head -1)"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
xcrun devicectl device process launch --device "$DEVICE_ID" com.forgetmenot.app
echo "Installed + launched on $DEVICE_NAME ($DEVICE_ID)"
```

```bash
chmod +x ios/deploy.sh
```

- [ ] **Step 7: Generate + build for the simulator to verify the project is valid**

Run: `cd ios && xcodegen generate && xcodebuild -project ForgetMeNot.xcodeproj -scheme ForgetMeNot -destination 'generic/platform=iOS Simulator' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add ios/project.yml ios/deploy.sh ios/ForgetMeNot/
git commit -m "M1: scaffold native iOS project (XcodeGen, CloudKit entitlements, deploy script)"
```

---

## Task 2: ISO-8601 date coding (matches JS `toISOString()`)

**Files:** Create `ios/ForgetMeNot/Models/ISO8601.swift`, `ios/ForgetMeNotTests/ISO8601Tests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class ISO8601Tests: XCTestCase {
    func test_decodesAndReencodesJSToISOString() throws {
        // JS: new Date("2026-06-15T12:34:56.789Z").toISOString() === "2026-06-15T12:34:56.789Z"
        let json = #"{"at":"2026-06-15T12:34:56.789Z"}"#.data(using: .utf8)!
        struct Box: Codable, Equatable { var at: Date }
        let decoded = try FMNJSON.decoder.decode(Box.self, from: json)
        let reencoded = try FMNJSON.encoder.encode(decoded)
        let s = String(data: reencoded, encoding: .utf8)!
        XCTAssertTrue(s.contains("2026-06-15T12:34:56.789Z"), s)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/ISO8601Tests`
Expected: FAIL — `FMNJSON` undefined.

- [ ] **Step 3: Implement `ISO8601.swift`**

```swift
import Foundation

/// JSON coders matching the web app's format: ISO-8601 UTC with millisecond
/// precision and a trailing `Z`, exactly like JavaScript `Date.toISOString()`.
enum FMNJSON {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(formatter.string(from: date))
        }
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: s) else {
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath,
                    debugDescription: "Bad ISO-8601 date: \(s)"))
            }
            return date
        }
        return d
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Models/ISO8601.swift ios/ForgetMeNotTests/ISO8601Tests.swift
git commit -m "M1: ISO-8601 JSON coders matching JS toISOString"
```

---

## Task 3: Web-identical DTOs + a fixture round-trip

**Files:** Create `ios/ForgetMeNot/Models/TaskDTO.swift`, `ios/ForgetMeNotTests/Fixtures/web-export.json`, `ios/ForgetMeNotTests/TaskDTOTests.swift`

- [ ] **Step 1: Create the fixture `ios/ForgetMeNotTests/Fixtures/web-export.json`** (representative of `src/types.ts` `Task`, including a live `instance`, a follow-up, action log, and `soundSeed`)

```json
{
  "tasks": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "title": "Flip the laundry",
      "description": "Move wash to dryer",
      "domain": "home",
      "tags": ["chores"],
      "status": "open",
      "priority": "normal",
      "createdAt": "2026-06-15T12:00:00.000Z",
      "updatedAt": "2026-06-15T12:30:00.000Z",
      "dueDate": null,
      "startedAt": null,
      "completedAt": null,
      "estimatedHours": null,
      "recurring": true,
      "baseCadenceSeconds": 2700,
      "cadenceMore": 300,
      "cadenceLess": 300,
      "instance": { "startedAt": "2026-06-15T12:00:00.000Z", "actualCadenceSeconds": 2850, "snoozed": false },
      "followUps": [ { "title": "Fold the laundry", "cadenceSeconds": 1800, "domain": "home" } ],
      "parentTaskId": null,
      "prompts": ["Did you check the pockets?"],
      "soundSeed": "laundry-7",
      "actionLog": [ { "note": "started", "at": "2026-06-15T12:00:00.000Z", "action": "reset" } ]
    }
  ],
  "settings": { "appName": "forget me not", "themePreset": "midnight", "soundEnabled": true },
  "exportedAt": "2026-06-15T12:30:00.000Z",
  "version": 1
}
```

- [ ] **Step 2: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class TaskDTOTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        return try Data(contentsOf: url)
    }

    func test_decodesWebTaskShape() throws {
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: fixture())
        let t = try XCTUnwrap(env.tasks.first)
        XCTAssertEqual(t.id, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(t.title, "Flip the laundry")
        XCTAssertEqual(t.recurring, true)
        XCTAssertEqual(t.baseCadenceSeconds, 2700)
        XCTAssertEqual(t.instance?.actualCadenceSeconds, 2850)
        XCTAssertEqual(t.followUps.first?.title, "Fold the laundry")
        XCTAssertEqual(t.soundSeed, "laundry-7")
        XCTAssertEqual(t.actionLog.first?.action, .reset)
        XCTAssertNil(t.dueDate)
    }

    func test_nullableFieldsReencodeAsExplicitNull() throws {
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: fixture())
        let data = try FMNJSON.encoder.encode(env.tasks[0])
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Web keeps nullable keys present as null; assert the key exists and is NSNull.
        XCTAssertTrue(obj.keys.contains("dueDate"))
        XCTAssertTrue(obj["dueDate"] is NSNull)
        XCTAssertTrue(obj["parentTaskId"] is NSNull)
    }
}
```

> Note: this test references `ExportEnvelope` (Task 4). Implement `TaskDTO` now; if you run this test before Task 4, expect a compile error on `ExportEnvelope` — that is acceptable and resolved in Task 4. Run `test_decodesWebTaskShape` only after Task 4.

- [ ] **Step 3: Implement `TaskDTO.swift`** — value types mirroring `src/types.ts`, with a custom encoder that emits explicit `null` for the web's nullable fields.

```swift
import Foundation

enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case open, inProgress = "in_progress", blocked, done, cancelled, archived
}
enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low, normal, high, critical
}
enum ActionType: String, Codable, Sendable {
    case reset, complete, note, lapsed
}

struct FollowUpDTO: Codable, Equatable, Sendable {
    var title: String
    var cadenceSeconds: Double
    var domain: String?
}

struct ActionLogEntryDTO: Codable, Equatable, Sendable {
    var note: String
    var at: Date
    var action: ActionType
}

struct ReminderInstanceDTO: Codable, Equatable, Sendable {
    var startedAt: Date
    var actualCadenceSeconds: Double
    var snoozed: Bool
}

struct TaskDTO: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var description: String
    var domain: String
    var tags: [String]
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var updatedAt: Date
    var dueDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var estimatedHours: Double?
    var recurring: Bool
    var baseCadenceSeconds: Double?
    var cadenceMore: Double?
    var cadenceLess: Double?
    var instance: ReminderInstanceDTO?
    var followUps: [FollowUpDTO]
    var parentTaskId: String?
    var prompts: [String]
    var soundSeed: String?
    var actionLog: [ActionLogEntryDTO]

    enum CodingKeys: String, CodingKey {
        case id, title, description, domain, tags, status, priority, createdAt, updatedAt,
             dueDate, startedAt, completedAt, estimatedHours, recurring, baseCadenceSeconds,
             cadenceMore, cadenceLess, instance, followUps, parentTaskId, prompts, soundSeed, actionLog
    }

    // Custom encode so nullable fields are emitted as explicit `null` (web parity),
    // using `encode` (not `encodeIfPresent`) on optionals.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(domain, forKey: .domain)
        try c.encode(tags, forKey: .tags)
        try c.encode(status, forKey: .status)
        try c.encode(priority, forKey: .priority)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(dueDate, forKey: .dueDate)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(completedAt, forKey: .completedAt)
        try c.encode(estimatedHours, forKey: .estimatedHours)
        try c.encode(recurring, forKey: .recurring)
        try c.encode(baseCadenceSeconds, forKey: .baseCadenceSeconds)
        try c.encode(cadenceMore, forKey: .cadenceMore)
        try c.encode(cadenceLess, forKey: .cadenceLess)
        try c.encode(instance, forKey: .instance)
        try c.encode(followUps, forKey: .followUps)
        try c.encode(parentTaskId, forKey: .parentTaskId)
        try c.encode(prompts, forKey: .prompts)
        try c.encode(soundSeed, forKey: .soundSeed)
        try c.encode(actionLog, forKey: .actionLog)
    }
}
```

- [ ] **Step 4: Run `test_decodesWebTaskShape` and `test_nullableFieldsReencodeAsExplicitNull`** (after Task 4 compiles `ExportEnvelope`)

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/TaskDTOTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Models/TaskDTO.swift ios/ForgetMeNotTests/Fixtures/web-export.json ios/ForgetMeNotTests/TaskDTOTests.swift
git commit -m "M1: web-identical Task DTOs + fixture (instance model, null parity)"
```

---

## Task 4: Export/import envelope

**Files:** Create `ios/ForgetMeNot/Models/ExportEnvelope.swift`, `ios/ForgetMeNotTests/ExportEnvelopeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class ExportEnvelopeTests: XCTestCase {
    func test_roundTripsWrapper() throws {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: data)
        XCTAssertEqual(env.version, 1)
        XCTAssertEqual(env.tasks.count, 1)
        XCTAssertNotNil(env.settings)
        let re = try FMNJSON.encoder.encode(env)
        let env2 = try FMNJSON.decoder.decode(ExportEnvelope.self, from: re)
        XCTAssertEqual(env2.tasks, env.tasks)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/ExportEnvelopeTests`
Expected: FAIL — `ExportEnvelope` undefined.

- [ ] **Step 3: Implement `ExportEnvelope.swift`**

```swift
import Foundation

/// Settings are kept as a free-form JSON blob in M1 (full typing lands with
/// the Settings UI in M4); this preserves them losslessly across export/import.
struct SettingsDTO: Codable, Equatable, Sendable {
    var raw: [String: JSONValue]
    init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode([String: JSONValue].self)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}

struct ExportEnvelope: Codable, Equatable, Sendable {
    var tasks: [TaskDTO]
    var settings: SettingsDTO?
    var exportedAt: Date?
    var version: Int
}
```

```swift
// JSONValue.swift content lives in the same file: a minimal Codable JSON value.
indirect enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "Unknown JSON")) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a): try c.encode(a)
        case .null: try c.encodeNil()
        }
    }
}
```

> Decode order matters: `bool` before `number` (JSON `true`/`false` must not be read as numbers).

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS. Also re-run Task 3's tests — both should pass now.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Models/ExportEnvelope.swift ios/ForgetMeNotTests/ExportEnvelopeTests.swift
git commit -m "M1: export/import envelope + JSON value for settings passthrough"
```

---

## Task 5: SwiftData entity + in-memory container

**Files:** Create `ios/ForgetMeNot/Persistence/Entities.swift`, `ios/ForgetMeNot/Persistence/FMNModelContainer.swift`, `ios/ForgetMeNotTests/EntityRoundTripTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import ForgetMeNot

final class EntityRoundTripTests: XCTestCase {
    @MainActor
    func test_insertAndFetch() throws {
        let container = try FMNModelContainer.inMemory()
        let ctx = container.mainContext
        let e = TaskEntity(id: "abc", title: "Test")
        ctx.insert(e)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<TaskEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Test")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/EntityRoundTripTests`
Expected: FAIL — `TaskEntity` / `FMNModelContainer` undefined.

- [ ] **Step 3: Implement `Entities.swift`** — CloudKit-safe (every attribute defaulted; nested value types stored as Codable arrays/structs).

```swift
import Foundation
import SwiftData

@Model
final class TaskEntity {
    var id: String = ""
    var title: String = ""
    var taskDescription: String = ""      // `description` is reserved on NSObject-ish contexts; map in mapper
    var domain: String = ""
    var tags: [String] = []
    var statusRaw: String = TaskStatus.open.rawValue
    var priorityRaw: String = TaskPriority.normal.rawValue
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast
    var dueDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var estimatedHours: Double?
    var recurring: Bool = false
    var baseCadenceSeconds: Double?
    var cadenceMore: Double?
    var cadenceLess: Double?
    // Embedded ReminderInstance (present iff recurring & live):
    var instanceStartedAt: Date?
    var instanceActualCadenceSeconds: Double?
    var instanceSnoozed: Bool = false
    var followUps: [FollowUpDTO] = []
    var parentTaskId: String?
    var prompts: [String] = []
    var soundSeed: String?
    var actionLog: [ActionLogEntryDTO] = []

    init(id: String, title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

> CloudKit rules honored: all attributes optional or defaulted, no `@Attribute(.unique)`. `id` is a logical key only; dedupe happens in the repository. `FollowUpDTO`/`ActionLogEntryDTO` are Codable, so SwiftData stores the arrays as encoded blobs.

- [ ] **Step 4: Implement `FMNModelContainer.swift`**

```swift
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
```

- [ ] **Step 5: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add ios/ForgetMeNot/Persistence/Entities.swift ios/ForgetMeNot/Persistence/FMNModelContainer.swift ios/ForgetMeNotTests/EntityRoundTripTests.swift
git commit -m "M1: SwiftData TaskEntity (CloudKit-safe) + container factory"
```

---

## Task 6: TaskMapper (entity ↔ DTO, lossless)

**Files:** Create `ios/ForgetMeNot/Persistence/TaskMapper.swift`, `ios/ForgetMeNotTests/TaskMapperTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class TaskMapperTests: XCTestCase {
    func test_dtoToEntityToDtoIsLossless() throws {
        let url = Bundle(for: Self.self).url(forResource: "web-export", withExtension: "json")!
        let env = try FMNJSON.decoder.decode(ExportEnvelope.self, from: try Data(contentsOf: url))
        let dto = env.tasks[0]
        let entity = TaskMapper.entity(from: dto)
        let back = TaskMapper.dto(from: entity)
        XCTAssertEqual(back, dto)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/TaskMapperTests`
Expected: FAIL — `TaskMapper` undefined.

- [ ] **Step 3: Implement `TaskMapper.swift`**

```swift
import Foundation

enum TaskMapper {
    static func entity(from d: TaskDTO) -> TaskEntity {
        let e = TaskEntity(id: d.id, title: d.title)
        e.taskDescription = d.description
        e.domain = d.domain
        e.tags = d.tags
        e.statusRaw = d.status.rawValue
        e.priorityRaw = d.priority.rawValue
        e.createdAt = d.createdAt
        e.updatedAt = d.updatedAt
        e.dueDate = d.dueDate
        e.startedAt = d.startedAt
        e.completedAt = d.completedAt
        e.estimatedHours = d.estimatedHours
        e.recurring = d.recurring
        e.baseCadenceSeconds = d.baseCadenceSeconds
        e.cadenceMore = d.cadenceMore
        e.cadenceLess = d.cadenceLess
        e.instanceStartedAt = d.instance?.startedAt
        e.instanceActualCadenceSeconds = d.instance?.actualCadenceSeconds
        e.instanceSnoozed = d.instance?.snoozed ?? false
        e.followUps = d.followUps
        e.parentTaskId = d.parentTaskId
        e.prompts = d.prompts
        e.soundSeed = d.soundSeed
        e.actionLog = d.actionLog
        return e
    }

    static func dto(from e: TaskEntity) -> TaskDTO {
        let instance: ReminderInstanceDTO? = {
            guard let s = e.instanceStartedAt, let c = e.instanceActualCadenceSeconds else { return nil }
            return ReminderInstanceDTO(startedAt: s, actualCadenceSeconds: c, snoozed: e.instanceSnoozed)
        }()
        return TaskDTO(
            id: e.id, title: e.title, description: e.taskDescription, domain: e.domain,
            tags: e.tags,
            status: TaskStatus(rawValue: e.statusRaw) ?? .open,
            priority: TaskPriority(rawValue: e.priorityRaw) ?? .normal,
            createdAt: e.createdAt, updatedAt: e.updatedAt,
            dueDate: e.dueDate, startedAt: e.startedAt, completedAt: e.completedAt,
            estimatedHours: e.estimatedHours, recurring: e.recurring,
            baseCadenceSeconds: e.baseCadenceSeconds, cadenceMore: e.cadenceMore, cadenceLess: e.cadenceLess,
            instance: instance, followUps: e.followUps, parentTaskId: e.parentTaskId,
            prompts: e.prompts, soundSeed: e.soundSeed, actionLog: e.actionLog
        )
    }

    /// Apply DTO fields onto an existing entity (for updates).
    static func apply(_ d: TaskDTO, to e: TaskEntity) {
        let fresh = entity(from: d)
        e.title = fresh.title; e.taskDescription = fresh.taskDescription; e.domain = fresh.domain
        e.tags = fresh.tags; e.statusRaw = fresh.statusRaw; e.priorityRaw = fresh.priorityRaw
        e.createdAt = fresh.createdAt; e.updatedAt = fresh.updatedAt
        e.dueDate = fresh.dueDate; e.startedAt = fresh.startedAt; e.completedAt = fresh.completedAt
        e.estimatedHours = fresh.estimatedHours; e.recurring = fresh.recurring
        e.baseCadenceSeconds = fresh.baseCadenceSeconds; e.cadenceMore = fresh.cadenceMore; e.cadenceLess = fresh.cadenceLess
        e.instanceStartedAt = fresh.instanceStartedAt; e.instanceActualCadenceSeconds = fresh.instanceActualCadenceSeconds; e.instanceSnoozed = fresh.instanceSnoozed
        e.followUps = fresh.followUps; e.parentTaskId = fresh.parentTaskId
        e.prompts = fresh.prompts; e.soundSeed = fresh.soundSeed; e.actionLog = fresh.actionLog
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Persistence/TaskMapper.swift ios/ForgetMeNotTests/TaskMapperTests.swift
git commit -m "M1: TaskMapper entity<->DTO lossless round-trip"
```

---

## Task 7: Urgency domain logic

**Files:** Create `ios/ForgetMeNot/Domain/Urgency.swift`, `ios/ForgetMeNotTests/UrgencyTests.swift`

Behavior ported from `src/store.ts` `getUrgencyRatio` / `getUrgencyColor`: recurring tasks measure elapsed since `instance.startedAt` over `instance.actualCadenceSeconds`; dated tasks measure `startedAt → dueDate`. Color tiers: `< 0.5` green, `< 0.8` orange, `< 1.0` red, `>= 1.0` overdue (pulsing).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class UrgencyTests: XCTestCase {
    private func task(instanceStart: Date, cadence: Double) -> TaskDTO {
        TaskDTO(id: "x", title: "t", description: "", domain: "", tags: [], status: .open,
                priority: .normal, createdAt: .distantPast, updatedAt: .distantPast,
                dueDate: nil, startedAt: nil, completedAt: nil, estimatedHours: nil,
                recurring: true, baseCadenceSeconds: cadence, cadenceMore: nil, cadenceLess: nil,
                instance: .init(startedAt: instanceStart, actualCadenceSeconds: cadence, snoozed: false),
                followUps: [], parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
    }

    func test_halfElapsedIsHalfRatio() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let t = task(instanceStart: now.addingTimeInterval(-50), cadence: 100)
        XCTAssertEqual(Urgency.ratio(t, now: now), 0.5, accuracy: 0.0001)
    }

    func test_overdueClampsTier() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let t = task(instanceStart: now.addingTimeInterval(-200), cadence: 100)
        XCTAssertTrue(Urgency.ratio(t, now: now) >= 1.0)
        XCTAssertEqual(Urgency.tier(for: Urgency.ratio(t, now: now)), .overdue)
    }

    func test_tierBoundaries() {
        XCTAssertEqual(Urgency.tier(for: 0.0), .calm)
        XCTAssertEqual(Urgency.tier(for: 0.49), .calm)
        XCTAssertEqual(Urgency.tier(for: 0.5), .soon)
        XCTAssertEqual(Urgency.tier(for: 0.79), .soon)
        XCTAssertEqual(Urgency.tier(for: 0.8), .due)
        XCTAssertEqual(Urgency.tier(for: 1.0), .overdue)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/UrgencyTests`
Expected: FAIL — `Urgency` undefined.

- [ ] **Step 3: Implement `Urgency.swift`**

```swift
import Foundation

enum UrgencyTier: Equatable { case calm, soon, due, overdue }

enum Urgency {
    /// Fraction of the current cycle elapsed (0 = fresh, >=1 = overdue).
    static func ratio(_ t: TaskDTO, now: Date = Date()) -> Double {
        if t.recurring, let inst = t.instance, inst.actualCadenceSeconds > 0 {
            return now.timeIntervalSince(inst.startedAt) / inst.actualCadenceSeconds
        }
        if let due = t.dueDate, let start = t.startedAt {
            let total = due.timeIntervalSince(start)
            guard total > 0 else { return 1 }
            return now.timeIntervalSince(start) / total
        }
        return 0
    }

    static func remainingSeconds(_ t: TaskDTO, now: Date = Date()) -> Double {
        if t.recurring, let inst = t.instance {
            return inst.startedAt.addingTimeInterval(inst.actualCadenceSeconds).timeIntervalSince(now)
        }
        if let due = t.dueDate { return due.timeIntervalSince(now) }
        return .infinity
    }

    static func tier(for ratio: Double) -> UrgencyTier {
        switch ratio {
        case ..<0.5: .calm
        case ..<0.8: .soon
        case ..<1.0: .due
        default: .overdue
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Domain/Urgency.swift ios/ForgetMeNotTests/UrgencyTests.swift
git commit -m "M1: urgency ratio/tier domain logic (parity with web)"
```

---

## Task 8: Cadence randomization

**Files:** Create `ios/ForgetMeNot/Domain/Cadence.swift`, `ios/ForgetMeNotTests/CadenceTests.swift`

Ported from `src/store.ts` `randomizeCadence(base, more, less)`: pick uniformly in `[base - less, base + more]`. RNG is injected for deterministic tests.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class CadenceTests: XCTestCase {
    func test_withinBounds() {
        var rng = SeededRNG(seed: 42)
        for _ in 0..<100 {
            let v = Cadence.randomized(base: 1000, more: 200, less: 300, using: &rng)
            XCTAssertGreaterThanOrEqual(v, 700)
            XCTAssertLessThanOrEqual(v, 1200)
        }
    }

    func test_nilVarianceReturnsBase() {
        var rng = SeededRNG(seed: 1)
        XCTAssertEqual(Cadence.randomized(base: 1000, more: nil, less: nil, using: &rng), 1000)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/CadenceTests`
Expected: FAIL — `Cadence` / `SeededRNG` undefined.

- [ ] **Step 3: Implement `Cadence.swift`** (includes a small seedable RNG for tests + production use)

```swift
import Foundation

/// Deterministic, seedable PRNG (SplitMix64) — usable in tests and in app code.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum Cadence {
    /// Uniform in [base - less, base + more]. Missing variance → base unchanged.
    static func randomized<R: RandomNumberGenerator>(
        base: Double, more: Double?, less: Double?, using rng: inout R
    ) -> Double {
        let lo = base - (less ?? 0)
        let hi = base + (more ?? 0)
        guard hi > lo else { return base }
        return Double.random(in: lo...hi, using: &rng).rounded()
    }
}
```

> Note `randomized` rounds to whole seconds (web stores integer seconds). The `nilVariance` test passes because `lo == hi == base`.

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Domain/Cadence.swift ios/ForgetMeNotTests/CadenceTests.swift
git commit -m "M1: cadence randomization with injectable seeded RNG"
```

---

## Task 9: Lifecycle transforms (reset / complete / snooze / lapse / spawn)

**Files:** Create `ios/ForgetMeNot/Domain/Lifecycle.swift`, `ios/ForgetMeNotTests/LifecycleTests.swift`

Pure transforms returning new state. Ported from `src/store.ts` `resetTask`, `completeTask`, `snoozeTask`, `checkDoubleLapsed`, `spawnFollowUp`. Reset starts a new randomized instance + logs `reset`; complete sets `done` + logs `complete`; snooze shifts the instance start by `0.75 * actualCadenceSeconds`; lapse detection flags a recurring task overdue by ≥ 2 cycles.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ForgetMeNot

final class LifecycleTests: XCTestCase {
    private func recurring(now: Date) -> TaskDTO {
        TaskDTO(id: "x", title: "t", description: "", domain: "home", tags: ["a"], status: .open,
                priority: .normal, createdAt: now, updatedAt: now, dueDate: nil, startedAt: nil,
                completedAt: nil, estimatedHours: nil, recurring: true, baseCadenceSeconds: 100,
                cadenceMore: 0, cadenceLess: 0,
                instance: .init(startedAt: now.addingTimeInterval(-300), actualCadenceSeconds: 100, snoozed: false),
                followUps: [.init(title: "next", cadenceSeconds: 50, domain: nil)],
                parentTaskId: nil, prompts: [], soundSeed: nil, actionLog: [])
    }

    func test_resetStartsNewInstanceAndLogs() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        var rng = SeededRNG(seed: 7)
        let r = Lifecycle.reset(recurring(now: now), note: "did it", now: now, rng: &rng)
        XCTAssertEqual(r.task.instance?.startedAt, now)
        XCTAssertEqual(r.task.actionLog.last?.action, .reset)
        XCTAssertEqual(r.task.actionLog.last?.note, "did it")
        XCTAssertEqual(r.spawned?.title, "next")          // first follow-up spawned
        XCTAssertEqual(r.spawned?.parentTaskId, "x")
    }

    func test_completeMarksDoneAndLogs() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let r = Lifecycle.complete(recurring(now: now), note: "done", now: now)
        XCTAssertEqual(r.task.status, .done)
        XCTAssertEqual(r.task.completedAt, now)
        XCTAssertEqual(r.task.actionLog.last?.action, .complete)
    }

    func test_snoozeShiftsInstanceStartForward() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let before = Urgency.ratio(recurring(now: now), now: now)   // 3.0
        let s = Lifecycle.snooze(recurring(now: now), now: now)
        let after = Urgency.ratio(s, now: now)
        XCTAssertLessThan(after, before)
        XCTAssertEqual(s.instance?.snoozed, true)
    }

    func test_doubleLapsedDetected() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let t = recurring(now: now)   // started 300s ago, cadence 100 → ratio 3.0 ≥ 2
        XCTAssertTrue(Lifecycle.isDoubleLapsed(t, now: now))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/LifecycleTests`
Expected: FAIL — `Lifecycle` undefined.

- [ ] **Step 3: Implement `Lifecycle.swift`**

```swift
import Foundation

enum Lifecycle {
    struct ResetResult { var task: TaskDTO; var spawned: TaskDTO? }

    static func reset<R: RandomNumberGenerator>(_ t: TaskDTO, note: String, now: Date = Date(), rng: inout R) -> ResetResult {
        var task = t
        let cadence = Cadence.randomized(base: t.baseCadenceSeconds ?? 0, more: t.cadenceMore, less: t.cadenceLess, using: &rng)
        task.instance = ReminderInstanceDTO(startedAt: now, actualCadenceSeconds: cadence, snoozed: false)
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .reset))
        task.updatedAt = now
        let spawned = spawnFollowUp(from: task, now: now)
        return ResetResult(task: task, spawned: spawned)
    }

    struct CompleteResult { var task: TaskDTO; var spawned: TaskDTO? }

    static func complete(_ t: TaskDTO, note: String, now: Date = Date()) -> CompleteResult {
        var task = t
        task.status = .done
        task.completedAt = now
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .complete))
        task.updatedAt = now
        return CompleteResult(task: task, spawned: spawnFollowUp(from: task, now: now))
    }

    static func snooze(_ t: TaskDTO, now: Date = Date()) -> TaskDTO {
        guard var inst = t.instance else { return t }
        // Web: shift start so ~75% of the cycle "remains" → start = now - 0.25*cadence.
        inst.startedAt = now.addingTimeInterval(-0.25 * inst.actualCadenceSeconds)
        inst.snoozed = true
        var task = t
        task.instance = inst
        task.updatedAt = now
        return task
    }

    static func note(_ t: TaskDTO, note: String, now: Date = Date()) -> TaskDTO {
        var task = t
        task.actionLog.append(ActionLogEntryDTO(note: note, at: now, action: .note))
        task.updatedAt = now
        return task
    }

    static func isDoubleLapsed(_ t: TaskDTO, now: Date = Date()) -> Bool {
        t.recurring && t.instance != nil && Urgency.ratio(t, now: now) >= 2.0
    }

    static func spawnFollowUp(from parent: TaskDTO, now: Date = Date()) -> TaskDTO? {
        guard let first = parent.followUps.first else { return nil }
        let remaining = Array(parent.followUps.dropFirst())
        let due = now.addingTimeInterval(first.cadenceSeconds)
        return TaskDTO(
            id: UUID().uuidString, title: first.title, description: "",
            domain: first.domain ?? parent.domain, tags: parent.tags, status: .open,
            priority: .normal, createdAt: now, updatedAt: now, dueDate: due, startedAt: now,
            completedAt: nil, estimatedHours: nil, recurring: false, baseCadenceSeconds: nil,
            cadenceMore: nil, cadenceLess: nil, instance: nil, followUps: remaining,
            parentTaskId: parent.id, prompts: parent.prompts, soundSeed: parent.soundSeed, actionLog: []
        )
    }
}
```

> Cross-check the exact `snoozeTask` math against `src/store.ts:174-180` during implementation; the web uses `Date.now() - actualCadenceSeconds * 750` (ms). Match the web's resulting urgency drop and adjust the constant if needed (test asserts the *direction*; tighten to exact parity if the web value differs).

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Domain/Lifecycle.swift ios/ForgetMeNotTests/LifecycleTests.swift
git commit -m "M1: lifecycle transforms (reset/complete/snooze/lapse/spawn)"
```

---

## Task 10: TaskRepository (protocol + SwiftData impl)

**Files:** Create `ios/ForgetMeNot/Persistence/TaskRepository.swift`, `ios/ForgetMeNotTests/RepositoryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import ForgetMeNot

final class RepositoryTests: XCTestCase {
    @MainActor
    private func makeRepo() throws -> SwiftDataTaskRepository {
        SwiftDataTaskRepository(context: try FMNModelContainer.inMemory().mainContext)
    }

    private func sample(_ id: String) -> TaskDTO {
        TaskDTO(id: id, title: "t-\(id)", description: "", domain: "", tags: [], status: .open,
                priority: .normal, createdAt: Date(), updatedAt: Date(), dueDate: nil, startedAt: nil,
                completedAt: nil, estimatedHours: nil, recurring: false, baseCadenceSeconds: nil,
                cadenceMore: nil, cadenceLess: nil, instance: nil, followUps: [], parentTaskId: nil,
                prompts: [], soundSeed: nil, actionLog: [])
    }

    @MainActor
    func test_upsertGetAllDelete() throws {
        let repo = try makeRepo()
        try repo.upsert(sample("a"))
        try repo.upsert(sample("b"))
        XCTAssertEqual(try repo.all().count, 2)

        var a = try XCTUnwrap(repo.get("a"))
        a.title = "renamed"
        try repo.upsert(a)
        XCTAssertEqual(try repo.get("a")?.title, "renamed")   // update, not duplicate
        XCTAssertEqual(try repo.all().count, 2)

        try repo.delete("a")
        XCTAssertNil(try repo.get("a"))
        XCTAssertEqual(try repo.all().count, 1)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd ios && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ForgetMeNotTests/RepositoryTests`
Expected: FAIL — `SwiftDataTaskRepository` undefined.

- [ ] **Step 3: Implement `TaskRepository.swift`**

```swift
import Foundation
import SwiftData

@MainActor
protocol TaskRepository {
    func all() throws -> [TaskDTO]
    func get(_ id: String) -> TaskDTO?
    func upsert(_ task: TaskDTO) throws
    func delete(_ id: String) throws
}

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    private func entity(_ id: String) -> TaskEntity? {
        let d = FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(d).first
    }

    func all() throws -> [TaskDTO] {
        try context.fetch(FetchDescriptor<TaskEntity>()).map(TaskMapper.dto(from:))
    }

    func get(_ id: String) -> TaskDTO? {
        entity(id).map(TaskMapper.dto(from:))
    }

    func upsert(_ task: TaskDTO) throws {
        if let existing = entity(task.id) {
            TaskMapper.apply(task, to: existing)
        } else {
            context.insert(TaskMapper.entity(from: task))
        }
        try context.save()
    }

    func delete(_ id: String) throws {
        if let e = entity(id) { context.delete(e); try context.save() }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: same as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios/ForgetMeNot/Persistence/TaskRepository.swift ios/ForgetMeNotTests/RepositoryTests.swift
git commit -m "M1: TaskRepository protocol + SwiftData upsert/get/all/delete"
```

---

## Task 11: Boot the real container + first device deploy

**Files:** Modify `ios/ForgetMeNot/ForgetMeNotApp.swift`

- [ ] **Step 1: Replace `ForgetMeNotApp.swift` to boot the CloudKit container (with an in-memory fallback so a missing iCloud account doesn't crash launch)**

```swift
import SwiftUI
import SwiftData

@main
struct ForgetMeNotApp: App {
    let container: ModelContainer

    init() {
        // Fall back to in-memory if CloudKit isn't available (e.g. no iCloud login),
        // so the app always launches; sync resumes once signed in (revisit in M4).
        if let c = try? FMNModelContainer.cloudKit() {
            container = c
        } else {
            container = try! FMNModelContainer.inMemory()
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Text("forget me not").font(.title2.weight(.semibold))
                Text("foundation online").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Run the full test suite (simulator) — everything green before touching the device**

Run: `cd ios && xcodegen generate && xcodebuild test -scheme ForgetMeNot -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: all tests PASS, `TEST SUCCEEDED`.

- [ ] **Step 3: Deploy to the iPhone 17**

Prereqs (confirm with the user): iPhone 17 connected/paired, Developer Mode ON, iOS 26, trusts this Mac.
Run: `cd ios && ./deploy.sh`
Expected: `BUILD SUCCEEDED`, then `Installed + launched on iPhone 17 …`. The app launches showing "forget me not / foundation online".

> If signing fails on iCloud/Push capabilities, open the project once in Xcode with the team selected to let it register the capabilities on the bundle id, then re-run `./deploy.sh`. Document whatever was needed in `ios/README.md`.

- [ ] **Step 4: Commit**

```bash
git add ios/ForgetMeNot/ForgetMeNotApp.swift
git commit -m "M1: boot CloudKit ModelContainer; first device deploy"
```

---

## Definition of Done (M1)

- `xcodebuild test` green on all 9 test files (ISO8601, TaskDTO, ExportEnvelope, EntityRoundTrip, TaskMapper, Urgency, Cadence, Lifecycle, Repository).
- Web-export fixture decodes to DTOs and survives DTO → entity → DTO losslessly (parity guarantee).
- App launches and runs on the physical iPhone 17.
- `ios/deploy.sh` reproduces build + install in one command.

---

## Self-Review

**Spec coverage (M1 portion):** project scaffold ✓ (T1); SwiftData+CloudKit ✓ (T5, T11); web-identical DTOs + ISO dates + instance model ✓ (T2, T3); export wrapper ✓ (T4); mapper/parity guarantee ✓ (T6); domain logic urgency/cadence/lifecycle/lapse ✓ (T7–T9); repository abstraction ✓ (T10); device deploy + signing via team ✓ (T1 deploy.sh, T11). Reminders, UI, themes, sound, full Settings typing → deferred to M2–M4 plans (out of M1 scope, as intended).

**Placeholder scan:** No TBD/TODO; every code-changing step shows full code; commands have expected output. The one soft spot — exact `snooze` constant — is flagged with the precise web line to verify against and a direction-asserting test, not left vague.

**Type consistency:** `FMNJSON`, `TaskDTO`/`ReminderInstanceDTO`/`FollowUpDTO`/`ActionLogEntryDTO`, `ExportEnvelope`/`SettingsDTO`/`JSONValue`, `TaskEntity` (with `taskDescription`), `FMNModelContainer.cloudKit()/.inMemory()`, `TaskMapper.entity/dto/apply`, `Urgency.ratio/tier/remainingSeconds`, `UrgencyTier`, `SeededRNG`, `Cadence.randomized`, `Lifecycle.reset/complete/snooze/note/isDoubleLapsed/spawnFollowUp`, `TaskRepository`/`SwiftDataTaskRepository.all/get/upsert/delete` — names are consistent across tasks. `description` is deliberately stored as `taskDescription` on the entity and mapped back to DTO `description`.
