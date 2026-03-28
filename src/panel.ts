import type { Task } from './types'
import {
  getTasks, getUrgencyRatio, getUrgencyColor, getUrgencyClass,
  resetTask, completeTask, snoozeTask, archiveTask, addActionNote,
} from './store'
import { formatTime, formatCadence, el } from './utils'
import { playAlert, clearAlert } from './sounds'
import { navigate } from './app'

type CaptureState = { taskId: string; timer: number | null; mode: 'check' | 'note' }

let capture: CaptureState | null = null
let groupByCategory = false

export function renderPanel(container: HTMLElement): void {
  const tasks = getTasks().filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')

  container.innerHTML = ''

  // Header
  const title = el('h1', { className: 'fmn-header-title' }, 'forget me not')
  title.onclick = () => navigate('panel')
  const header = el('div', { className: 'fmn-header' },
    title,
    el('div', { className: 'fmn-header-actions' },
      createBtn('+', 'btn-accent', () => navigate('create')),
      createBtn('\u2699', 'btn-icon', () => navigate('settings')),
    ),
  )
  container.appendChild(header)

  if (tasks.length === 0) {
    container.appendChild(el('div', { className: 'fmn-empty' }, 'No tasks yet. Hit + to create one.'))
    return
  }

  // Group by category toggle
  const toggleRow = el('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:12px;' })
  const toggleLabel = el('label', { className: 'fmn-toggle' })
  const toggleInput = el('input', { type: 'checkbox' }) as HTMLInputElement
  toggleInput.checked = groupByCategory
  toggleInput.onchange = () => { groupByCategory = toggleInput.checked; navigate('panel') }
  toggleLabel.appendChild(toggleInput)
  toggleLabel.appendChild(el('span', { className: 'fmn-toggle-track' }))
  toggleLabel.appendChild(el('span', { className: 'fmn-toggle-thumb' }))
  toggleRow.appendChild(toggleLabel)
  toggleRow.appendChild(el('span', { style: 'font-size:12px;color:var(--dim);' }, 'group by category'))
  container.appendChild(toggleRow)

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

  if (isOverdue) playAlert(task.id)
  else clearAlert(task.id)

  const card = el('div', { className: `fmn-card fmn-task ${urgencyClass}` })
  const row = el('div', { className: 'fmn-task-row' })

  // Check button — always opens capture input first
  const checkBtn = createBtn('\u2713', 'btn-icon', () => startCapture(task))
  row.appendChild(checkBtn)

  // Title
  const titleEl = el('span', { className: 'fmn-task-title' }, task.title)
  titleEl.onclick = () => navigate('detail', task.id)
  row.appendChild(titleEl)

  // Priority badge (one-time only)
  if (!isRecurring && task.priority !== 'normal') {
    row.appendChild(el('span', { className: `fmn-badge fmn-badge-${task.priority}` }, task.priority))
  }

  // Quick note button
  row.appendChild(createBtn('\u270E', 'btn-icon btn-sm', () => startNote(task)))

  // Snooze (recurring) or delete (one-time)
  if (isRecurring) {
    row.appendChild(createBtn('zz', 'btn-icon btn-sm', () => { snoozeTask(task.id); navigate('panel') }))
  } else {
    row.appendChild(createBtn('\u00D7', 'btn-icon btn-sm', () => { archiveTask(task.id); navigate('panel') }))
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
    const randomPrompt = task.prompts[Math.floor(Math.random() * task.prompts.length)]
    card.appendChild(el('div', { className: 'fmn-prompt' }, `? ${randomPrompt}`))
  }

  // Quick capture (recurring check or note mode)
  if (capture && capture.taskId === task.id) {
    const input = el('input', {
      className: 'fmn-capture',
      type: 'text',
      placeholder: capture.mode === 'note' ? 'what did you do?' : 'quick note (auto-submits in 1.5s)...',
    }) as HTMLInputElement
    card.appendChild(input)
    requestAnimationFrame(() => input.focus())

    if (capture.mode === 'note') {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && input.value.trim()) {
          addActionNote(task.id, input.value.trim())
          capture = null
          navigate('panel')
        }
        if (e.key === 'Escape') { capture = null; navigate('panel') }
      })
    } else {
      input.addEventListener('input', () => resetCaptureTimer(task, input))
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') executeCapture(task, input.value)
        if (e.key === 'Escape') { capture = null; navigate('panel') }
      })
      startCaptureTimer(task, input)
    }
  }

  return card
}

function startCapture(task: Task): void {
  capture = { taskId: task.id, timer: null, mode: 'check' }
  navigate('panel')
}

function startNote(task: Task): void {
  capture = { taskId: task.id, timer: null, mode: 'note' }
  navigate('panel')
}

function startCaptureTimer(task: Task, input: HTMLInputElement): void {
  if (capture) {
    if (capture.timer) clearTimeout(capture.timer)
    capture.timer = window.setTimeout(() => executeCapture(task, input.value), 1500)
  }
}

function resetCaptureTimer(task: Task, input: HTMLInputElement): void {
  if (capture) {
    if (capture.timer) clearTimeout(capture.timer)
    capture.timer = window.setTimeout(() => executeCapture(task, input.value), 1500)
  }
}

function executeCapture(task: Task, note: string): void {
  if (capture?.timer) clearTimeout(capture.timer)
  capture = null
  if (task.recurring) {
    resetTask(task.id, note)
  } else {
    completeTask(task.id, note)
  }
  navigate('panel')
}

function createBtn(text: string, className: string, onClick: () => void): HTMLButtonElement {
  const btn = el('button', { className }, text) as HTMLButtonElement
  btn.addEventListener('click', (e) => { e.stopPropagation(); onClick() })
  return btn
}
