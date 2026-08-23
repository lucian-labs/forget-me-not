# Data model

One entity: `Task`. Everything in the app is a list of them. The canonical
definition, field by field, is [`src/types.ts`](../src/types.ts) — this document
covers the parts the type can't say: how the pieces move, and what you have to
touch when you add to it.

## The shape of the idea

A task is either:

- a **loop** — `recurring: true`, comes due every `baseCadenceSeconds`, forever; or
- a **one-off** — `dueDate` set, done once and gone.

Everything else follows from that split.

## How a loop actually runs

The cadence you set is not the cadence that runs. Each cycle is a fresh
`ReminderInstance`:

```
instance = {
  startedAt:            now,
  actualCadenceSeconds: randomize(base, cadenceMore, cadenceLess),
  snoozed:              false,
}
```

`randomize` picks from `base - cadenceLess … base + cadenceMore` (both null =
exactly `base`), so a loop doesn't fire at the same moment every day.

**Urgency** — the number driving colour, sort order, sounds and alerts — is:

```
ratio = (now - instance.startedAt) / instance.actualCadenceSeconds
```

`1.0` is due. Past `2.0` a loop counts as double-lapsed and auto-resets with a
`lapsed` entry. Measure against `actualCadenceSeconds`, never `baseCadenceSeconds`
— that's the single most common mistake here.

One-offs use `(now - startedAt) / (dueDate - startedAt)` instead.

## What the buttons do

| UI | Store call | Logs | Fires follow-ups | Resets timer |
|---|---|---|---|---|
| ✓ checkpoint | `resetTask` (loop) / `completeTask` (one-off) | `reset` / `complete` | yes | yes |
| ↓ reset | `restartCycle` | `restarted` (hidden) | no | yes |
| zz sleep | `snoozeTask` | `snoozed` (hidden) | no | no — rewinds to 75% elapsed |
| pencil | `addActionNote` | `note` | no | no |
| auto | `checkDoubleLapsed` | `lapsed` | no | yes |

`actionLog` is append-only. `reset`/`complete`/`lapsed` are what count as
completed cycles — they feed the streak strip and the stats. `snoozed` and
`restarted` are telemetry only: captured for cadence tuning, hidden from the
visible history so those two actions stay "quiet". Their `note` holds the urgency
ratio at press time (`"@0.83"`), which is the actual signal worth analysing.

## Prompts

`prompts: string[]` are the nudges shown on a card **once it's overdue** — one
picked at random, re-rolled periodically. They are not instructions or subtasks;
they're a low-activation-energy poke at someone who's stalling. Keep them small
and concrete:

```ts
prompts: ['sweep', 'dust a shelf', 'clear one surface']
```

Add them without clobbering what's there via the agent API:

```js
fmn.addPrompts('tidy', ['sweep', 'dust a shelf'])
```

## Chains (follow-ups)

`followUps: FollowUp[]` describes the steps after this one — laundry → move to
dryer → fold. **The two platforms activate them differently**, which is the other
easy thing to get wrong:

- **Web** — `spawnFollowUp` creates the next step as a real task when the parent
  is checked off, carrying the remaining chain forward and setting `parentTaskId`.
- **iOS** — the children exist up front as dormant tasks (`parentTaskId` set,
  `dueDate: nil`) and are *activated* when the parent is marked done.

Same stored shape, different runtime. Don't infer one from the other.

## Where the data lives

- **Web** — one `localStorage` key holds every task; `Settings` is separate.
  Origin-scoped, so nothing off-page can read it (which is why the agent API is
  a `window` surface and not an endpoint — see [`src/agent.ts`](../src/agent.ts)).
- **iOS** — SwiftData, mirrored to CloudKit's private database.
- Both serialise to the same JSON, so export/import moves between them.

## Adding a field

The type is the easy part. These have to agree, or data silently drops on the
way through:

1. **`src/types.ts`** — add it, and document *why* it exists, not just its type.
2. **`src/store.ts` → `createTask`** — give it a default. Every task ever loaded
   from storage predates your field, so `undefined` has to be survivable.
3. **`importAll` / `exportAll`** — round-trip it. If it's derived, don't store it.
4. **iOS `TaskDTO.swift`** — same name, same JSON encoding, or sync drops it.
   Mind the SwiftData limits noted in that file (no arrays of Codable structs —
   store JSON in a `Data` field with a `@Transient` accessor).
5. **`src/agent.ts`** — add it to `view()` if an agent should see it, and to
   `TaskInput` if an agent should be able to set it. Prefer human units
   (`"2h"` over `7200`); `parseDuration` handles the conversion.
6. **`SYNC_SPEC.md`** — if it changes the sync contract.
7. **`public/llms.txt`** — if it changes what an agent can do.

Two properties worth preserving:

- **Old data must keep working.** There are no migrations; a task written months
  ago is loaded as-is. Default anything missing.
- **Derived values don't get stored.** Urgency, remaining time and streaks are
  computed on read (`getUrgencyRatio`, `getRemainingSeconds`, `getCycleHistory`).
  Storing them creates a second source of truth that will drift.
