import { el, formatTime, formatCadence, timeAgo } from './utils'
import { navigate } from './app'

/**
 * Loops playground.
 *
 * A loop is a user-configurable, skill-growing recurrence — "do 10 pushups",
 * "make a $1 sale", "read 5 pages", etc. Intentionally separate from the
 * task/reminder system: loops are about long-term reps and streaks, not
 * one-shot notifications.
 *
 * Schema and UX here are deliberately minimal so we can iterate fast.
 */

export type LoopCategory = 'mental' | 'physical' | 'money' | 'creative' | 'social' | 'other'

export interface Loop {
  id: string
  name: string
  category: LoopCategory
  cadenceSeconds: number
  description: string
  completions: string[] // ISO timestamps, oldest-first
  createdAt: string
}

const STORAGE_KEY = 'fmn-loops'

const CATEGORY_META: Record<LoopCategory, { label: string; color: string }> = {
  mental: { label: 'mental', color: '#a78bfa' },
  physical: { label: 'physical', color: '#f87171' },
  money: { label: 'money', color: '#34d399' },
  creative: { label: 'creative', color: '#fbbf24' },
  social: { label: 'social', color: '#60a5fa' },
  other: { label: 'other', color: '#9ca3af' },
}

const CADENCE_PRESETS: { label: string; seconds: number }[] = [
  { label: '1h', seconds: 3600 },
  { label: '4h', seconds: 14400 },
  { label: 'daily', seconds: 86400 },
  { label: '2d', seconds: 172800 },
  { label: 'weekly', seconds: 604800 },
]

function loadLoops(): Loop[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as Loop[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

function saveLoops(loops: Loop[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(loops))
}

function newId(): string {
  return 'loop-' + Math.random().toString(36).slice(2, 10)
}

function lastCompletion(loop: Loop): Date | null {
  if (loop.completions.length === 0) return null
  return new Date(loop.completions[loop.completions.length - 1])
}

function secondsUntilDue(loop: Loop): number {
  const last = lastCompletion(loop)
  if (!last) return 0 // never done → due now
  const nextAt = last.getTime() + loop.cadenceSeconds * 1000
  return Math.round((nextAt - Date.now()) / 1000)
}

/**
 * Current streak: consecutive completions where each gap <= 1.5x cadence.
 * A skipped cycle breaks the streak.
 */
function streak(loop: Loop): number {
  if (loop.completions.length === 0) return 0
  const tolerance = loop.cadenceSeconds * 1500 // 1.5x in ms
  let count = 1
  for (let i = loop.completions.length - 1; i > 0; i--) {
    const gap = new Date(loop.completions[i]).getTime() - new Date(loop.completions[i - 1]).getTime()
    if (gap <= tolerance) count++
    else break
  }
  return count
}

export function renderLoops(container: HTMLElement): void {
  container.innerHTML = ''

  const loops = loadLoops()

  // Header
  const backBtn = el('button', { className: 'btn-ghost btn-sm', style: 'margin-right:8px;' }, '←')
  backBtn.onclick = () => navigate('panel')

  const title = el('h1', { className: 'fmn-header-title' }, 'loops')

  const addBtn = el('button', { className: 'btn-accent btn-sm' }, '+ new loop')
  addBtn.onclick = () => toggleForm(container, loops)

  const header = el('div', { className: 'fmn-header' },
    el('div', { style: 'display:flex;align-items:center;gap:8px;' }, backBtn, title),
    el('div', { className: 'fmn-header-actions' }, addBtn),
  )
  container.appendChild(header)

  // Inline create form slot
  const formSlot = el('div', { className: 'fmn-loops-form-slot' })
  container.appendChild(formSlot)

  // List
  const list = el('div', { className: 'fmn-loops-list', style: 'display:flex;flex-direction:column;gap:8px;margin-top:12px;' })
  container.appendChild(list)

  if (loops.length === 0) {
    list.appendChild(el('div', { className: 'fmn-empty' },
      'No loops yet. Hit "+ new loop" to add one. Loops are recurring micro-habits you want to build.'))
    return
  }

  // Sort: overdue first, then by time-until-due ascending
  const sorted = [...loops].sort((a, b) => secondsUntilDue(a) - secondsUntilDue(b))
  for (const loop of sorted) list.appendChild(renderLoopCard(loop))
}

function renderLoopCard(loop: Loop): HTMLElement {
  const meta = CATEGORY_META[loop.category] ?? CATEGORY_META.other
  const due = secondsUntilDue(loop)
  const last = lastCompletion(loop)
  const s = streak(loop)

  const card = el('div', {
    className: 'fmn-loop-card',
    style: 'border:1px solid var(--border);border-radius:10px;padding:12px;background:var(--surface);display:flex;flex-direction:column;gap:6px;',
  })

  const titleRow = el('div', { style: 'display:flex;align-items:center;gap:8px;justify-content:space-between;' })
  const nameAndPill = el('div', { style: 'display:flex;align-items:center;gap:8px;flex:1;min-width:0;' })
  const name = el('span', { style: 'font-weight:600;font-size:15px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;' }, loop.name)
  const pill = el('span', {
    style: `font-size:10px;padding:2px 8px;border-radius:999px;background:${meta.color}22;color:${meta.color};border:1px solid ${meta.color}44;`,
  }, meta.label)
  nameAndPill.appendChild(name)
  nameAndPill.appendChild(pill)

  const delBtn = el('button', { className: 'btn-ghost btn-sm', title: 'delete loop', style: 'opacity:0.5;' }, '×')
  delBtn.onclick = () => {
    if (!confirm(`Delete loop "${loop.name}"?`)) return
    const all = loadLoops().filter((l) => l.id !== loop.id)
    saveLoops(all)
    navigate('loops')
  }

  titleRow.appendChild(nameAndPill)
  titleRow.appendChild(delBtn)

  if (loop.description) {
    card.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);' }, loop.description))
  }

  const statsRow = el('div', { style: 'display:flex;gap:14px;font-size:11px;color:var(--dim);flex-wrap:wrap;' })
  statsRow.appendChild(el('span', {}, `every ${formatCadence(loop.cadenceSeconds)}`))
  statsRow.appendChild(el('span', {}, `streak: ${s}`))
  statsRow.appendChild(el('span', {}, `done: ${loop.completions.length}`))
  statsRow.appendChild(el('span', {}, last ? `last: ${timeAgo(last.toISOString())}` : 'never done'))

  const dueText = due <= 0
    ? el('span', { style: 'color:var(--red);font-weight:600;' }, due <= -3600 ? `overdue ${formatTime(-due)}` : 'due now')
    : el('span', { style: 'color:var(--dim);' }, `due in ${formatTime(due)}`)

  const actionRow = el('div', { style: 'display:flex;align-items:center;gap:8px;margin-top:4px;' })
  const doneBtn = el('button', { className: 'btn-accent btn-sm' }, '\u2713 did it')
  doneBtn.onclick = () => {
    const all = loadLoops()
    const target = all.find((l) => l.id === loop.id)
    if (!target) return
    target.completions.push(new Date().toISOString())
    saveLoops(all)
    navigate('loops')
  }
  actionRow.appendChild(doneBtn)
  actionRow.appendChild(dueText)

  card.appendChild(titleRow)
  if (loop.description) {
    // already appended above
  }
  card.appendChild(statsRow)
  card.appendChild(actionRow)

  return card
}

function toggleForm(container: HTMLElement, _loops: Loop[]): void {
  const slot = container.querySelector('.fmn-loops-form-slot') as HTMLElement
  if (!slot) return
  if (slot.firstChild) {
    slot.innerHTML = ''
    return
  }

  const nameInput = el('input', { type: 'text', placeholder: 'loop name (e.g. "10 pushups")', className: 'fmn-input' }) as HTMLInputElement
  const descInput = el('input', { type: 'text', placeholder: 'optional description', className: 'fmn-input' }) as HTMLInputElement

  const catSelect = el('select', { className: 'fmn-input' }) as HTMLSelectElement
  for (const key of Object.keys(CATEGORY_META) as LoopCategory[]) {
    const opt = el('option', { value: key }, CATEGORY_META[key].label)
    catSelect.appendChild(opt)
  }

  const cadSelect = el('select', { className: 'fmn-input' }) as HTMLSelectElement
  for (const preset of CADENCE_PRESETS) {
    const opt = el('option', { value: String(preset.seconds) }, preset.label)
    cadSelect.appendChild(opt)
  }
  cadSelect.value = '86400'

  const row = (...kids: HTMLElement[]) =>
    el('div', { style: 'display:flex;gap:8px;' }, ...kids)

  const saveBtn = el('button', { className: 'btn-accent btn-sm' }, 'save')
  saveBtn.onclick = () => {
    const name = nameInput.value.trim()
    if (!name) {
      nameInput.focus()
      return
    }
    const loop: Loop = {
      id: newId(),
      name,
      description: descInput.value.trim(),
      category: catSelect.value as LoopCategory,
      cadenceSeconds: parseInt(cadSelect.value, 10) || 86400,
      completions: [],
      createdAt: new Date().toISOString(),
    }
    const all = loadLoops()
    all.push(loop)
    saveLoops(all)
    navigate('loops')
  }

  const cancelBtn = el('button', { className: 'btn-ghost btn-sm' }, 'cancel')
  cancelBtn.onclick = () => { slot.innerHTML = '' }

  const form = el('div', {
    style: 'border:1px solid var(--border);border-radius:10px;padding:12px;margin-top:12px;display:flex;flex-direction:column;gap:8px;background:var(--surface);',
  },
    nameInput,
    descInput,
    row(catSelect, cadSelect),
    row(saveBtn, cancelBtn),
  )

  slot.appendChild(form)
  nameInput.focus()
}
