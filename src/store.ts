import type { Task, Settings, FollowUp } from './types'

const TASKS_KEY = 'fmn-tasks'
const SETTINGS_KEY = 'fmn-settings'

const DEFAULT_SETTINGS: Settings = {
  soundEnabled: true,
  soundSeed: 'forgetmenot',
  soundPreset: 0,
  soundBpm: 160,
  soundVolume: 0.4,
  soundMode: 1,
  appName: '',
  domains: ['home', 'work', 'health', 'errands'],
  themePreset: 'midnight',
  customColors: {},
  customBorderRadius: null,
  customFontSize: null,
  customHeaderFont: null,
  customBodyFont: null,
  customSpacing: null,
  userThemes: [],
  fullWidth: true,
  panelCollapsed: false,
  syncEndpoint: '',
  syncApiKey: '',
  syncEnabled: false,
}

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

function write<T>(key: string, value: T): void {
  localStorage.setItem(key, JSON.stringify(value))
}

// --- Tasks ---

export function getTasks(): Task[] {
  return read<Task[]>(TASKS_KEY, [])
}

function saveTasks(tasks: Task[]): void {
  write(TASKS_KEY, tasks)
}

export function getTask(id: string): Task | undefined {
  return getTasks().find((t) => t.id === id)
}

export function createTask(partial: Partial<Task> & { title: string }): Task {
  const now = new Date().toISOString()
  const task: Task = {
    id: crypto.randomUUID(),
    title: partial.title,
    description: partial.description ?? '',
    domain: partial.domain ?? '',
    tags: partial.tags ?? [],
    status: partial.status ?? 'open',
    priority: partial.priority ?? 'normal',
    createdAt: now,
    updatedAt: now,
    dueDate: partial.dueDate ?? null,
    startedAt: partial.startedAt ?? (partial.dueDate ? now : null),
    completedAt: null,
    estimatedHours: partial.estimatedHours ?? null,
    recurring: partial.recurring ?? false,
    cadenceSeconds: partial.cadenceSeconds ?? null,
    cadenceMore: partial.cadenceMore ?? null,
    cadenceLess: partial.cadenceLess ?? null,
    lastResetAt: partial.recurring ? now : null,
    followUps: partial.followUps ?? [],
    parentTaskId: partial.parentTaskId ?? null,
    prompts: partial.prompts ?? [],
    actionLog: [],
  }
  const tasks = getTasks()
  tasks.push(task)
  saveTasks(tasks)
  return task
}

export function updateTask(id: string, updates: Partial<Task>): Task | undefined {
  const tasks = getTasks()
  const idx = tasks.findIndex((t) => t.id === id)
  if (idx === -1) return undefined
  tasks[idx] = { ...tasks[idx], ...updates, updatedAt: new Date().toISOString() }
  saveTasks(tasks)
  return tasks[idx]
}

export function deleteTask(id: string): void {
  saveTasks(getTasks().filter((t) => t.id !== id))
}

export function resetTask(id: string, note: string): Task | undefined {
  const task = getTask(id)
  if (!task) return undefined
  const now = new Date().toISOString()
  const entry = { note, at: now, action: 'reset' as const }
  // Randomize cadence within range on reset
  let newCadence = task.cadenceSeconds
  if (task.cadenceSeconds && (task.cadenceMore || task.cadenceLess)) {
    const base = task.cadenceSeconds
    const less = task.cadenceLess ?? 0
    const more = task.cadenceMore ?? 0
    const min = base - less
    const max = base + more
    newCadence = Math.round(min + Math.random() * (max - min))
  }

  const updates: Partial<Task> = {
    lastResetAt: now,
    cadenceSeconds: newCadence,
    actionLog: [...task.actionLog, entry],
  }
  const updated = updateTask(id, updates)
  if (updated && updated.followUps.length > 0) {
    spawnFollowUp(updated)
  }
  return updated
}

export function completeTask(id: string, note: string): Task | undefined {
  const task = getTask(id)
  if (!task) return undefined
  const now = new Date().toISOString()
  const entry = { note, at: now, action: 'complete' as const }
  const updates: Partial<Task> = {
    status: 'done',
    completedAt: now,
    actionLog: [...task.actionLog, entry],
  }
  const updated = updateTask(id, updates)
  if (updated && updated.followUps.length > 0) {
    spawnFollowUp(updated)
  }
  return updated
}

export function snoozeTask(id: string): Task | undefined {
  const task = getTask(id)
  if (!task || !task.cadenceSeconds) return undefined
  const snoozeTime = new Date(Date.now() - task.cadenceSeconds * 750).toISOString()
  return updateTask(id, { lastResetAt: snoozeTime })
}

export function archiveTask(id: string): Task | undefined {
  return updateTask(id, { status: 'archived' })
}

function spawnFollowUp(parent: Task): void {
  const first: FollowUp = parent.followUps[0]
  const remaining = parent.followUps.slice(1)
  const now = Date.now()
  createTask({
    title: first.title,
    domain: first.domain ?? parent.domain,
    dueDate: new Date(now + first.cadenceSeconds * 1000).toISOString(),
    startedAt: new Date().toISOString(),
    followUps: remaining,
    parentTaskId: parent.id,
    tags: parent.tags,
  })
}

export function addActionNote(id: string, note: string): Task | undefined {
  const task = getTask(id)
  if (!task) return undefined
  const entry = { note, at: new Date().toISOString(), action: 'note' as const }
  return updateTask(id, { actionLog: [...task.actionLog, entry] })
}

// --- Settings ---

export function getSettings(): Settings {
  return { ...DEFAULT_SETTINGS, ...read<Partial<Settings>>(SETTINGS_KEY, {}) }
}

export function updateSettings(updates: Partial<Settings>): Settings {
  const settings = { ...getSettings(), ...updates }
  write(SETTINGS_KEY, settings)
  return settings
}

// --- Export / Import ---

export function exportAll(): string {
  return JSON.stringify({
    tasks: getTasks(),
    settings: getSettings(),
    exportedAt: new Date().toISOString(),
    version: 1,
  }, null, 2)
}

export function exportTasks(): string {
  return JSON.stringify({
    tasks: getTasks(),
    exportedAt: new Date().toISOString(),
    version: 1,
  }, null, 2)
}

export function isFirstRun(): boolean {
  return localStorage.getItem(SETTINGS_KEY) === null
}

export function importAll(json: string): { tasks: number } {
  const data = JSON.parse(json)
  if (data.tasks && Array.isArray(data.tasks)) {
    saveTasks(data.tasks)
  }
  if (data.settings) {
    write(SETTINGS_KEY, { ...getSettings(), ...data.settings })
  }
  return { tasks: data.tasks?.length ?? 0 }
}

export function clearAll(): void {
  localStorage.removeItem(TASKS_KEY)
  localStorage.removeItem(SETTINGS_KEY)
}

// --- Urgency ---

export function getUrgencyRatio(task: Task): number {
  const now = Date.now()
  if (task.recurring && task.lastResetAt && task.cadenceSeconds) {
    const elapsed = now - new Date(task.lastResetAt).getTime()
    return elapsed / (task.cadenceSeconds * 1000)
  }
  if (task.dueDate && task.startedAt) {
    const start = new Date(task.startedAt).getTime()
    const due = new Date(task.dueDate).getTime()
    const total = due - start
    if (total <= 0) return 1
    return (now - start) / total
  }
  return 0
}

/** Seconds remaining until due/overdue. Negative = overdue. Infinity = no deadline. */
export function getRemainingSeconds(task: Task): number {
  const now = Date.now()
  if (task.recurring && task.lastResetAt && task.cadenceSeconds) {
    const elapsed = (now - new Date(task.lastResetAt).getTime()) / 1000
    return task.cadenceSeconds - elapsed
  }
  if (task.dueDate) {
    return (new Date(task.dueDate).getTime() - now) / 1000
  }
  return Infinity
}

export function getUrgencyColor(ratio: number): string {
  if (ratio < 0.75) return 'var(--green)'
  if (ratio < 0.95) return 'var(--orange)'
  return 'var(--red)'
}

export function getUrgencyClass(ratio: number): string {
  if (ratio >= 1.0) return 'fmn-overdue'
  return ''
}
