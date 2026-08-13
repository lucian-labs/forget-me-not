// Setups — shareable bundles of "how the app should start out": the look, the
// sounds, the categories, and a set of starter loops. The admin panel (admin.ts)
// composes them; a setup travels as a link, a QR code, or JSON.
//
// A setup is NOT a data backup (that's Share -> Send to device, which moves your
// actual task history). Applying a setup layers a configuration on top: it never
// deletes what you already have.

import type { Task, ThemeStyle, Settings } from './types'
import { getTasks, getSettings, updateSettings, createTask } from './store'
import { getTheme } from './themes'

export interface SetupTask {
  title: string
  domain: string
  description?: string
  recurring: boolean
  baseCadenceSeconds: number | null
  prompts: string[]
  followUps?: { title: string; cadenceSeconds: number; domain?: string }[]
}

export interface SetupSound {
  enabled: boolean
  seed: string
  preset: number
  bpm: number
  volume: number
  mode: number
}

export interface Setup {
  version: 1
  id: string
  name: string
  description: string
  createdAt: string
  /** Everything below is optional — a setup includes only the parts you chose. */
  theme?: ThemeStyle
  sound?: SetupSound
  appName?: string
  domains?: string[]
  tasks?: SetupTask[]
}

const STORE_KEY = 'fmn-setups'
const DEFAULT_KEY = 'fmn-default-setup'

// --- storage ---

export function getSetups(): Setup[] {
  try {
    const raw = localStorage.getItem(STORE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export function saveSetup(setup: Setup): void {
  const all = getSetups().filter((s) => s.id !== setup.id)
  all.push(setup)
  localStorage.setItem(STORE_KEY, JSON.stringify(all))
}

export function deleteSetup(id: string): void {
  localStorage.setItem(STORE_KEY, JSON.stringify(getSetups().filter((s) => s.id !== id)))
  if (getDefaultSetupId() === id) setDefaultSetupId(null)
}

/** The setup a brand-new install starts from (instead of the built-in starter loops). */
export function getDefaultSetupId(): string | null {
  return localStorage.getItem(DEFAULT_KEY)
}

export function setDefaultSetupId(id: string | null): void {
  if (id) localStorage.setItem(DEFAULT_KEY, id)
  else localStorage.removeItem(DEFAULT_KEY)
}

export function getDefaultSetup(): Setup | null {
  const id = getDefaultSetupId()
  if (!id) return null
  return getSetups().find((s) => s.id === id) ?? null
}

// --- composing ---

/** Snapshot the current app state into a setup, including only the chosen parts. */
export function captureSetup(opts: {
  name: string
  description?: string
  includeTheme: boolean
  includeSound: boolean
  includeNaming: boolean
  taskIds: string[] | 'all' | 'none'
  id?: string
}): Setup {
  const settings = getSettings()
  const setup: Setup = {
    version: 1,
    id: opts.id ?? crypto.randomUUID(),
    name: opts.name.trim() || 'Untitled setup',
    description: (opts.description ?? '').trim(),
    createdAt: new Date().toISOString(),
  }

  if (opts.includeTheme) {
    // Resolve to a full theme so the recipient gets the exact look, even if it's
    // a custom one they don't have — including any per-field customizations.
    const base = getTheme(settings.themePreset, settings)
    setup.theme = {
      ...base,
      colors: { ...base.colors, ...settings.customColors },
      borderRadius: settings.customBorderRadius ?? base.borderRadius,
      fontSize: settings.customFontSize ?? base.fontSize,
      headerFont: settings.customHeaderFont ?? base.headerFont,
      bodyFont: settings.customBodyFont ?? base.bodyFont,
      spacing: (settings.customSpacing as ThemeStyle['spacing']) ?? base.spacing,
    }
  }

  if (opts.includeSound) {
    setup.sound = {
      enabled: settings.soundEnabled,
      seed: settings.soundSeed,
      preset: settings.soundPreset,
      bpm: settings.soundBpm,
      volume: settings.soundVolume,
      mode: settings.soundMode,
    }
  }

  if (opts.includeNaming) {
    setup.appName = settings.appName
    setup.domains = [...settings.domains]
  }

  if (opts.taskIds !== 'none') {
    const all = getTasks().filter((t) => t.status !== 'archived' && t.status !== 'cancelled')
    const chosen = opts.taskIds === 'all' ? all : all.filter((t) => opts.taskIds.includes(t.id))
    setup.tasks = chosen.map(toSetupTask)
  }

  return setup
}

function toSetupTask(t: Task): SetupTask {
  return {
    title: t.title,
    domain: t.domain,
    description: t.description || undefined,
    recurring: t.recurring,
    baseCadenceSeconds: t.baseCadenceSeconds,
    prompts: [...t.prompts],
    followUps: t.followUps.length ? t.followUps.map((f) => ({ ...f })) : undefined,
  }
}

// --- applying ---

export interface ApplyResult {
  tasks: number
  theme: boolean
  sound: boolean
  naming: boolean
}

/**
 * Layer a setup onto this install. Adds its loops (skipping ones you already have
 * by title, so re-applying doesn't duplicate) and applies whichever settings it
 * carries. Never deletes existing tasks.
 */
export function applySetup(setup: Setup): ApplyResult {
  const patch: Partial<Settings> = {}
  const result: ApplyResult = { tasks: 0, theme: false, sound: false, naming: false }

  if (setup.theme) {
    const settings = getSettings()
    const incoming = setup.theme
    // Store as a user theme so it survives and shows in the picker.
    const userThemes = (settings.userThemes ?? []).filter((t) => t.name !== incoming.name)
    userThemes.push(incoming)
    patch.userThemes = userThemes
    patch.themePreset = incoming.name
    // Clear per-field overrides — the setup's theme IS the look now.
    patch.customColors = {}
    patch.customBorderRadius = null
    patch.customFontSize = null
    patch.customHeaderFont = null
    patch.customBodyFont = null
    patch.customSpacing = null
    result.theme = true
  }

  if (setup.sound) {
    patch.soundEnabled = setup.sound.enabled
    patch.soundSeed = setup.sound.seed
    patch.soundPreset = setup.sound.preset
    patch.soundBpm = setup.sound.bpm
    patch.soundVolume = setup.sound.volume
    patch.soundMode = setup.sound.mode
    result.sound = true
  }

  if (setup.appName !== undefined || setup.domains) {
    if (setup.appName !== undefined) patch.appName = setup.appName
    if (setup.domains) {
      // Union, so a setup adds categories without dropping the user's own.
      const existing = getSettings().domains ?? []
      patch.domains = [...new Set([...existing, ...setup.domains])]
    }
    result.naming = true
  }

  if (Object.keys(patch).length) updateSettings(patch)

  if (setup.tasks?.length) {
    const have = new Set(getTasks().map((t) => t.title.trim().toLowerCase()))
    for (const st of setup.tasks) {
      if (have.has(st.title.trim().toLowerCase())) continue
      createTask({
        title: st.title,
        domain: st.domain,
        description: st.description ?? '',
        recurring: st.recurring,
        baseCadenceSeconds: st.baseCadenceSeconds,
        prompts: st.prompts ?? [],
        followUps: st.followUps ?? [],
      })
      result.tasks++
    }
  }

  return result
}

// --- transport ---

export function setupToJson(setup: Setup): string {
  return JSON.stringify(setup, null, 2)
}

/** Parse a setup from JSON, tolerating a pasted link. Returns null if it isn't one. */
export function parseSetupJson(text: string): Setup | null {
  try {
    const parsed = JSON.parse(text.trim())
    if (!parsed || typeof parsed !== 'object') return null
    if (!parsed.name && !parsed.tasks && !parsed.theme && !parsed.sound) return null
    return {
      version: 1,
      id: parsed.id || crypto.randomUUID(),
      name: parsed.name || 'Imported setup',
      description: parsed.description || '',
      createdAt: parsed.createdAt || new Date().toISOString(),
      theme: parsed.theme,
      sound: parsed.sound,
      appName: parsed.appName,
      domains: parsed.domains,
      tasks: parsed.tasks,
    }
  } catch {
    return null
  }
}
