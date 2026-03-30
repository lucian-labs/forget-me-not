# Themes & Plugins System

Design considerations for a cross-platform theme and plugin system, informed by how VSCode, Obsidian, and similar tools handle extensibility.

---

## Theme System

### Core Principle

A theme is a JSON document that describes visual presentation. The same theme definition should produce a coherent look across web and iOS, even if the rendering differs per platform.

### Theme Schema (shared)

```jsonc
{
  "name": "my-theme",
  "label": "My Theme",
  "author": "someone",
  "version": 1,
  "colors": {
    "bg": "#0a0a0a",
    "surface": "#141414",
    "border": "#2a2a2a",
    "text": "#e0e0e0",
    "dim": "#666666",
    "accent": "#60a5fa",
    "green": "#4ade80",
    "orange": "#fb923c",
    "red": "#ef4444",
    "cyan": "#22d3ee"
  },
  "typography": {
    "headerFont": "Fira Code",        // resolved per-platform
    "bodyFont": "Fira Code",
    "fontSize": 14,
    "headerWeight": 600
  },
  "layout": {
    "borderRadius": 6,
    "spacing": "normal",               // compact | normal | relaxed
    "cardPadding": 12
  },
  "animation": "fade",                 // web-only, ignored on iOS
  "sound": {                            // optional defaults
    "preset": 88,
    "bpm": 160,
    "volume": 0.4,
    "mode": 1
  }
}
```

### Per-Platform Font Resolution

This is the central divergence between platforms.

**Web:**
- Arbitrary Google Fonts loaded via `<link>` at runtime — zero cost to support any font.
- Theme specifies font name directly; the app calls `fonts.googleapis.com`.
- Fallback chain in CSS (`'Fira Code', 'SF Mono', monospace`).
- User can type any font name. Invalid names degrade to system fallback.

**iOS:**
- No runtime font loading from URLs. Three options:
  1. **System fonts** (~80 families ship with iOS). Enumerate via `UIFont.familyNames`. This is what Obsidian does — it surfaces the full system font list and lets users pick. Zero bundle cost.
  2. **Bundled fonts** — include .ttf/.otf in the app bundle. Increases binary size. Requires licensing. Only worth it for a few signature fonts.
  3. **On-demand download** — `CTFontDescriptorMatchFontDescriptorsWithProgressHandler` can download from Apple's font server. Limited to Apple's curated set. Not guaranteed to include the font you want.
- Best approach: Use system fonts as first-class, with a mapping table from Google Font names → closest iOS system font. When a theme specifies "Fira Code", iOS resolves it to "Menlo".

**Font mapping table (current):**

| Web (Google Font)       | iOS (System Font)        | Category    |
|------------------------|--------------------------|-------------|
| Fira Code              | Menlo                    | Monospaced  |
| JetBrains Mono         | Menlo                    | Monospaced  |
| Space Mono             | Courier New              | Monospaced  |
| IBM Plex Mono          | Menlo                    | Monospaced  |
| Orbitron               | Courier New              | Monospaced  |
| Playfair Display       | Didot                    | Serif       |
| Lora                   | Georgia                  | Serif       |
| Cormorant Garamond     | Baskerville              | Serif       |
| Source Serif 4         | Charter                  | Serif       |
| Kaisei Tokumin         | Hiragino Mincho ProN     | Serif/JP    |
| Poppins                | Avenir Next              | Sans        |
| Quicksand              | Gill Sans                | Sans/Round  |
| Josefin Sans           | Futura                   | Sans        |
| Nunito                 | Avenir Next              | Sans        |
| Inter                  | Helvetica Neue           | Sans        |
| Bebas Neue             | DIN Condensed            | Condensed   |
| Raleway                | Avenir                   | Sans        |
| Open Sans              | Helvetica Neue           | Sans        |
| Noto Sans JP           | Hiragino Sans            | Sans/JP     |

**Future (Android):**
- Google Fonts available natively via `Downloadable Fonts` API (Play Services).
- Closest to web behavior — specify the name, system downloads it.
- Fallback to system fonts (Roboto, Noto) if download fails.

### Theme Distribution

Obsidian uses a community theme gallery with a git-backed registry. VSCode uses the marketplace. For FMN:

**Phase 1 (now):**
- Share via JSON copy/paste (already works on web).
- Share via URL with base64-encoded theme (already works on web).
- Import/export in settings on both platforms.

**Phase 2:**
- Theme gallery endpoint (could be a simple JSON index on CDN).
- Each theme is a JSON file at a known URL pattern.
- App fetches the index, shows available themes, user taps to install.
- No review process — anyone can submit via PR to a themes repo.

**Phase 3:**
- User accounts (tied to sync system).
- "Publish theme" from within the app.
- Rating/popularity sorting.

### Theme Customization Layers

Following Obsidian's model of base theme + CSS snippets:

```
Built-in theme defaults
  └── User-selected theme preset (overrides all defaults)
       └── User color overrides (per-color)
            └── User font overrides (header + body)
                 └── User layout overrides (radius, size, spacing)
```

Each layer only stores the delta from the layer above. Switching theme presets clears all layers below it (current behavior).

---

## Plugin System

### What Plugins Would Do

Plugins extend behavior, not just appearance. Potential categories:

1. **Data source plugins** — Connect to external backends (Notion, Todoist, Google Tasks, custom API). The `DataSource` protocol on iOS is already designed for this.
2. **Notification plugins** — Custom alert strategies (Slack webhook, email digest, push notification services).
3. **View plugins** — Custom card layouts, dashboard widgets, calendar view, kanban board.
4. **Automation plugins** — Rules engine ("when task X goes overdue, create task Y", "auto-archive after 3 completions").
5. **Import/export plugins** — Converters for other task formats.

### Per-Platform Plugin Considerations

**Web:**
- Easiest platform for plugins. JavaScript is inherently extensible.
- Plugins can be loaded as ES modules from URLs (like the existing `fmnLoadTheme()` script-tag approach).
- Sandboxing: Run plugin code in a Web Worker or iframe for isolation. Or accept the risk for a trust-based community model (Obsidian's approach — plugins run with full access).
- Plugin API surface: Expose a `FMN` global with hooks for lifecycle events, data access, UI injection points.

```js
// Example plugin registration
FMN.registerPlugin({
  name: 'slack-notify',
  version: 1,
  onTaskOverdue(task) {
    fetch(this.settings.webhookUrl, {
      method: 'POST',
      body: JSON.stringify({ text: `Overdue: ${task.title}` })
    })
  }
})
```

**iOS:**
- Native plugins are hard. Apple doesn't allow arbitrary code execution.
- Options:
  1. **Built-in plugin catalog** — Ship plugin code in the app binary, let users enable/disable. New plugins require an app update. This is how most iOS apps handle it.
  2. **JavaScriptCore** — Run JS-based plugins in a sandboxed JSC context. Plugins get a limited API surface (no DOM, no network by default). This is how some apps (like Scriptable) handle user extensibility.
  3. **Shortcuts / App Intents** — Expose task operations as Shortcuts actions. Users build automation in Shortcuts app. Low effort, leverages platform.
  4. **URL schemes** — `forgetmenot://create?title=...` for inter-app automation.
- Recommendation: Start with Shortcuts integration (App Intents) + URL scheme. Consider JSC for power users later.

**Cross-platform plugin format:**
- Plugins written in JS can work on both web (native) and iOS (via JSC).
- The plugin API should be the same interface on both platforms.
- Platform-specific capabilities (DOM manipulation, UIKit) are not part of the plugin API — plugins interact through an abstract FMN SDK.

### Plugin Lifecycle

```
discover → install → configure → activate → [run] → deactivate → uninstall
```

- **discover**: Browse gallery or paste URL.
- **install**: Download plugin manifest + code. Store locally.
- **configure**: Plugin declares its settings schema. App renders a settings form.
- **activate**: Plugin hooks into app lifecycle events.
- **run**: Plugin code executes in response to events.
- **deactivate**: Unhook. Plugin data retained.
- **uninstall**: Remove plugin code and data.

### Plugin Manifest

```jsonc
{
  "name": "slack-notify",
  "label": "Slack Notifications",
  "version": "1.0.0",
  "author": "someone",
  "description": "Send Slack messages when tasks go overdue",
  "platforms": ["web", "ios"],           // which platforms this works on
  "entry": "index.js",                   // plugin code
  "settings": [                          // auto-rendered settings form
    { "key": "webhookUrl", "type": "string", "label": "Webhook URL" },
    { "key": "channel", "type": "string", "label": "Channel", "default": "#tasks" }
  ],
  "hooks": ["onTaskOverdue", "onTaskComplete"],  // which events it subscribes to
  "permissions": ["network"]              // what capabilities it needs
}
```

### Security Model

**Obsidian's approach:** Community plugins run with full access. Users are warned. A review process catches obvious malice but can't prevent all abuse. This works because the user base is technical.

**VSCode's approach:** Extensions run in a sandboxed extension host process. They declare permissions. Marketplace has a review process.

**Recommendation for FMN:** Start permissive (Obsidian model). The app is local-first with no sensitive data beyond task titles. If/when sync with auth tokens exists, tighten the sandbox.

---

## Implementation Priority

1. **Theme JSON import/export** — already done on web, needs polish on iOS
2. **Font picker on iOS** — done (system fonts via UIFont.familyNames)
3. **Font mapping table** — done (Google Font → system font fallback)
4. **Theme gallery endpoint** — low effort, high value
5. **Shortcuts / App Intents on iOS** — expose create/complete/reset as Shortcuts actions
6. **Plugin manifest format** — define the schema
7. **Web plugin loader** — ES module or script-tag based
8. **iOS JSC plugin runtime** — if demand warrants it

---

## Open Questions

- Should themes be able to override the urgency color thresholds (0.75 / 0.95), or is that behavior not presentation?
- Should plugins be able to add new task fields (custom metadata), or only react to existing data?
- Is a community gallery worth maintaining, or is JSON copy/paste + a GitHub repo sufficient?
- For iOS, is it worth bundling 3-5 popular Google Fonts (Fira Code, Inter, Playfair Display) to reduce the mapping gap? Licensing allows it for all of these.
