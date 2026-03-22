# forget-me-not

**Tagline:** forgot your laundry in the washer? not anymore!

**Repo:** `lucian-labs/forget-me-not`

## What This Is

A standalone, zero-cloud reminder app for recurring and one-time tasks. No accounts, no servers, no sync — everything lives in localStorage (web) or on-device storage (mobile). Uses the yama-bruh FM synth engine for notification sounds — each reminder gets a unique, deterministic ringtone generated from its ID.

This is extracted from the task scheduling model in GroundControl (`ELI7VH/ground-control`), stripped of all server dependencies and rebuilt as a self-contained client-side app.

## Architecture

**Web:** Single-page app. Vanilla TS + Vite. All data in localStorage. Service Worker for background timer wake-ups and push notifications (Notification API, no server).

**iOS:** Native SwiftUI app (iOS 17+). Swift 6. YamaBruh SPM package for FM synth sounds. UserDefaults/JSON file for persistence. UNUserNotificationCenter for local notification scheduling. Modeled after GroundControl iOS (`ELI7VH/ground-control/ios/`).

**Android:** Native Kotlin + Jetpack Compose (API 26+). SharedPreferences/DataStore for persistence. AlarmManager + NotificationManager for scheduling. Web Audio ported to AudioTrack/Oboe for yama-bruh sound generation.

**No cloud. No accounts. No sync. Period.**

## Data Model

Extracted from GroundControl's Task model, simplified to only what a reminder app needs:

```typescript
interface Reminder {
  id: string              // nanoid, used as yama-bruh seed for unique ringtone
  title: string           // "Move laundry to dryer"
  description?: string    // optional details

  // Scheduling
  recurring: boolean      // true = repeats on cadence, false = one-shot
  cadenceSeconds?: number // recurrence interval (only if recurring)
  dueAt: number           // unix timestamp ms — next fire time
  lastResetAt?: number    // last time recurring task was reset (unix ms)

  // State
  status: 'active' | 'snoozed' | 'done' | 'archived'
  snoozedUntil?: number   // unix ms — snooze target

  // Sound
  preset?: number         // yama-bruh preset index (0-99), default random from id
  volume?: number         // 0-1, default 0.8

  // Meta
  createdAt: number       // unix ms
  tags?: string[]         // optional grouping
}
```

### Recurrence Logic

Ported from GC's cadence model:
- **Recurring reminders:** When fired or manually reset, `dueAt` advances by `cadenceSeconds * 1000`. `lastResetAt` updates to now.
- **One-time reminders:** When fired, status flips to `done`. No reset.
- **Snooze:** Sets `snoozedUntil` to `now + (cadenceSeconds * 750)` (75% of cadence, matching GC's snooze behavior). Timer defers until snooze expires.
- **Follow-ups:** Not in v1. Keep the model extensible for later (optional `followUps` array).

### Storage

```typescript
// Web
const STORAGE_KEY = 'fmn:reminders'
const reminders: Reminder[] = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]')
function persist(reminders: Reminder[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(reminders))
}
```

## Sound: yama-bruh Integration

Every reminder generates a unique FM synth ringtone using the yama-bruh notification engine. The reminder's `id` is the seed — same ID always produces the same melody across all devices.

**Integration:** Include `yamabruh-notify.js` as a vendored file (copy from `ELI7VH/yama-bruh/www/yamabruh-notify.js`). It's a single self-contained JS file with all 99+ presets embedded. No WASM, no dependencies.

```typescript
const notify = new YamaBruhNotify({ seed: 'forget-me-not', volume: 0.8 })

function fireReminder(reminder: Reminder) {
  notify.play(reminder.id, {
    preset: reminder.preset ?? hashToPreset(reminder.id),
    volume: reminder.volume ?? 0.8,
    onDone: () => { /* mark as fired, advance cadence or complete */ }
  })
}

// Deterministic preset from id when user hasn't picked one
function hashToPreset(id: string): number {
  let h = 5381
  for (let i = 0; i < id.length; i++) h = ((h << 5) + h + id.charCodeAt(i)) >>> 0
  return h % 100
}
```

**yamabruh-notify.js API surface:**
- `new YamaBruhNotify({ seed?, preset?, bpm?, volume?, sampleRate? })`
- `.play(seedStr?, { preset?, bpm?, volume?, onDone? })` — play ringtone from seed string
- `.stop()` — stop current playback
- `.configure(config)` — update defaults
- `YamaBruhNotify.PRESET_NAMES` — array of 117 preset name strings

**Preset categories (0-99):** Piano (01-10), Organ (11-20), Brass (21-30), Strings (31-40), Bass (41-50), Lead (51-60), Bell/Mallet (61-70), Reed/Pipe (71-80), SFX (81-90), Retro (91-99).

Users can pick a preset per reminder or let it auto-assign from the ID hash. The preset picker should play a preview when tapped.

## UI Spec

Minimal, opinionated, single-screen app with a bottom sheet for create/edit.

### Main Screen
- List of active reminders sorted by next `dueAt`
- Each card shows: title, time-until-due (relative), recurring icon if applicable, preset name
- Swipe left to archive, swipe right to snooze
- Tap to edit
- Overdue items pulse or glow
- FAB (floating action button) to create new

### Create/Edit Sheet
- Title (required)
- Description (optional)
- Recurring toggle → shows cadence picker when on
- Cadence picker: presets (15min, 30min, 1h, 2h, 4h, 8h, daily, weekly) + custom
- Due date/time picker (for first occurrence or one-shot)
- Sound preset picker (grid of preset names, tap to preview)
- Volume slider
- Tags (optional, comma-separated)

### Firing State
When a reminder fires:
- Full-screen overlay with title + pulsing animation
- yama-bruh ringtone plays on loop until dismissed
- Actions: "Done" (complete/reset), "Snooze", "Dismiss" (silence but don't change state)

### Color / Style
- Dark theme default (follows system preference)
- Accent color: `#f49e4c` (amber/orange — urgency without alarm)
- Font: system default, monospace for timestamps
- No gratuitous animation. Functional transitions only.

## Timer Engine

The core scheduler runs client-side. Two strategies, layered:

### 1. Foreground Timer (always active when tab/app is open)
```typescript
// Check every 15 seconds
setInterval(() => {
  const now = Date.now()
  const due = reminders.filter(r =>
    r.status === 'active' &&
    r.dueAt <= now &&
    (!r.snoozedUntil || r.snoozedUntil <= now)
  )
  due.forEach(fireReminder)
}, 15_000)
```

### 2. Service Worker (background, web only)
Register a service worker that:
- Receives the reminder list via `postMessage`
- Uses `setTimeout` / periodic sync (where supported) to check due reminders
- Fires `Notification API` push when due, even if tab is backgrounded
- Clicking the notification focuses the app and shows the firing overlay

### 3. iOS
- `UNUserNotificationCenter` with `UNTimeIntervalNotificationTrigger` per reminder
- Custom sound per reminder via YamaBruh WAV → `Library/Sounds/`
- Notification actions: Done, Snooze (category `fmn-reminder`)
- Reschedule all on app launch (notifications are cleared on reboot)

### 4. Android
- `AlarmManager.setExactAndAllowWhileIdle` per reminder
- `BroadcastReceiver` fires notification with custom WAV sound
- `BootReceiver` re-schedules all alarms after device reboot
- Notification actions: Done, Snooze

## Tech Stack

- **Build:** Vite + TypeScript
- **Framework:** None. Vanilla TS with minimal DOM helpers. No React, no Vue, no Svelte. Keep the bundle tiny.
- **Storage:** localStorage (web), AsyncStorage (RN), Preferences API (Capacitor)
- **Sound:** yamabruh-notify.js (vendored)
- **Notifications:** Service Worker + Notification API (web)
- **PWA:** Full PWA manifest so it installs as a home screen app. Offline-first by design (there's nothing to be online for).

## File Structure

```
forget-me-not/
  src/
    main.ts           # entry, mounts app, starts timer engine
    store.ts          # localStorage CRUD, reminder model
    timer.ts          # foreground interval + service worker bridge
    ui/
      app.ts          # main screen, reminder list
      card.ts         # reminder card component
      sheet.ts        # create/edit bottom sheet
      fire.ts         # firing overlay
      preset-picker.ts # sound preset grid with preview
    sound.ts          # yamabruh-notify wrapper
    sw.ts             # service worker
    types.ts          # Reminder interface, enums
    utils.ts          # time formatting, hash helpers
  public/
    yamabruh-notify.js  # vendored from yama-bruh
    manifest.json       # PWA manifest
    icons/              # app icons
  index.html
  vite.config.ts
  tsconfig.json
  package.json
```

## Build & Dev

```bash
npm create vite@latest . -- --template vanilla-ts
npm install
# copy yamabruh-notify.js to public/
cp ../yama-bruh/www/yamabruh-notify.js public/
npm run dev
```

## Commit Convention

All commits must include:
```
Co-Authored-By: Ana Iliovic <ana@thevii.app>
```

## iOS App

Native SwiftUI, following the same architecture as GroundControl iOS (`ELI7VH/ground-control/ios/`). Same patterns, same conventions, scaled down to just reminders.

### Architecture (from GC iOS)

- **SwiftUI + @Observable** (iOS 17 Observable macro, not ObservableObject)
- **@MainActor** on store class for thread safety
- State passed via `.environment(store)`
- Dark theme forced: `.preferredColorScheme(.dark)`
- No SwiftData/CoreData — JSON file persistence

### Data Model (Swift)

```swift
struct Reminder: Codable, Identifiable, Equatable {
    let id: String              // nanoid, doubles as yama-bruh seed
    var title: String
    var description: String?

    // Scheduling
    var recurring: Bool
    var cadenceSeconds: Int?    // recurrence interval
    var dueAt: Date             // next fire time
    var lastResetAt: Date?

    // State
    var status: ReminderStatus  // .active, .snoozed, .done, .archived
    var snoozedUntil: Date?

    // Sound
    var presetIndex: Int?       // yama-bruh preset (0-99), nil = auto from id hash
    var volume: Float?          // 0-1, default 0.8

    // Meta
    var createdAt: Date
    var tags: [String]?
}

enum ReminderStatus: String, Codable, CaseIterable {
    case active, snoozed, done, archived
}
```

### State Management

```swift
@Observable @MainActor
final class ReminderStore {
    var reminders: [Reminder] = []

    func create(_ reminder: Reminder)
    func update(_ reminder: Reminder)
    func complete(_ id: String)        // done for one-shot, advance cadence for recurring
    func reset(_ id: String)           // reset recurring to now + cadence
    func snooze(_ id: String)          // push 75% into cadence (matching GC snooze)
    func archive(_ id: String)
    func delete(_ id: String)

    func persist()                     // write to JSON file
    func load()                        // read from JSON file
}
```

### Persistence

```swift
// ~/Documents/reminders.json — simple JSON file, no CoreData
private let fileURL: URL = {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("reminders.json")
}()
```

### Sound: YamaBruh SPM Integration

Add YamaBruh as a local SPM dependency (same as GC iOS does):

```swift
// Package dependency in Xcode project or Package.swift:
.package(path: "../../yama-bruh")  // or publish to GitHub and use URL
```

**Notification sound generation** (ported from GC iOS `NotificationSoundGenerator.swift`):

```swift
import YamaBruh

func generateNotificationSound(for reminder: Reminder) -> URL {
    let seed = djb2Hash(reminder.id)
    let appSeed = djb2Hash("forget-me-not")
    let presetIdx = reminder.presetIndex ?? Int(seed % 100)

    let wavData = Ringtone.generate(
        seed: seed,
        appSeed: appSeed,
        presetIndex: presetIdx,
        bpm: 140,
        sampleRate: 44100
    )

    // Write to Library/Sounds for UNNotificationSound
    let soundsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Sounds", isDirectory: true)
    try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)

    let soundURL = soundsDir.appendingPathComponent("fmn-\(reminder.id).wav")
    try? wavData.write(to: soundURL)
    return soundURL
}

// DJB2 hash (matches JS and Rust implementations for cross-platform determinism)
func djb2Hash(_ str: String) -> UInt32 {
    var hash: UInt32 = 5381
    for c in str.utf8 { hash = ((hash &<< 5) &+ hash) &+ UInt32(c) }
    return hash
}
```

**In-app preview playback** (from GC iOS `AudioEngine` pattern):

```swift
import AVFoundation
import YamaBruh

final class SoundEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    @Published var isPlaying = false

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
    }

    func preview(reminder: Reminder) {
        let seed = djb2Hash(reminder.id)
        let appSeed = djb2Hash("forget-me-not")
        let wavData = Ringtone.generate(seed: seed, appSeed: appSeed,
            presetIndex: reminder.presetIndex, bpm: 140, sampleRate: 44100)
        playWavData(wavData)
    }

    func previewPreset(_ index: Int) {
        let wavData = Ringtone.generate(seed: 42, appSeed: 0,
            presetIndex: index, bpm: 140, sampleRate: 44100)
        playWavData(wavData)
    }

    private func playWavData(_ data: Data) {
        // write to temp, load as AVAudioFile, schedule on playerNode
        // (same pattern as yama-bruh AudioEngine.swift)
    }
}
```

### Notifications

```swift
import UserNotifications

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    func requestPermission() async -> Bool {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return true  // simplified
    }

    func schedule(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "forget-me-not"
        content.body = reminder.title
        content.categoryIdentifier = "fmn-reminder"
        content.sound = UNNotificationSound(named:
            UNNotificationSoundName("fmn-\(reminder.id).wav"))

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, reminder.dueAt.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancel(_ id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Re-schedule all active reminders (call on app launch)
    func rescheduleAll(_ reminders: [Reminder]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        reminders.filter { $0.status == .active && $0.dueAt > Date() }
            .forEach { schedule($0) }
    }
}
```

**Notification actions** (from GC iOS pattern):

```swift
// In AppDelegate or App init:
let doneAction = UNNotificationAction(identifier: "done", title: "Done")
let snoozeAction = UNNotificationAction(identifier: "snooze", title: "Snooze")
let category = UNNotificationCategory(identifier: "fmn-reminder",
    actions: [doneAction, snoozeAction], intentIdentifiers: [])
UNUserNotificationCenter.current().setNotificationCategories([category])

// In UNUserNotificationCenterDelegate:
func userNotificationCenter(_ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse) async {
    let id = response.notification.request.identifier
    switch response.actionIdentifier {
    case "done": store.complete(id)
    case "snooze": store.snooze(id)
    default: break // tapped notification — open app to firing view
    }
}
```

### Views

Follow GC iOS view patterns:

| View | Purpose | GC Equivalent |
|------|---------|---------------|
| `ContentView` | Single tab, reminder list | `ContentView.swift` (simplified, no tabs) |
| `ReminderListView` | Main list, sorted by dueAt, swipe actions | `TaskListView.swift` |
| `ReminderRowView` | Card with title, time-until-due, preset name, recurring badge | `TaskRowView.swift` |
| `ReminderDetailView` | Edit form: title, cadence, preset picker, volume | `TaskDetailView.swift` |
| `ReminderCreateView` | Create sheet | `TaskCreateView.swift` |
| `PresetPickerView` | Grid of 99 preset names, tap to preview | (new) |
| `FiringView` | Full-screen overlay when reminder fires, pulsing + ringtone loop | (new) |

### Design Tokens

```swift
enum FMNTheme {
    static let accent = Color(hex: "#f49e4c")   // amber/orange
    static let bg = Color(hex: "#0d1117")
    static let surface = Color(hex: "#161b22")
    static let text = Color(hex: "#c9d1d9")
    static let muted = Color(hex: "#4a6a78")
    static let red = Color(hex: "#ab3428")

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
```

### Project Configuration

```yaml
# project.yml (XcodeGen)
name: ForgetMeNot
settings:
  SWIFT_VERSION: "6.0"
  TARGETED_DEVICE_FAMILY: "1,2"  # iPhone + iPad
targets:
  ForgetMeNot:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources: [Sources]
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: ca.lucianlabs.forgetmenot
      INFOPLIST_VALUES:
        CFBundleDisplayName: forget-me-not
        UIBackgroundModes: [audio, processing]
    dependencies:
      - package: YamaBruh
```

### File Structure (iOS)

```
ios/
  project.yml                     # XcodeGen config
  Sources/
    ForgetMeNotApp.swift          # @main, AppDelegate, notification delegate
    ContentView.swift             # Root view
    Models/
      Reminder.swift              # Reminder struct + ReminderStatus enum
    State/
      ReminderStore.swift         # @Observable store, JSON persistence
    Sound/
      SoundEngine.swift           # AVAudioEngine + YamaBruh preview playback
      NotificationSoundGen.swift  # Generate WAV → Library/Sounds
    Notifications/
      NotificationScheduler.swift # UNUserNotificationCenter scheduling + actions
    Views/
      ReminderListView.swift
      ReminderRowView.swift
      ReminderDetailView.swift
      ReminderCreateView.swift
      PresetPickerView.swift
      FiringView.swift
    Config/
      FMNTheme.swift              # Design tokens
    Utils/
      DJB2.swift                  # Hash function
      TimeFormat.swift            # Relative time strings
  Assets.xcassets/
```

---

## Android App

Native Kotlin + Jetpack Compose. Same data model and UX as iOS, adapted to Android platform conventions.

### Architecture

- **Jetpack Compose** for UI (Material 3, dark theme)
- **ViewModel + StateFlow** for state management
- **DataStore (Preferences)** or JSON file for persistence — no Room, no SQLite
- **AlarmManager** for exact alarm scheduling
- **NotificationManager** for local notifications with custom sound

### Data Model (Kotlin)

```kotlin
@Serializable
data class Reminder(
    val id: String,                    // nanoid
    val title: String,
    val description: String? = null,
    val recurring: Boolean = false,
    val cadenceSeconds: Int? = null,
    val dueAt: Long,                   // unix ms
    val lastResetAt: Long? = null,
    val status: ReminderStatus = ReminderStatus.ACTIVE,
    val snoozedUntil: Long? = null,
    val presetIndex: Int? = null,      // yama-bruh preset 0-99
    val volume: Float? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val tags: List<String>? = null
)

@Serializable
enum class ReminderStatus { ACTIVE, SNOOZED, DONE, ARCHIVED }
```

### State Management

```kotlin
class ReminderViewModel(private val store: ReminderStore) : ViewModel() {
    val reminders: StateFlow<List<Reminder>> = store.reminders
        .stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    fun create(reminder: Reminder)
    fun complete(id: String)
    fun reset(id: String)
    fun snooze(id: String)        // 75% cadence push
    fun archive(id: String)
    fun delete(id: String)
}
```

### Persistence

```kotlin
// JSON file in app internal storage — same approach as iOS
class ReminderStore(private val context: Context) {
    private val file = File(context.filesDir, "reminders.json")
    private val json = Json { ignoreUnknownKeys = true }

    val reminders: Flow<List<Reminder>> = /* MutableStateFlow backed by file reads */

    fun save(reminders: List<Reminder>) {
        file.writeText(json.encodeToString(reminders))
    }
}
```

### Sound: YamaBruh Port

Android doesn't have the YamaBruh Swift package. Two options:

**Option A (recommended): Port yamabruh-notify.js synthesis to Kotlin**
The JS notification engine is ~400 lines of pure Web Audio math. Port the OPLL synthesis, ADSR envelopes, and sequence generator to Kotlin. Render to PCM buffer, play via `AudioTrack`.

```kotlin
object YamaBruhSynth {
    // All 99 presets embedded (port from YAMABRUH_PRESETS array in yamabruh-notify.js)
    private val PRESETS: Array<FloatArray> = arrayOf(/* ... */)

    fun generateRingtone(seed: String, presetIndex: Int, bpm: Int = 140,
                         sampleRate: Int = 44100): ShortArray {
        val noteSeed = djb2Hash(seed)
        val notes = generateSequence(noteSeed, 3 + (noteSeed % 3).toInt())
        return renderNotes(notes, PRESETS[presetIndex], bpm, sampleRate)
    }

    fun generateWav(seed: String, presetIndex: Int): ByteArray {
        val pcm = generateRingtone(seed, presetIndex)
        return encodeWav(pcm, 44100)
    }

    private fun djb2Hash(str: String): UInt {
        var hash: UInt = 5381u
        for (c in str.toByteArray(Charsets.UTF_8)) {
            hash = ((hash shl 5) + hash + c.toUInt())
        }
        return hash
    }
}
```

**Option B: Use yama-bruh WASM via WebView**
Run `yamabruh-notify.js` in a headless WebView, pipe audio out via JavaScriptInterface. Hacky but functional for v1.

### Notifications

```kotlin
class ReminderAlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    fun schedule(reminder: Reminder) {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            putExtra("reminder_id", reminder.id)
        }
        val pending = PendingIntent.getBroadcast(context, reminder.id.hashCode(),
            intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP, reminder.dueAt, pending
        )
    }

    fun cancel(id: String) {
        val intent = Intent(context, ReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(context, id.hashCode(),
            intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.cancel(pending)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra("reminder_id") ?: return

        // Generate notification sound WAV → write to cache dir
        val wavBytes = YamaBruhSynth.generateWav(reminderId, presetIndex)
        val soundFile = File(context.cacheDir, "fmn-$reminderId.wav")
        soundFile.writeBytes(wavBytes)
        val soundUri = FileProvider.getUriForFile(context, "${context.packageName}.provider", soundFile)

        val notification = NotificationCompat.Builder(context, "fmn-reminders")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("forget-me-not")
            .setContentText(/* load title from store */)
            .setSound(soundUri)
            .addAction(R.drawable.ic_done, "Done", /* done PendingIntent */)
            .addAction(R.drawable.ic_snooze, "Snooze", /* snooze PendingIntent */)
            .build()

        NotificationManagerCompat.from(context).notify(reminderId.hashCode(), notification)
    }
}
```

### Design Tokens

```kotlin
object FMNTheme {
    val accent = Color(0xFFf49e4c)
    val bg = Color(0xFF0d1117)
    val surface = Color(0xFF161b22)
    val text = Color(0xFFc9d1d9)
    val muted = Color(0xFF4a6a78)
    val red = Color(0xFFab3428)
}

// Material 3 dark color scheme using these tokens
val FMNColorScheme = darkColorScheme(
    primary = FMNTheme.accent,
    background = FMNTheme.bg,
    surface = FMNTheme.surface,
    onBackground = FMNTheme.text,
    onSurface = FMNTheme.text,
    error = FMNTheme.red,
)
```

### File Structure (Android)

```
android/
  app/
    src/main/
      java/ca/lucianlabs/forgetmenot/
        ForgetMeNotApp.kt           # Application class, notification channel
        MainActivity.kt             # Single activity, Compose entry
        data/
          Reminder.kt               # Data class + enum
          ReminderStore.kt           # JSON file persistence
        viewmodel/
          ReminderViewModel.kt       # StateFlow, CRUD operations
        sound/
          YamaBruhSynth.kt           # FM synthesis engine (ported from JS)
          SoundPlayer.kt             # AudioTrack playback for previews
        notifications/
          ReminderAlarmScheduler.kt  # AlarmManager scheduling
          ReminderReceiver.kt        # BroadcastReceiver → notification
          BootReceiver.kt            # Re-schedule alarms after reboot
        ui/
          theme/
            Theme.kt                 # Material 3 dark theme
            Color.kt                 # FMNTheme tokens
          screens/
            ReminderListScreen.kt
            ReminderDetailScreen.kt
            ReminderCreateScreen.kt
            PresetPickerScreen.kt
            FiringScreen.kt
          components/
            ReminderCard.kt
            CadencePicker.kt
      res/
        drawable/                    # Icons
        values/                      # Strings
      AndroidManifest.xml            # permissions: SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, POST_NOTIFICATIONS
    build.gradle.kts
  build.gradle.kts
  settings.gradle.kts
```

### Permissions (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### Dependencies (build.gradle.kts)

```kotlin
dependencies {
    implementation("androidx.compose.material3:material3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json")
    // No networking libraries — zero cloud
}
```

---

## What NOT to Build

- No user accounts or auth
- No cloud sync, no Firebase, no Supabase
- No analytics or tracking
- No ads
- No social features
- No complex recurring patterns (no "every 3rd Tuesday") — just fixed-interval cadence
- No calendar integration
- No AI anything
