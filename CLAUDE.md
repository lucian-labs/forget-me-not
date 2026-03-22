# forget-me-not

**Tagline:** forgot your laundry in the washer? not anymore!

**Repo:** `lucian-labs/forget-me-not`

## What This Is

A standalone, zero-cloud reminder app for recurring and one-time tasks. No accounts, no servers, no sync — everything lives in localStorage (web) or on-device storage (mobile). Uses the yama-bruh FM synth engine for notification sounds — each reminder gets a unique, deterministic ringtone generated from its ID.

This is extracted from the task scheduling model in GroundControl (`ELI7VH/ground-control`), stripped of all server dependencies and rebuilt as a self-contained client-side app.

## Architecture

**Web:** Single-page app. Vanilla TS + Vite. All data in localStorage. Service Worker for background timer wake-ups and push notifications (Notification API, no server).

**Mobile (future):** React Native or Capacitor wrapper. Same core logic. AsyncStorage or SQLite for persistence. Local notifications via platform APIs.

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

### 3. Mobile (future)
- React Native: `react-native-push-notification` or `expo-notifications` for local scheduling
- Capacitor: `@capacitor/local-notifications`
- Schedule exact alarms per reminder. Re-schedule on app launch.

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

## What NOT to Build

- No user accounts or auth
- No cloud sync, no Firebase, no Supabase
- No analytics or tracking
- No ads
- No social features
- No complex recurring patterns (no "every 3rd Tuesday") — just fixed-interval cadence
- No calendar integration
- No AI anything
