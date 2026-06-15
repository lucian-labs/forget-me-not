# Forget Me Not — Native iOS Rebuild (v1) — Design

**Date:** 2026-06-15
**Status:** Approved (pending spec review)
**Author:** Elijah + Claude

## Goal

Rebuild the iOS app **from zero** as a clean, native SwiftUI app at **feature parity** with the web PWA (`tasks.lucianlabs.ca`), deployed directly to a physical **iPhone 17**. The web app remains the **source of truth** for feature iteration; iOS mirrors it. Net-new iOS-only superpowers are explicitly deferred (see Non-Goals).

The current `ios/` SwiftUI port is a useful parity *reference* but is **not** the model of record — it flattened the web's data model (lost the `instance` concept, `soundSeed`, the `lapsed` action, ISO-8601 dates). The rebuild follows the **web types** (`src/types.ts`, `src/store.ts`), not the old port. The old `ios/` is preserved in git history.

## Non-Goals (v1)

Deferred as fast-follows — they will be designed on the web first, then ported. Architectural **seams are kept** so they drop in without rework:

- AI capture via Apple Intelligence / Foundation Models
- Home Screen / Lock Screen **widgets**, **Live Activity**, Control Center controls
- **Siri / App Intents / Shortcuts**
- Theme **sharing** via URL / JSON / script tag
- The 99-preset "YamaBruh" web-audio **sound synth** (replaced by a small native sound set + haptics)
- Self-host **sync server** (`SYNC_SPEC.md`) — deferred, but the web-identical JSON interchange format is preserved so it can be added later

## Decisions (resolved during brainstorming)

| Question | Decision |
| --- | --- |
| Ambition | Native parity v1; AI/widgets/Siri deferred |
| Persistence | **SwiftData + CloudKit** private database (auto-sync across the user's Apple devices) |
| Interchange | Codable DTOs mirroring the web JSON **1:1**; a mapper translates entity ↔ web-JSON for export/import + future server sync |
| Settings | Stored **locally** (UserDefaults / `@AppStorage`) — matches the web's current local-only settings |
| Cosmetics | Port the 11 themes + full customization; native sounds + haptics; drop sharing + synth |
| Language / target | Swift 6 (strict concurrency), min **iOS 18**, single app target, **XcodeGen** |
| Distribution | Build → sign with `Apple Development: Elijah Lucian` cert + team → install on iPhone 17 via `devicectl` |

## Architecture

SwiftUI **MV** (Model-View) with an `@Observable` app store — no per-view view-models. Single app target. Internal module boundaries (folders, each with one clear purpose):

```
Models/        Codable DTOs (web-identical) + enums + value types
Persistence/   SwiftData @Model entities, ModelContainer (CloudKit), TaskRepository protocol + impl, TaskMapper (entity <-> DTO)
Domain/        Pure functions: urgency, cadence randomization, follow-up spawn, lapse detection, next-fire computation
Reminders/     ReminderScheduler over UNUserNotificationCenter, notification actions, background refresh
Store/         @Observable AppStore (orchestrates repository + scheduler + settings)
Theme/         11 themes + resolver + customization + fonts
Sound/         Native sound set + haptics
Views/         Panel, TaskCard, TaskDetail, CreateTask, Settings, FontPicker, UrgencyBar
```

**Why this shape:** the repository protocol + pure-function domain keep all logic testable without a UI or a live CloudKit container; the DTO/mapper boundary keeps the persistence engine (CloudKit today, a sync server later) independent of the portable format the web owns.

## Data Model

### Interchange DTOs (web-identical — `src/types.ts`)

Codable structs mirroring the web `Task` exactly, including the **instance-based** recurrence model:

- `Task`: `id, title, description, domain, tags[], status, priority, createdAt, updatedAt, dueDate?, startedAt?, completedAt?, estimatedHours?, recurring, baseCadenceSeconds?, cadenceMore?, cadenceLess?, instance?, followUps[], parentTaskId?, prompts[], soundSeed?, actionLog[]`
- `ReminderInstance`: `{ startedAt, actualCadenceSeconds, snoozed }` — present iff the recurring task has a live cycle. `startedAt` is the cycle's reset point; `actualCadenceSeconds` is the randomized cadence for *this* cycle (within `[base-less, base+more]`).
- `FollowUp`: `{ title, cadenceSeconds, domain? }`
- `ActionLogEntry`: `{ note, at, action }`, `action ∈ {reset, complete, note, lapsed}`
- Enums: `TaskStatus`, `TaskPriority`, `ActionType` as String-raw.
- **Dates: ISO-8601 strings** matching JS `Date.toISOString()` (UTC, millisecond precision, `Z` suffix). Swift side uses `ISO8601DateFormatter` with `.withInternetDateTime` + `.withFractionalSeconds`.
- **Export wrapper:** `{ tasks: Task[], settings: Settings, exportedAt: ISO, version: 1 }` (matches `exportAll()`). Import is tolerant/merging (matches `importAll()` + `migrateTask`).

### SwiftData entities (CloudKit-compatible)

`@Model` classes obeying CloudKit rules — **every attribute optional or defaulted, no `@Attribute(.unique)`, relationships optional with inverses**:

- `TaskEntity` — all DTO fields as native types (`Date`, `Double`, `Bool`, raw-string enums). The `ReminderInstance` is embedded as three optional columns (`instanceStartedAt`, `instanceActualCadenceSeconds`, `instanceSnoozed`). `tags`, `prompts`, `followUps`, `actionLog` stored as Codable arrays on the entity (simplest exact mapping to the web JSON).
- `id` kept as a logical `String` UUID (not unique-constrained — dedupe on import in code).

**CloudKit conflict policy:** last-writer-wins per task on `updatedAt` (CloudKit merges at record granularity). Accepted for v1. The append-only-log union-merge described in `SYNC_SPEC.md` is a *server* concern and only applies if/when the sync server is added.

### TaskMapper

`TaskEntity ↔ Task` (DTO). Round-trip must be lossless: `dto → entity → dto == dto`. This is the parity guarantee and is covered by tests.

## Domain Logic (pure, TDD)

Ported precisely from `src/store.ts`:

- `urgencyRatio(task, now)` — from `instance.startedAt + instance.actualCadenceSeconds` for recurring, or `startedAt → dueDate` window otherwise.
- `remainingSeconds`, urgency color/class thresholds (green → orange → red → pulsing).
- `randomizeCadence(base, more, less)` — applied when a new instance starts.
- `resetTask` / `completeTask` — append to action log, start a new randomized instance (reset) or mark done (complete), and spawn the first follow-up if any.
- `snoozeTask` — shift the instance start so urgency drops (web uses `actualCadenceSeconds * 0.75`).
- `checkDoubleLapsed` / lapse handling — auto-reset double-lapsed recurring tasks to keep the loop alive, unless sleep mode is on; appends a `lapsed` log entry.
- `spawnFollowUp(parent)` — create the next chained task from `followUps`.

## Reminders (native equivalent of the web's browser notifications)

- `UNUserNotificationCenter` local notifications. Authorization requested on first relevant action (creating a recurring task / enabling reminders), with a graceful denied state.
- On every task mutation, the `ReminderScheduler` **(re)schedules a one-shot** notification at the task's next-fire time (`instance.startedAt + actualCadenceSeconds`, or `dueDate`). Body text drawn randomly from the task's `prompts`.
- **Reconcile-all** on app launch and via a `BGAppRefreshTask`, so the schedule stays correct after time passes in the background.
- Notification **category + actions**: Done, Snooze, Log (text input) — handled to mutate the store directly from the notification.
- **Sleep mode** suppresses auto-reset of lapsed tasks (parity with the web's sleep toggle).
- Foreground: urgency bars animate via `TimelineView(.periodic)` (no manual `Timer` tick); in-app overdue presentation + sound/haptic.

## UI (parity)

- **PanelView** — active tasks sorted by urgency; header (app name, version, sleep toggle, add button); streak strip / pips.
- **TaskCardView** — title, urgency bar, streak pips, quick ✓ (complete/reset with a note that auto-submits after ~1.5s), pencil (quick log).
- **TaskDetailView** — full detail, action log condensed by day, prompts, edit, follow-ups, archive/delete.
- **CreateTaskView** — title, recurring + cadence with variance (more/less), due date, domain, tags, follow-up chain editor, prompts, per-task sound seed.
- **SettingsView** — theme picker (11) + customization (colors, radius, font size, header/body fonts, spacing), sound + haptics, notifications permission/toggle, sleep mode, export/import JSON, clear all, app name, domains.
- **FontPickerView** — font selection.

## Theming

Port the 11 themes (Midnight, Sunrise, Selva, Kente, Neon, Cloud, Terracotta, Matcha, Vinyl, Oceano, Sakura) from `src/themes.ts`. `ThemeColors` (10 named roles) + `borderRadius`, `fontSize`, `headerFont`, `bodyFont`, `spacing`, per-theme `animation` + `sound` defaults. User customization overrides resolve on top of the chosen preset. Light/dark color scheme per theme. Fonts: system + bundled where a web font has a close native analog.

## Sound & Haptics

A small curated set of native notification sounds (bundled `.caf`/system sounds) plus `UIFeedbackGenerator` haptics. The per-task `soundSeed` selects within the set deterministically. No web-audio synth.

## CloudKit Specifics

- iCloud + CloudKit capability, container `iCloud.com.forgetmenot.app`; `aps-environment` + `remote-notification` background mode for sync push.
- `ModelConfiguration(cloudKitDatabase: .private(...))` (or `.automatic`).
- Signing must carry iCloud + Push entitlements; automatic signing under the paid team registers them. First device deploy may require enabling the capabilities on the bundle id.

## Testing (TDD)

- In-memory `ModelContainer` (`isStoredInMemoryOnly: true`) for persistence tests.
- Pure-function tests: urgency math, cadence randomization (seeded/injected RNG), follow-up spawn, snooze, lapse detection, next-fire computation.
- **Mapper round-trip** tests against real web-format JSON fixtures (the parity guarantee).
- Repository CRUD tests.
- Scheduler tests with an injected fake notification center (assert scheduled request set).

## Build & Deploy

- `xcodegen generate` → `xcodebuild` build.
- Sign: auto-discover `Apple Development: Elijah Lucian` identity; `DEVELOPMENT_TEAM` from `APPLE_TEAM_ID` in `lucian-utils/.env`.
- Install to iPhone 17: `xcrun devicectl device install app` (device paired, Developer Mode on, iOS 26).
- A `deploy.sh` script encodes generate → build → install, mirroring the house deploy pattern.

## Milestones (each ends with a build deployed to the iPhone 17)

1. **Foundation** — XcodeGen project, SwiftData+CloudKit entities, DTOs, `TaskMapper`, `TaskRepository`, domain logic, full unit-test suite. Empty-but-running app on device.
2. **UI parity** — Panel / TaskCard / TaskDetail / CreateTask / Settings / FontPicker + theming. Usable app on device.
3. **Reminders** — `ReminderScheduler`, notification actions, background refresh, sleep mode. The core "forget me not" payoff on device.
4. **Cosmetics + I/O** — native sounds + haptics, export/import (web-format), settings completeness, device polish.

## Risks / Open Items

- **JSON parity** must match the web byte-shape (field names, ISO dates, instance model) — locked by mapper round-trip tests against fixtures captured from the web's `exportAll()`.
- **CloudKit device provisioning** — first deploy may need capability registration; automatic signing under the paid account should handle it.
- **CloudKit eventual consistency** — first-sync latency and record-level LWW are accepted for v1.
- **Settings divergence** — settings are local-only in v1 (parity with the web today); revisit if/when the sync server lands.
