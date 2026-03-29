import type { Task } from './types'
import {
  getTasks, getSettings, updateSettings, getUrgencyRatio, getUrgencyColor, getUrgencyClass,
  resetTask, completeTask, snoozeTask, archiveTask, addActionNote,
} from './store'
import { formatTime, formatCadence, el } from './utils'
import { playAlert, clearAlert } from './sounds'
import { navigate } from './app'
import { animateOut } from './animate'
import { appName } from './brand'

type CaptureState = { timer: number | null; mode: 'check' | 'note'; card: HTMLElement | null }

const captures = new Map<string, CaptureState>()
let groupByCategory = localStorage.getItem('fmn-categorize') === 'true'
const promptCache = new Map<string, { text: string; at: number }>()

export function renderPanel(container: HTMLElement): void {
  const tasks = getTasks().filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')

  container.innerHTML = ''

  const title = el('h1', { className: 'fmn-header-title' }, appName())
  title.onclick = () => navigate('panel')

  const catToggle = el('label', { className: 'fmn-toggle', style: 'margin:0;' })
  const catInput = el('input', { type: 'checkbox' }) as HTMLInputElement
  catInput.checked = groupByCategory
  catInput.onchange = () => { groupByCategory = catInput.checked; localStorage.setItem('fmn-categorize', String(catInput.checked)); navigate('panel') }
  catToggle.appendChild(catInput)
  catToggle.appendChild(el('span', { className: 'fmn-toggle-track' }))
  catToggle.appendChild(el('span', { className: 'fmn-toggle-thumb' }))

  const catWrap = el('div', { style: 'display:flex;align-items:center;gap:5px;' })
  catWrap.appendChild(catToggle)
  catWrap.appendChild(el('span', { style: 'font-size:11px;color:var(--dim);' }, 'categorize'))

  // Sound toggle
  const settings = getSettings()
  const sndToggle = el('label', { className: 'fmn-toggle', style: 'margin:0;' })
  const sndInput = el('input', { type: 'checkbox' }) as HTMLInputElement
  sndInput.checked = settings.soundEnabled
  sndInput.onchange = () => { updateSettings({ soundEnabled: sndInput.checked }); navigate('panel') }
  sndToggle.appendChild(sndInput)
  sndToggle.appendChild(el('span', { className: 'fmn-toggle-track' }))
  sndToggle.appendChild(el('span', { className: 'fmn-toggle-thumb' }))

  const sndWrap = el('div', { style: 'display:flex;align-items:center;gap:5px;' })
  sndWrap.appendChild(sndToggle)
  sndWrap.appendChild(el('span', { style: 'font-size:11px;color:var(--dim);' }, 'sounds'))

  const titleWrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
  titleWrap.appendChild(title)
  titleWrap.appendChild(createBtn('+', 'btn-accent btn-sm', () => navigate('create')))

  const header = el('div', { className: 'fmn-header' },
    titleWrap,
    el('div', { className: 'fmn-header-actions' },
      catWrap,
      sndWrap,
      createBtn('*', 'btn-ghost btn-sm', () => navigate('settings')),
    ),
  )
  container.appendChild(header)

  if (tasks.length === 0) {
    container.appendChild(el('div', { className: 'fmn-empty' }, 'No tasks yet. Hit + to create one.'))
    return
  }

  if (groupByCategory) {
    renderGroupedByCategory(container, tasks)
  } else {
    renderByType(container, tasks)
  }
}

function renderByType(container: HTMLElement, tasks: Task[]): void {
  const recurring = tasks.filter((t) => t.recurring).sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))
  const oneTime = tasks.filter((t) => !t.recurring).sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))

  if (recurring.length > 0) {
    container.appendChild(el('div', { className: 'fmn-section' }, 'Recurring'))
    for (const task of recurring) container.appendChild(renderTaskItem(task))
  }

  if (oneTime.length > 0) {
    container.appendChild(el('div', { className: 'fmn-section' }, 'Tasks'))
    for (const task of oneTime) container.appendChild(renderTaskItem(task))
  }
}

function renderGroupedByCategory(container: HTMLElement, tasks: Task[]): void {
  const groups = new Map<string, Task[]>()
  for (const t of tasks) {
    const cat = t.domain || 'uncategorized'
    if (!groups.has(cat)) groups.set(cat, [])
    groups.get(cat)!.push(t)
  }
  for (const [cat, catTasks] of groups) {
    container.appendChild(el('div', { className: 'fmn-section' }, cat))
    const sorted = catTasks.sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))
    for (const task of sorted) container.appendChild(renderTaskItem(task))
  }
}

function renderTaskItem(task: Task): HTMLElement {
  const ratio = getUrgencyRatio(task)
  const color = getUrgencyColor(ratio)
  const urgencyClass = getUrgencyClass(ratio)
  const isOverdue = ratio >= 1.0
  const isRecurring = task.recurring
  const cap = captures.get(task.id)

  if (isOverdue) playAlert(task.id)
  else clearAlert(task.id)

  const card = el('div', { className: `fmn-card fmn-task ${urgencyClass}` })
  const row = el('div', { className: 'fmn-task-row' })

  const checkBtn = createBtn('\u2713', 'btn-icon', () => startCapture(task.id, 'check'))
  row.appendChild(checkBtn)

  const titleEl = el('span', { className: 'fmn-task-title' }, task.title)
  titleEl.onclick = () => navigate('detail', task.id)
  row.appendChild(titleEl)

  if (!isRecurring && task.priority !== 'normal') {
    row.appendChild(el('span', { className: `fmn-badge fmn-badge-${task.priority}` }, task.priority))
  }

  row.appendChild(createBtn('\u270E', 'btn-icon btn-sm', () => startCapture(task.id, 'note')))

  if (isRecurring) {
    row.appendChild(createBtn('zz', 'btn-icon btn-sm', () => {
      animateOut(card).then(() => { snoozeTask(task.id); navigate('panel') })
    }))
  } else {
    row.appendChild(createBtn('\u00D7', 'btn-icon btn-sm', () => {
      animateOut(card).then(() => { archiveTask(task.id); navigate('panel') })
    }))
  }

  card.appendChild(row)

  // Meta line
  const metaParts: string[] = []
  if (isRecurring && task.cadenceSeconds && task.lastResetAt) {
    const elapsed = (Date.now() - new Date(task.lastResetAt).getTime()) / 1000
    const remaining = task.cadenceSeconds - elapsed
    if (remaining > 0) metaParts.push(`${formatTime(remaining)} left`)
    else metaParts.push(`${formatTime(Math.abs(remaining))} over`)
    metaParts.push(`every ${formatCadence(task.cadenceSeconds)}`)
  } else if (task.dueDate) {
    const remaining = (new Date(task.dueDate).getTime() - Date.now()) / 1000
    if (remaining > 0) metaParts.push(`${formatTime(remaining)} left`)
    else metaParts.push(`${formatTime(Math.abs(remaining))} over`)
  }
  if (metaParts.length > 0) {
    card.appendChild(el('div', { className: 'fmn-task-meta' }, metaParts.join(' \u00B7 ')))
  }

  // Progress bar
  const progress = el('div', { className: 'fmn-progress' })
  const fill = el('div', { className: 'fmn-progress-fill' })
  fill.style.width = `${Math.min(ratio * 100, 100)}%`
  fill.style.background = color
  progress.appendChild(fill)
  card.appendChild(progress)

  // Overdue prompt
  if (isOverdue && task.prompts.length > 0) {
    const now = Date.now()
    const cached = promptCache.get(task.id)
    if (!cached || now - cached.at > 10000) {
      promptCache.set(task.id, { text: task.prompts[Math.floor(Math.random() * task.prompts.length)], at: now })
    }
    card.appendChild(el('div', { className: 'fmn-prompt' }, `? ${promptCache.get(task.id)!.text}`))
  }

  // Capture input (each task has its own independent lifecycle)
  if (cap) {
    cap.card = card
    const input = el('input', {
      className: 'fmn-capture',
      type: 'text',
      placeholder: cap.mode === 'note' ? 'what did you do?' : 'quick note (auto-submits in 2s)...',
    }) as HTMLInputElement
    card.appendChild(input)
    requestAnimationFrame(() => input.focus())

    if (cap.mode === 'note') {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && input.value.trim()) {
          addActionNote(task.id, input.value.trim())
          captures.delete(task.id)
          navigate('panel')
        }
        if (e.key === 'Escape') { captures.delete(task.id); navigate('panel') }
      })
    } else {
      input.addEventListener('input', () => resetCaptureTimer(task, input))
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') executeCapture(task, input.value)
        if (e.key === 'Escape') { captures.delete(task.id); navigate('panel') }
      })
      startCaptureTimer(task, input)
    }
  }

  return card
}

function startCapture(taskId: string, mode: 'check' | 'note'): void {
  // Toggle off if already open in same mode
  const existing = captures.get(taskId)
  if (existing && existing.mode === mode) {
    if (existing.timer) clearTimeout(existing.timer)
    captures.delete(taskId)
  } else {
    if (existing?.timer) clearTimeout(existing.timer)
    captures.set(taskId, { timer: null, mode, card: null })
  }
  navigate('panel')
}

function startCaptureTimer(task: Task, input: HTMLInputElement): void {
  const cap = captures.get(task.id)
  if (cap) {
    if (cap.timer) clearTimeout(cap.timer)
    cap.timer = window.setTimeout(() => executeCapture(task, input.value), 2000)
  }
}

function resetCaptureTimer(task: Task, input: HTMLInputElement): void {
  const cap = captures.get(task.id)
  if (cap) {
    if (cap.timer) clearTimeout(cap.timer)
    cap.timer = window.setTimeout(() => executeCapture(task, input.value), 2000)
  }
}

function executeCapture(task: Task, note: string): void {
  const cap = captures.get(task.id)
  if (cap?.timer) clearTimeout(cap.timer)
  const cardEl = cap?.card
  captures.delete(task.id)

  const finish = () => {
    if (task.recurring) {
      resetTask(task.id, note)
    } else {
      completeTask(task.id, note)
    }
    navigate('panel')
  }

  if (cardEl) {
    animateOut(cardEl).then(finish)
  } else {
    finish()
  }
}

function createBtn(text: string, className: string, onClick: () => void): HTMLButtonElement {
  const btn = el('button', { className }, text) as HTMLButtonElement
  btn.addEventListener('click', (e) => { e.stopPropagation(); onClick() })
  return btn
}
