## Loops — the concept

A **loop** is a recurring, pre-decided minimum-rep designed to bypass activation-energy freeze and build a specific muscle through volume. It's the opposite of a goal (outcome-oriented, binary) or a to-do (one-off, needs fresh activation each time). Loops treat action as training, not performance.

### The load-bearing insight

**The block is always the decision, not the execution.** The nervous system freezes at "pick," "evaluate," "commit" — not at "do." Loops solve this by pre-deciding everything that normally gets decided per-iteration. What's left is mechanical.

### Anatomy of a loop (components)

1. **Cadence** — how often it fires (daily / weekly / bounded sprint / event-triggered).
2. **Quantum** — smallest indivisible complete unit (1 application, 1 piece, 1 outreach). Not "work on X" — a specific countable thing.
3. **Selection rule** — how you pick the target of this rep. Mechanical, not judgmental. "First listing that matches 2 skills." "Closest piece to my camera." "Most recently finished." Never "best" or "most sellable."
4. **Stakes tier** — training vs. real. Training tier lets you fail cheaply (local jobs, price-on-request, same resumé every time). Real tier is reserved for weekly/monthly higher-effort shots.
5. **Friction reducers** — what's explicitly deferred or reused. No tailoring, same template, no pricing, no platform decision. Every friction you remove is a wall you don't have to climb each rep.
6. **Rep counter** — every attempt counts including failures. Rejections are reps. Silence is a rep. The log doesn't track outcomes, it tracks reps.
7. **Escape criterion** — the conditional that levels you up. "After first sale → decide Stripe." "After 10 reps → start tailoring." Prevents premature optimization AND prevents staying in training tier forever.
8. **Freeze antidote** — the explicit reframe that unlocks action. "List ≠ sell." "Apply ≠ get hired." "Post ≠ get validated." Named in the loop so you can re-read it when the freeze hits.

### Types (from this conversation)

- **Daily loops** — habit-compounding, low per-rep stakes. Example: 1 local job + 1 consulting outreach/day. Training wheels.
- **Sprint loops** — bounded volume burst, medium stakes. Example: 10 art pieces this weekend. Break freeze by overwhelming it.
- **Trigger loops** — conditional, event-activated. Example: "after first sale, evaluate Stripe." Defers premature decisions.

### Why it's different from habit apps

Habit apps (Streaks, Habitica, etc.) model **presence** — did you do it, yes/no. Loops model **resistance** — they encode the freeze-breaker rules, the mechanical selection, the deferred decisions, the stakes tier. The point isn't to remember to do it; the point is to have already pre-decided the path so the doing doesn't require re-deciding.

### The one-sentence version

A loop is a pre-committed structure that converts a resistance-laden decision into a mechanical rep, tracked by volume not outcome, at a pre-tiered stakes level, with the escape condition already defined.

---

## Refinement — entity-centric, event-logged, evidence-bearing

The "do 10 pushups" framing undersells what a loop actually is. A loop is not a counter on a single repeating action — it's a **sequence of events attached to an entity**, producing a growth log over time.

### What the loop actually tracks

- **The entity** — a concrete subject the loop applies to: a piece of artwork, a listing, a project, a product, a writing draft. The loop lives on the entity, not in the abstract.
- **A series of events** — the ordered stages that entity passes through. Example: *chose a piece → posted it on social → added it to the store*. Each of those is an event inside one loop instance for one entity.
- **Evidence per event** — mandatory, not optional. "I did this here's proof" is the shape of each log entry. Links, screenshots, URLs, timestamps. This is the load-bearing difference from tasks: in tasks evidence is optional, in loops it's the whole point.
- **Growth over time** — aggregated across entities and events, the loop becomes a record of moved work. The dashboard isn't "did you do it today" — it's "what did each thing go through, and where did it end up."

### Relation to the existing task model

Loops likely **inherit follow-up task logic**. A follow-up on a task already encodes "after X, do Y" — which is structurally close to "after event A in the loop, event B becomes due." That machinery may be reusable, with the loop layering on: entity identity, required evidence, and ordered stages rather than a flat follow-up list.

### What this implies for the dashboard

The current playground models loops as rep-counters per loop definition. The refactor direction is:

- Top-level: list of **loop templates** (the stage sequence) — e.g. "Artwork release."
- Under each template: list of **entities** moving through it — e.g. *Redwood Study #3*, *Blue Field*, *etc.*
- Per entity: **timeline of events**, each with its stage name, timestamp, and evidence blob.
- "Advance" an entity = log the next event with required evidence, not toggle a boolean.

To be reconciled in the next pass against the GC pipeline-template model (`Loop` + `LoopItem` + stage transitions) — that one is already entity-centric and event-logged, so the two framings probably collapse into a single model once aggregated.

---

## Correction — the loop is the behavior, not the artifact

The previous section got the entity wrong. The artwork is **not** the loop's subject — it's a byproduct that proves the loop ran. The loop is the **internal act of pushing through a specific resistance**, repeated. The artifacts the outside world sees are evidence that you did it.

### The true subject of a loop

| Domain | The loop (subject) | The byproduct (evidence) |
|---|---|---|
| Creative | *publishing / making self vulnerable in public* | the artwork posted, the listing created |
| Professional | *putting self out for rejection / judgment* | applications sent, responses, follow-ups, interviews |
| Physical | *breaking the mental barrier to enter workout mode* | reps logged (40 pushups, then 45, etc.) |

In every case, the loop names a **behavioral practice with a specific internal resistance attached**. The repeated successful execution of that practice hardens the nervous system's ability to do it without freeze.

### Tasks vs. loops, again — sharper

- A **task** is *"did 40 pushups"* — a specific action, evidence optional, reminder-driven. It's a thing to remember and do.
- A **loop** is *"entered workout mode today"* — a behavioral practice, evidence is the byproduct artifact, barrier-breaking is the whole point.

The pushups live *inside* a run of the workout loop. The task is what got produced; the loop is the act of getting past the wall to produce it. Same relationship: the job application is inside a run of the "apply-to-things" loop; the posted artwork is inside a run of the "publish" loop.

This also means daily-habit apps can't model loops. They track the artifact (did you do 40 pushups) and miss the actual unit of growth (did you get past the resistance and enter the mode). Two people with identical pushup counts can be running entirely different loops — or no loop at all.

### Categories — the three axes of "adulting plus"

- **Personal loops** — self-regulation and barrier-breaking against one's own friction. Getting out the door. Entering workout mode. Sleep routine.
- **Professional loops** — career exposure, vulnerability to external judgment, making asks. Job applications, consulting outreach, pitches, cold messages.
- **Creative / self-purpose loops** — publishing, self-expression under exposure, making-for-others. Posting work, listing it, putting one's face on it.

Overall framing: loops are **adulting plus** — the meta-practice of hardening one's execution across each life domain by making the resistance mechanical. The specific action varies; the friction being trained is domain-specific; the mechanism (pre-decided, repeated, evidenced) is shared.

### Implication for the model

This shifts the core data model:

- The top-level **Loop** is a named behavioral practice (e.g. *"publish creative work"*, *"apply for gigs"*, *"enter workout mode"*) with its friction, cadence, stakes tier, and freeze antidote baked in.
- Each **run** of the loop is one rep of that behavior. Runs have timestamps, a stage log (if the practice has sub-stages like pick → post → list), and **attached byproducts as evidence** (artifact links, artwork, application URLs, rep counts).
- Growth is measured in two axes: **rep count over time** (did you keep showing up), and **byproduct accumulation** (what the outside world sees — posted pieces, applications sent, sessions completed).

Tasks and loops are now clearly distinct but composable. Tasks can be produced *by* a loop run (the pushup-count task is created when the workout-loop rep is logged). That inheritance/spawning relationship is probably where the follow-up-task logic gets reused.

