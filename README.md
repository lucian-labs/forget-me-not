# forget-me-not

Forgot your laundry in the washer? Not anymore.

A standalone, localStorage-backed PWA for recurring task management with urgency tracking, follow-up chains, and overdue alerts. Zero server, zero signup — everything lives in your browser.

## Features

- **Recurring + one-time tasks** with real-time urgency bars (green → orange → red → pulsing)
- **Quick-capture on check** — tap ✓, type a note, auto-submits in 1.5s
- **Quick logging** — pencil icon to log what you did without completing/resetting
- **Follow-up chains** — sequential task spawning (e.g. Laundry → Dryer → Fold)
- **Decision prompts** — random reminders shown when a task is overdue
- **Sound alerts** — YamaBruh-powered notifications with 99 presets, configurable BPM/volume/mood
- **Browser notifications** — fires when the tab is hidden and a task goes overdue
- **11 themes** — Midnight, Sunrise, Selva, Kente, Neon, Cloud, Terracotta, Matcha, Vinyl, Oceano, Sakura — plus full color/radius/size/spacing customization
- **Export/import JSON** — full dataset backup and restore
- **Sync config** — Obsidian-style: plug in your own endpoint and API key, you own the pipe
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

## Stack

Vite + vanilla TypeScript. No framework. ~40KB gzipped.
