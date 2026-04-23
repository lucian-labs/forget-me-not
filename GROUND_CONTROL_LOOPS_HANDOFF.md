# Ground Control → Loops Handoff

Extract of the Loops feature from `ground-control` (Express + Mongoose + MongoDB) for a v2 rebuild in `forget-me-not`. The GC database and app stay as-is; this doc is the spec for rebuilding the concept elsewhere.

Source files in GC: `src/db/models/Loop.ts`, `src/db/models/LoopItem.ts`, `src/routes/loops.ts`, `src/routes/dashboard.ts` (loop sections), `src/dashboard/views.ts` (loop UI), `src/dashboard/config.ts`.

---

## Concept

A **Loop** is a reusable multi-stage pipeline template (stages in order). A **LoopItem** is a concrete instance moving through those stages.

- 1 Loop → N LoopItems
- Loops chain: `loop.outputTo = otherLoopSlug` — completing the last stage can spawn a new item in a downstream loop (preserving title/data/project).
- No cron, no rollover, no snooze. **Pull-based and manual.** `stage.timingHours` is a passive SLA marker only — UI flags OVERDUE when `now > item.enteredStageAt + timingHours`.
- Recurring-reminder behavior lives in the separate `Task` model, not Loops. (That's already moved out.)

Items can be tagged with a `project` string (a product/service slug — in GC this is a `Project` with `type != "project"`). The dashboard supports `parentProject` filtering that resolves child products server-side via `Project.find({ parent: slug })`.

---

## Data Model

### Loop

| Field | Type | Notes |
|---|---|---|
| `slug` | string | unique, indexed, immutable (identity) |
| `name` | string | display name |
| `description` | string? | optional |
| `stages` | `LoopStage[]` | ordered pipeline |
| `outputTo` | string? | slug of downstream loop for chaining |
| `status` | enum | `active` \| `paused` \| `archived` (default `active`) |
| `metadata` | object | arbitrary extensions |
| `createdAt`, `updatedAt` | Date | timestamps |

**LoopStage (embedded, no `_id`):**

| Field | Type | Notes |
|---|---|---|
| `key` | string | unique within loop; auto-slugified from `name` if missing |
| `name` | string | display |
| `description` | string? | optional |
| `order` | number | 0-indexed position |
| `timingHours` | number? | SLA; used by UI for OVERDUE badge |

Indexes: `{slug:1}` unique, `{status:1, updatedAt:-1}`, `{outputTo:1}`.

### LoopItem

| Field | Type | Notes |
|---|---|---|
| `loop` | string | ref `Loop.slug`, required, indexed |
| `project` | string? | product/service slug, indexed |
| `stage` | string | current `LoopStage.key`, indexed |
| `status` | enum | `active` \| `completed` \| `dropped` \| `chained` (default `active`) |
| `title` | string | required |
| `data` | object | arbitrary user fields |
| `history` | `StageTransition[]` | append-only audit trail |
| `source` | string | `manual` (default) \| `api` \| `chained` |
| `sourceItemId` | ObjectId? | set when `source=chained`; points to upstream item |
| `enteredStageAt` | Date | set on every stage change |
| `completedAt`, `droppedAt` | Date? | terminal timestamps |
| `droppedReason` | string? | |
| `lastTouchedBy` | string? | `dashboard` / `api` / machine name |
| `metadata` | object | extensions |
| `createdAt`, `updatedAt` | Date | timestamps |

**StageTransition (embedded):** `{ from: string\|null, to: string, at: Date, notes?: string, by?: string }`.

Pseudo-`to` values used only in history (not real stage keys): `_completed`, `_dropped`, `_chained→<slug>`.

Indexes: `{loop:1, project:1, status:1}`, `{loop:1, stage:1, status:1}`, `{project:1, status:1}`.

### Status lifecycle

```
active ──advance──▶ active (next stage)
active ──advance at last stage──▶ completed  (if no outputTo)
active ──chain at last stage ───▶ chained    (spawns downstream item)
active ──drop─────▶ dropped
```

All terminal states are one-way. No resurrection.

---

## API Surface

Auth: `X-API-Key` on everything. GC has two route trees that mirror each other — consolidate in v2.

| Method | Path | Purpose |
|---|---|---|
| GET | `/loops` | List (`?status=`) |
| POST | `/loops` | Create (auto-slugifies `name`→`slug`, stage `name`→`key`) |
| GET | `/loops/:slug` | Detail + `{stageCounts, totalActive}` (active only) |
| PATCH | `/loops/:slug` | Update `name`, `description`, `stages`, `outputTo`, `status`, `metadata` |
| DELETE | `/loops/:slug` | 400 if active items exist |
| GET | `/loops/:slug/items` | List (`?stage=`, `?status=`, `?project=`; default status `active`) |
| POST | `/loops/:slug/items` | Create — places item at first stage, seeds history `{from:null, to:firstStage}` |
| PATCH | `/loops/:slug/items/:id` | Update `title`, `data`, `project`, `metadata`, `lastTouchedBy` |
| POST | `/loops/:slug/items/:id/advance` | Next stage. At last stage: completes (if no `outputTo`) or returns `{atEnd:true, canChain:true, outputTo}` |
| POST | `/loops/:slug/items/:id/move` | Direct jump — `{stage, notes?, by?}` — powers drag-drop |
| POST | `/loops/:slug/items/:id/drop` | `{reason?, by?}` → status `dropped` |
| POST | `/loops/:slug/items/:id/chain` | Requires `loop.outputTo`. Marks original `chained`, spawns new item in downstream loop preserving `title`/`data`/`project`, `source=chained`, `sourceItemId=original._id` |

Dashboard-only duplicates exist at `/dashboard/loop/:slug*` with extra response shape (`activeProjects` list, `parentProject` resolution) and are what the UI actually calls.

---

## Dashboard UI

**List view:** loop cards with status badge, total active count, stage badges with per-stage counts, `chains to → X` indicator.

**Detail view (kanban):** horizontal column per stage.
- Column header: stage name, description, SLA hours badge, item count.
- Item card: title (click expands), project badge, age, OVERDUE flag if `age > timingHours`, buttons `Advance ▶` / `Chain →` / `Complete` (last-stage variants) / `Drop`.
- Expanded pane: `data` k/v, reversed history timeline, "Move to stage" dropdown.
- Drag-drop between columns → `POST /move`.
- Parent-project filter dropdown at top — server resolves child products via `Project.find({parent: slug})`.

**Edit loop form:** name, description, `outputTo`, stages table (name/description/SLA hrs), add-stage button.

**Add-item form:** title, project, data (key=value lines parsed to JSON).

---

## Invariants

1. `slug` is unique and immutable.
2. `stage.key` unique within a loop (naive slugify — be careful with collisions).
3. `history` is append-only.
4. Terminal states (`completed`, `dropped`, `chained`) are one-way.
5. Cannot delete a loop with active items.
6. Chaining preserves `title`, `data`, `project`; `sourceItemId` back-links.
7. `outputTo` validated at chain time, not at loop save (forward refs allowed).

---

## Side Effects

Each mutation broadcasts to the dashboard (WS/SSE) as `{type:"loop-item", data:{action, loop, itemId, ...}}` where `action ∈ {created, advanced, completed, dropped, chained}`. **No** Telegram, email, or task-spawning. No outbound webhooks.

---

## Known Quirks to Fix in v2

- **`project` naming trap.** `LoopItem.project` holds a product/service slug, not a top-level project slug. GC's `Project` model is recursive with `type ∈ {project, product, service, library}`; leaves are what items point at. Rename to `productSlug` or pick clearer terminology.
- **Duplicated routes.** `/loops/*` (agent API) and `/dashboard/loop/*` (UI) have drifted. Ship one tree.
- **Pseudo-stages in history.** `_completed`/`_dropped`/`_chained→slug` pollute history queries. Store status transitions in a separate field or as explicit typed events.
- **Double slugification.** Frontend + backend both slugify stage names independently. Pick one (backend) and send raw names from UI.
- **No batch endpoints.** Advancing N items = N requests.
- **No seed data.** Loops are created ad-hoc; ship a starter set in v2 (sales cycle, QA, onboarding) for onboarding new users.
- **No soft-delete.** Dropped items live forever in `status: dropped`. Consider TTL or archive table.

---

## Minimum Rebuild Checklist

Core:
- [ ] Loop CRUD
- [ ] LoopItem CRUD + filter by `stage`/`status`/`project`
- [ ] `advance`, `move`, `drop`, `chain` transitions with history append
- [ ] Delete-guard on loops with active items

UI:
- [ ] Kanban with drag-drop → `move`
- [ ] Item detail pane (data, history, move)
- [ ] Loop edit (stages CRUD)
- [ ] Add-item form
- [ ] OVERDUE flag from `enteredStageAt + timingHours`
- [ ] Parent-product filter (if you keep the product concept)

Optional:
- [ ] Real-time broadcast
- [ ] Batch advance/drop
- [ ] Archival/TTL for terminal items
