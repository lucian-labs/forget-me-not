# Mascot Model — Handoff

**Goal:** replace the stock Apple Image Playground mascots with creatures in **Elijah's own
drawn style** (cartoon alien animals), without nuking people's devices. Shipping our own
model — on-device or server-side — is on the table.

## Where this plugs in (the seam already exists)

All mascot generation goes through one protocol — swapping the engine needs **zero UI/app
changes**:

```swift
// ios/ForgetMeNot/AI/CharacterService.swift
protocol CharacterService: Sendable {
    var available: Bool { get }
    func generate(prompt: String) async -> CGImage?
}
```

- Current impl: `ImagePlaygroundCharacterService` (Apple `ImageCreator`, style `.animation`).
- Prompt builder: `Characters.prompt(animal:task:)` — already incorporates a **user style
  string** (Settings → "Mascot style", `UserDefaults "fmn.mascotStyle"`) and the **task
  description**. So prompt steering is live today; only the *renderer* needs replacing.
- `CharacterStore` owns evolution + caching + per-task animal persistence. It calls
  `service.generate(prompt:)`. Point it at a new service and everything else stays.
- **Current throttle:** mascots regenerate only at 0% (calm) and 100% (feral), cached to
  `Caches/characters/<taskId>.png`. Richer evolution (25/50/75 + escalating) is intentionally
  parked until generation is cheap enough (this doc).

## The core tension

On-device diffusion (what Image Playground hides) is **expensive** — seconds per image, real
battery/thermal cost. Evolving art across many tasks multiplies that. The style we want
(Elijah's drawings) also isn't expressible through Image Playground's fixed styles. So we need
both **our style** and **a cheaper delivery path**.

## Options (with trade-offs)

### A. Pre-rendered bundled library — recommended near-term
Train the style once, **batch-render an `[animal × mood]` grid offline**, ship the PNGs as app
assets. At runtime, picking a mascot is just choosing the asset for `(animal, moodTier)` — **zero
on-device generation**, instant, private, offline, no thermal cost.
- Implement as `BundledCharacterService` (or skip `CharacterService` for picks entirely and have
  `CharacterStore` map `(animal, tier)` → bundled image).
- ~15 animals × 4 mood tiers = 60 images. At ~150–300 KB each ≈ 10–20 MB in the bundle. Fine.
- Trade-off: finite variety (no truly unique creature per task) and app-size cost. Mitigate by
  shipping more animals, or layering option B/C for "reroll" novelty.
- **This is the path that best matches "don't nuke devices" + "my style."**

### B. On-device Core ML (LoRA → Core ML)
Train a LoRA on a base diffusion model, convert to Core ML (`apple/ml-stable-diffusion`), run
on-device. Live, private, infinite variety.
- Trade-off: heavy (multi-second gens, model download ~1–2 GB, thermal). Use a few-step model
  (SDXL-Turbo / LCM / SD-Turbo) to cut steps. Still the most device-intensive option.
- Good as an optional "generate a fresh one" power feature, not the default per-task path.

### C. Server-side own model
Host our LoRA/model on a backend; the app POSTs `(animal, mood, description, style)` and gets a
PNG. No device cost; full model freedom.
- Trade-off: needs hosting + network + a cost model; breaks the "no-server / offline" property
  the app has today. Pairs naturally with the eventual `SYNC_SPEC` server.
- Could also be a **build-time** service: run it in CI to regenerate the bundled library (A).

### D. Hybrid (likely end state)
Bundle the library (A) for the default per-task mascot + offline; offer on-device (B) or server
(C) for "reroll / surprise me." `CharacterService` already makes this a runtime choice.

## Training the style (LoRA)

**Data — Elijah's drawings:**
- Target **20–50+** clean images in the consistent target style (more = better). Flat
  background, single subject, consistent line/coloring.
- Caption each (e.g. "a `<style>` cartoon alien axolotl, content"). Keep a **trigger token**
  (e.g. `fmnstyle`) in every caption so the LoRA binds to it.
- Normalize to 1024×1024 (SDXL) or 512×512 (SD1.5). Include a spread of moods if possible so the
  model learns content↔feral.

**Train:**
- Tooling: `diffusers` LoRA training scripts or `kohya_ss`. Base: SDXL (quality) or SD1.5
  (lighter / easier Core ML). 1500–3000 steps, lr ~1e-4, rank 16–32. Validate against held-out
  animals not in the training set (generalization to the 15 animal list).
- Output: a LoRA (`.safetensors`).

**Render the library (option A):**
- Batch script: for each `animal ∈ Characters.animals` × `mood ∈ {content, restless, frazzled,
  feral}`, generate N candidates with the LoRA + trigger token, hand-pick the best, export PNG
  named `<animal>-<mood>.png`. Drop into the app's asset catalog. Wire `CharacterStore` to pick
  by `(animals[taskId], Urgency.tier)`.

**Core ML (option B):** convert base+LoRA via `apple/ml-stable-diffusion` (`python_coreml_stable_diffusion.torch2coreml`),
bake or apply the LoRA, ship the `.mlpackage`s (consider on-demand resources for size).

## Recommended plan

1. **Now:** style + description steering is already live (Settings + task field). Keep the 0/100
   throttle.
2. **Phase 1:** Elijah assembles the drawing set + captions (trigger token). Train a LoRA.
3. **Phase 2:** batch-render the `[animal × mood]` library, bundle it, add `BundledCharacterService`
   and switch `CharacterStore` to pick bundled assets for the default per-task mascot. Re-enable
   the full 25/50/75/100 evolution (now free — just asset swaps).
4. **Phase 3 (optional):** Core ML (B) or server (C) behind a "reroll" for unique variants.

## Open questions for Elijah

- How many drawings can you provide, and at what consistency? (Drives LoRA quality.)
- Mood granularity — 4 tiers enough, or do you want more expressive steps?
- App-size budget for a bundled library (~10–20 MB for ~60 images)?
- Is a server path acceptable long-term, or must it stay fully on-device/offline?
- Final animal roster (currently 15 in `Characters.animals`) — keep, expand, or curate to ones
  that read well in your style?
