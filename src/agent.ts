// Agent API — a stable, documented surface on `window.fmn` so an AI agent can
// configure someone's tasks by CALLING things, instead of driving the UI by
// clicking pixels or poking at a minified bundle.
//
// Why it lives on `window` and not on a server: this app is deliberately
// serverless — everything is in the browser's localStorage, which is
// origin-scoped. Nothing outside the page can read it. But any agent that can
// run JavaScript on the page (Claude in Chrome, Playwright, computer-use,
// devtools) can call these. So the page hands out a real API instead.
//
// Security posture: this exposes nothing that a script on the page couldn't
// already do by reading localStorage directly — it's the same origin, same
// data, just curated and documented. It is NOT a remote API; there is no way
// to reach it from another origin.

import type { Task, Settings } from './types'
import {
  getTasks, getTask, createTask, updateTask, deleteTask,
  resetTask, completeTask, snoozeTask, restartCycle, addActionNote, archiveTask,
  getSettings, updateSettings, exportAll, importAll,
  getUrgencyRatio, getRemainingSeconds, getCycleHistory,
} from './store'
import { getAllThemes, applyTheme } from './themes'
import {
  getSetups, saveSetup, applySetup, captureSetup, parseSetupJson, setupToJson,
  getDefaultSetupId, setDefaultSetupId, type Setup,
} from './config'
import { refreshView } from './app'
import { parseDuration, humanize } from './duration'

const API_VERSION = 1

type Ok<T> = { ok: true } & T
type Err = { ok: false; error: string }
type Result<T> = Ok<T> | Err

const fail = (error: string): Err => ({ ok: false, error })

/**
 * Repaint whatever view is open so agent-driven changes show up immediately.
 * Deliberately does NOT navigate: if you're reading a task's detail page while
 * your agent edits it, you should stay there rather than being thrown home.
 */
function refresh(): void {
  try { refreshView() } catch { /* pre-boot calls are fine to ignore */ }
}


// --- finding a task ---------------------------------------------------------

/**
 * Agents refer to tasks the way people do — "tidy", not a UUID. Accepts an id,
 * an exact title (case-insensitive), or an unambiguous partial title. Ambiguity
 * is an error listing the candidates rather than a silent guess at which one.
 */
function resolve(idOrTitle: string): Task | { error: string } {
  const key = (idOrTitle ?? '').trim()
  if (!key) return { error: 'give a task id or title' }

  const all = getTasks()
  const byId = all.find((t) => t.id === key)
  if (byId) return byId

  const lower = key.toLowerCase()
  const exact = all.filter((t) => t.title.trim().toLowerCase() === lower)
  if (exact.length === 1) return exact[0]
  if (exact.length > 1) {
    return { error: `several tasks are called "${key}" — use an id: ${exact.map((t) => t.id).join(', ')}` }
  }

  const partial = all.filter((t) => t.title.toLowerCase().includes(lower))
  if (partial.length === 1) return partial[0]
  if (partial.length > 1) {
    return { error: `"${key}" matches ${partial.length} tasks: ${partial.map((t) => t.title).join(', ')}` }
  }
  return { error: `no task called "${key}" — fmn.listTasks() to see what's here` }
}

function isErr(r: Task | { error: string }): r is { error: string } {
  return (r as { error: string }).error !== undefined
}

// --- shaping ----------------------------------------------------------------

/** A task as an agent should see it: no internals, durations in plain words. */
function view(t: Task) {
  const remaining = getRemainingSeconds(t)
  return {
    id: t.id,
    title: t.title,
    description: t.description || undefined,
    category: t.domain || undefined,
    status: t.status,
    recurring: t.recurring,
    cadenceSeconds: t.baseCadenceSeconds ?? undefined,
    cadence: t.baseCadenceSeconds ? humanize(t.baseCadenceSeconds) : undefined,
    dueDate: t.dueDate ?? undefined,
    urgency: Math.round(getUrgencyRatio(t) * 100) / 100,
    overdue: getUrgencyRatio(t) >= 1,
    remainingSeconds: Number.isFinite(remaining) ? Math.round(remaining) : null,
    prompts: t.prompts?.length ? t.prompts : undefined,
    followUps: t.followUps?.length ? t.followUps : undefined,
    completions: t.actionLog.filter((e) => e.action === 'reset' || e.action === 'complete').length,
  }
}


// --- the API ----------------------------------------------------------------

export interface TaskInput {
  title: string
  /** "2h", "every 3 days", "daily", or a number of seconds. */
  cadence?: string | number
  cadenceSeconds?: number
  category?: string
  description?: string
  /** Nudges shown while the task is overdue. */
  prompts?: string[]
  /** Chain of steps that activate when this task is marked done. */
  followUps?: { title: string; cadence?: string | number; cadenceSeconds?: number; domain?: string }[]
  /** Omit for a repeating loop; pass a date for a one-off. */
  dueDate?: string
  recurring?: boolean
}

function buildTask(input: TaskInput): Result<{ task: ReturnType<typeof view> }> {
  if (!input?.title?.trim()) return fail('title is required')

  const seconds = input.cadenceSeconds ?? parseDuration(input.cadence)
  const recurring = input.recurring ?? (input.dueDate ? false : true)

  if (recurring && !seconds) {
    return fail('a repeating task needs a cadence, e.g. cadence: "2h" or "every 3 days"')
  }

  const followUps = (input.followUps ?? []).map((f) => ({
    title: f.title,
    cadenceSeconds: f.cadenceSeconds ?? parseDuration(f.cadence) ?? 3600,
    domain: f.domain,
  }))

  const task = createTask({
    title: input.title.trim(),
    description: input.description ?? '',
    domain: input.category ?? '',
    recurring,
    baseCadenceSeconds: recurring ? seconds : (seconds ?? null),
    dueDate: input.dueDate ?? null,
    prompts: input.prompts ?? [],
    followUps,
  })
  return { ok: true, task: view(task) }
}

export const agentApi = {
  version: API_VERSION,
  app: 'forget-me-not',

  /** Everything this API can do, as data — call it first to learn the surface. */
  help() {
    return {
      app: 'forget-me-not',
      version: API_VERSION,
      about:
        'Recurring-task tracker. Data lives in this browser (localStorage). ' +
        'Every method returns a JSON-serializable object; failures come back as ' +
        '{ok:false,error} instead of throwing.',
      tasksById:
        'Anywhere a task is named you can pass its id, its exact title, or an ' +
        'unambiguous part of the title — fmn.addPrompts("tidy", [...]) works.',
      prompts:
        'Prompts are the small nudges shown on a card once it goes overdue — one ' +
        'is picked at random. Keep them concrete and tiny: "sweep", "dust a shelf".',
      durations:
        'Anywhere a cadence is accepted you can write "90s", "15m", "2h", "3 days", ' +
        '"1h 30m", or "daily"/"weekly"/"hourly". Numbers are seconds.',
      methods: {
        'help()': 'this document',
        'listTasks({includeDone?, category?, overdueOnly?})': 'all tasks, most urgent first',
        'getTask(idOrTitle)': 'one task, with its history',
        'createTask({title, cadence, category?, description?, prompts?, followUps?})': 'add a task',
        'createTasks([...])': 'add many at once',
        'updateTask(idOrTitle, {title?, cadence?, category?, description?, prompts?})': 'edit a task',
        'addPrompts(idOrTitle, ["sweep", "dust a shelf"])': 'append nudges, keeping existing ones',
        'removePrompts(idOrTitle, [...]) / setPrompts(idOrTitle, [...])': 'drop or replace nudges',
        'deleteTask(id)': 'remove permanently',
        'completeTask(id, note?)': 'mark done (one-off) / restart the cycle (repeating), fires follow-ups',
        'snoozeTask(id)': 'quiet it briefly — jumps to 75% of the cycle',
        'restartTask(id)': 'restart the timer without completing it — no follow-ups fired',
        'addNote(id, note)': 'append a note to the task history',
        'archiveTask(id)': 'hide without deleting',
        'getSettings()': 'app name, categories, theme, sound',
        'updateSettings(patch)': 'change any of the above',
        'listThemes()': 'available theme names',
        'setTheme(name)': 'switch theme',
        'listSetups() / applySetup(idOrJson) / captureSetup(opts) / setDefaultSetup(id)':
          'shareable starter configurations',
        'exportData() / importData(json)': 'whole-dataset backup and restore',
      },
      examples: [
        'fmn.createTask({title: "stretch", cadence: "45m", category: "health"})',
        'fmn.listTasks({overdueOnly: true})',
        'fmn.createTask({title: "laundry", cadence: "3 days", followUps: [{title: "move to dryer", cadence: "45m"}]})',
        'fmn.addPrompts("tidy", ["sweep", "dust a shelf", "clear one surface"])',
        'fmn.setTheme("sakura")',
      ],
    }
  },

  // --- reading ---

  listTasks(opts: { includeDone?: boolean; category?: string; overdueOnly?: boolean } = {}) {
    let tasks = getTasks()
    if (!opts.includeDone) {
      tasks = tasks.filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')
    }
    if (opts.category) tasks = tasks.filter((t) => t.domain === opts.category)
    if (opts.overdueOnly) tasks = tasks.filter((t) => getUrgencyRatio(t) >= 1)
    tasks.sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))
    return { ok: true as const, count: tasks.length, tasks: tasks.map(view) }
  },

  getTask(idOrTitle: string) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    return {
      ok: true as const,
      task: view(t),
      history: t.actionLog.slice(-25).map((e) => ({ action: e.action, note: e.note || undefined, at: e.at })),
      cycles: getCycleHistory(t),
    }
  },

  // --- writing ---

  createTask(input: TaskInput) {
    const r = buildTask(input)
    if (r.ok) refresh()
    return r
  },

  createTasks(inputs: TaskInput[]) {
    if (!Array.isArray(inputs)) return fail('expected an array of tasks')
    const created: unknown[] = []
    const errors: unknown[] = []
    for (const i of inputs) {
      const r = buildTask(i)
      if (r.ok) created.push(r.task)
      else errors.push({ title: i?.title, error: r.error })
    }
    refresh()
    return { ok: true as const, created: created.length, tasks: created, errors }
  },

  updateTask(idOrTitle: string, patch: Partial<TaskInput>) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    const id = t.id
    const updates: Partial<Task> = {}
    if (patch.title !== undefined) updates.title = patch.title
    if (patch.description !== undefined) updates.description = patch.description
    if (patch.category !== undefined) updates.domain = patch.category
    if (patch.prompts !== undefined) updates.prompts = patch.prompts
    if (patch.dueDate !== undefined) updates.dueDate = patch.dueDate
    if (patch.cadence !== undefined || patch.cadenceSeconds !== undefined) {
      const secs = patch.cadenceSeconds ?? parseDuration(patch.cadence)
      if (!secs) return fail(`could not understand cadence: ${patch.cadence}`)
      updates.baseCadenceSeconds = secs
      // Re-arm the running cycle so the new cadence takes effect now, not next time.
      if (t.instance) updates.instance = { ...t.instance, actualCadenceSeconds: secs }
    }
    const out = updateTask(id, updates)
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail('update failed')
  },

  deleteTask(idOrTitle: string) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    const id = t.id
    deleteTask(id)
    refresh()
    return { ok: true as const, deleted: id }
  },

  completeTask(idOrTitle: string, note = '') {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    const id = t.id
    const out = t.recurring ? resetTask(id, note) : completeTask(id, note)
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail('could not complete')
  },

  snoozeTask(idOrTitle: string) {
    const found = resolve(idOrTitle)
    if (isErr(found)) return fail(found.error)
    const id = found.id
    const out = snoozeTask(id)
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail(`could not snooze ${id}`)
  },

  restartTask(idOrTitle: string) {
    const found = resolve(idOrTitle)
    if (isErr(found)) return fail(found.error)
    const id = found.id
    const out = restartCycle(id)
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail(`could not restart ${id}`)
  },

  addNote(idOrTitle: string, note: string) {
    if (!note?.trim()) return fail('note is empty')
    const found = resolve(idOrTitle)
    if (isErr(found)) return fail(found.error)
    const id = found.id
    const out = addActionNote(id, note.trim())
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail(`no task with id ${id}`)
  },

  archiveTask(idOrTitle: string) {
    const found = resolve(idOrTitle)
    if (isErr(found)) return fail(found.error)
    const id = found.id
    const out = archiveTask(id)
    refresh()
    return out ? { ok: true as const, task: view(out) } : fail(`no task with id ${id}`)
  },


  // --- prompts (the little nudges shown while a task is overdue) ---

  /**
   * Append nudges to a task, keeping what's already there. This exists because
   * "add a few more" is the common ask, and updateTask({prompts}) replaces the
   * whole list — an agent would otherwise have to read-merge-write and could
   * clobber prompts it never saw.
   */
  addPrompts(idOrTitle: string, prompts: string[] | string) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    const incoming = (Array.isArray(prompts) ? prompts : [prompts])
      .map((p) => String(p).trim())
      .filter(Boolean)
    if (!incoming.length) return fail('no prompts given')

    const existing = t.prompts ?? []
    const seen = new Set(existing.map((p) => p.toLowerCase()))
    const added = incoming.filter((p) => !seen.has(p.toLowerCase()))
    const out = updateTask(t.id, { prompts: [...existing, ...added] })
    refresh()
    return out
      ? { ok: true as const, added: added.length, skipped: incoming.length - added.length, prompts: out.prompts, task: view(out) }
      : fail('could not add prompts')
  },

  /** Drop nudges by exact text (case-insensitive). */
  removePrompts(idOrTitle: string, prompts: string[] | string) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    const drop = new Set((Array.isArray(prompts) ? prompts : [prompts]).map((p) => String(p).trim().toLowerCase()))
    const kept = (t.prompts ?? []).filter((p) => !drop.has(p.toLowerCase()))
    const out = updateTask(t.id, { prompts: kept })
    refresh()
    return out
      ? { ok: true as const, removed: (t.prompts?.length ?? 0) - kept.length, prompts: out.prompts }
      : fail('could not remove prompts')
  },

  /** Replace the whole nudge list. */
  setPrompts(idOrTitle: string, prompts: string[]) {
    const t = resolve(idOrTitle)
    if (isErr(t)) return fail(t.error)
    if (!Array.isArray(prompts)) return fail('prompts must be an array')
    const out = updateTask(t.id, { prompts: prompts.map((p) => String(p).trim()).filter(Boolean) })
    refresh()
    return out ? { ok: true as const, prompts: out.prompts } : fail('could not set prompts')
  },

  // --- configuration ---

  getSettings() {
    const s = getSettings()
    return {
      ok: true as const,
      settings: {
        appName: s.appName,
        categories: s.domains,
        theme: s.themePreset,
        sound: { enabled: s.soundEnabled, seed: s.soundSeed, preset: s.soundPreset, bpm: s.soundBpm, volume: s.soundVolume, mood: s.soundMode },
      },
    }
  },

  updateSettings(patch: Partial<Settings> & { categories?: string[]; theme?: string }) {
    const mapped: Partial<Settings> = { ...patch }
    if (patch.categories) mapped.domains = patch.categories
    if (patch.theme) mapped.themePreset = patch.theme
    delete (mapped as Record<string, unknown>).categories
    delete (mapped as Record<string, unknown>).theme
    const s = updateSettings(mapped)
    applyTheme(s)
    refresh()
    return { ok: true as const, settings: s }
  },

  listThemes() {
    return { ok: true as const, themes: getAllThemes(getSettings()).map((t) => ({ name: t.name, label: t.label })) }
  },

  setTheme(name: string) {
    const found = getAllThemes(getSettings()).find((t) => t.name === name)
    if (!found) return fail(`no theme "${name}" — try fmn.listThemes()`)
    applyTheme(updateSettings({ themePreset: name }))
    refresh()
    return { ok: true as const, theme: name }
  },

  // --- setups (shareable starter configurations) ---

  listSetups() {
    const def = getDefaultSetupId()
    return {
      ok: true as const,
      setups: getSetups().map((s) => ({
        id: s.id, name: s.name, description: s.description || undefined,
        isDefault: s.id === def,
        includes: {
          theme: !!s.theme, sound: !!s.sound,
          naming: s.appName !== undefined || !!s.domains,
          tasks: s.tasks?.length ?? 0,
        },
      })),
    }
  },

  applySetup(idOrJson: string) {
    let setup: Setup | null = getSetups().find((s) => s.id === idOrJson) ?? null
    if (!setup) setup = parseSetupJson(idOrJson)
    if (!setup) return fail('not a known setup id, and not valid setup JSON')
    const r = applySetup(setup)
    refresh()
    return { ok: true as const, applied: r }
  },

  captureSetup(opts: { name: string; description?: string; includeTheme?: boolean; includeSound?: boolean; includeNaming?: boolean; tasks?: 'all' | 'none' }) {
    if (!opts?.name) return fail('name is required')
    const setup = captureSetup({
      name: opts.name,
      description: opts.description,
      includeTheme: opts.includeTheme ?? true,
      includeSound: opts.includeSound ?? true,
      includeNaming: opts.includeNaming ?? true,
      taskIds: opts.tasks === 'none' ? 'none' : 'all',
    })
    saveSetup(setup)
    refresh()
    return { ok: true as const, setup: { id: setup.id, name: setup.name }, json: setupToJson(setup) }
  },

  setDefaultSetup(id: string | null) {
    if (id && !getSetups().some((s) => s.id === id)) return fail(`no setup with id ${id}`)
    setDefaultSetupId(id)
    return { ok: true as const, defaultSetup: id }
  },

  // --- whole dataset ---

  exportData() {
    return { ok: true as const, json: exportAll() }
  },

  importData(json: string) {
    try {
      const r = importAll(json)
      refresh()
      return { ok: true as const, imported: r }
    } catch (e) {
      return fail(`import failed: ${String(e)}`)
    }
  },
}

/** Attach the API and leave a breadcrumb an agent can find. */
export function installAgentApi(): void {
  ;(window as unknown as Record<string, unknown>).fmn = agentApi

  // Discovery: an agent that lands on the page and reads the DOM or console
  // learns the API exists without anyone telling it.
  const meta = document.createElement('meta')
  meta.name = 'ai-agent-api'
  meta.content = `window.fmn v${API_VERSION} — call fmn.help() for the full surface`
  document.head.appendChild(meta)

  console.info(
    '%cforget me not%c — agent API available: call %cfmn.help()%c for what it can do.',
    'font-weight:bold', '', 'font-family:monospace', '',
  )
}
