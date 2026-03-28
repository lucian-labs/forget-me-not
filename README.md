# forget-me-not

Forgot your laundry in the washer? Not anymore.

**[tasks.lucianlabs.ca](https://tasks.lucianlabs.ca/)**

A standalone, localStorage-backed PWA for recurring task management with urgency tracking, follow-up chains, and overdue alerts. Zero server, zero signup — everything lives in your browser.

## Features

- **Recurring + one-time tasks** with real-time urgency bars (green → orange → red → pulsing)
- **Quick-capture on check** — tap ✓, type a note, auto-submits in 1.5s
- **Quick logging** — pencil icon to log what you did without completing/resetting
- **Follow-up chains** — sequential task spawning (e.g. Laundry → Dryer → Fold)
- **Reminders** — random prompts shown when a task is overdue ("Did you check the pockets?")
- **Sound alerts** — YamaBruh-powered notifications with 99 presets, configurable BPM/volume/mood
- **Browser notifications** — fires when the tab is hidden and a task goes overdue
- **11 themes** — Midnight, Sunrise, Selva, Kente, Neon, Cloud, Terracotta, Matcha, Vinyl, Oceano, Sakura
- **Per-theme animations** — each theme has its own exit animation (sakura floats like petals, neon glitches out, vinyl spins, etc.)
- **Per-theme sound defaults** — switching themes sets matching notification sounds
- **Custom fonts** — header and body fonts loaded from Google Fonts, per-theme defaults or user override
- **Full theme customization** — colors, corner radius, text size, spacing, fonts
- **Theme sharing** — share via URL (`#theme=sakura`), copy JSON, paste to import, or load via script tag (CORS-free)
- **Export/import JSON** — full dataset backup and restore
- **URL routing** — browser back/forward and swipe gestures work between views
- **PWA** — installable, works offline via service worker

## Run

```
npm install
npm run dev
```

## Build

```
npm run build
```

Static output lands in `dist/`. Deploy anywhere that serves static files.

## Theme sharing

Share a built-in theme: `https://tasks.lucianlabs.ca/#theme=sakura`

Share a custom theme: use the "Copy share link" button in settings, or export the JSON and host it anywhere.

Load from a gist (no CORS): host a `.js` file that calls `fmnLoadTheme({...theme})` and include it as a script tag.

## Stack

Vite + vanilla TypeScript. No framework. ~16KB gzipped.
