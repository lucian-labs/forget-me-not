import type { Task } from './types'
import {
  getTasks, getUrgencyRatio, getUrgencyColor, getUrgencyClass,
  resetTask, completeTask, snoozeTask, archiveTask,
} from './store'
import { formatTime, formatCadence, el } from './utils'
import { playAlert, clearAlert } from './sounds'
import { navigate } from './app'

type CaptureState = { taskId: string; timer: number | null }

let capture: CaptureState | null = null

export function renderPanel(container: HTMLElement): void {
  const tasks = getTasks().filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')
  const recurring = tasks.filter((t) => t.recurring).sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))
  const oneTime = tasks.filter((t) => !t.recurring).sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))

  container.innerHTML = ''

  // Header
  const header = el('div', { className: 'fmn-header' },
    el('h1', {}, 'forget me not'),
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

  // Recurring section
  if (recurring.length > 0) {
    container.appendChild(el('div', { className: 'fmn-section' }, 'Recurring'))
    for (const task of recurring) {
      container.appendChild(renderTaskItem(task, true))
    }
  }

  // One-time section
  if (oneTime.length > 0) {
    container.appendChild(el('div', { className: 'fmn-section' }, 'Tasks'))
    for (const task of oneTime) {
      container.appendChild(renderTaskItem(task, false))
    }
  }
}

function renderTaskItem(task: Task, isRecurring: boolean): HTMLElement {
  const ratio = getUrgencyRatio(task)
  const color = getUrgencyColor(ratio)
  const urgencyClass = getUrgencyClass(ratio)
  const isOverdue = ratio >= 1.0

  // Alert handling
  if (isOverdue) {
    playAlert(task.id)
  } else {
    clearAlert(task.id)
  }

  const card = el('div', { className: `fmn-card fmn-task ${urgencyClass}` })

  const row = el('div', { className: 'fmn-task-row' })

  // Check button
  const checkBtn = createBtn('\u2713', 'btn-icon', () => startCapture(task, card, isRecurring))
  row.appendChild(checkBtn)

  // Title
  const titleEl = el('span', { className: 'fmn-task-title' }, task.title)
  titleEl.onclick = () => navigate('detail', task.id)
  row.appendChild(titleEl)

  // Domain badge
  if (task.domain) {
    row.appendChild(el('span', { className: 'fmn-task-domain' }, task.domain))
  }

  // Priority badge (one-time only)
  if (!isRecurring && task.priority !== 'normal') {
    row.appendChild(el('span', { className: `fmn-badge fmn-badge-${task.priority}` }, task.priority))
  }

  // Recurring badge
  if (isRecurring) {
    row.appendChild(el('span', { className: 'fmn-badge fmn-badge-recurring' }, '\u21BB'))
  }

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
    if (remaining > 0) {
      metaParts.push(`${formatTime(remaining)} left`)
    } else {
      metaParts.push(`${formatTime(Math.abs(remaining))} over`)
    }
    metaParts.push(`every ${formatCadence(task.cadenceSeconds)}`)
  } else if (task.dueDate) {
    const remaining = (new Date(task.dueDate).getTime() - Date.now()) / 1000
    if (remaining > 0) {
      metaParts.push(`${formatTime(remaining)} left`)
    } else {
      metaParts.push(`${formatTime(Math.abs(remaining))} over`)
    }
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

  // Quick capture (if active for this task)
  if (capture && capture.taskId === task.id) {
    const input = el('input', {
      className: 'fmn-capture',
      type: 'text',
      placeholder: 'quick note (auto-submits in 1.5s)...',
    }) as HTMLInputElement
    card.appendChild(input)
    requestAnimationFrame(() => input.focus())

    input.addEventListener('input', () => resetCaptureTimer(task, input, isRecurring))
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') executeCapture(task, input.value, isRecurring)
      if (e.key === 'Escape') { capture = null; navigate('panel') }
    })

    startCaptureTimer(task, input, isRecurring)
  }

  return card
}

function startCapture(task: Task, _card: HTMLElement, _isRecurring: boolean): void {
  capture = { taskId: task.id, timer: null }
  navigate('panel')
}

function startCaptureTimer(task: Task, input: HTMLInputElement, isRecurring: boolean): void {
  if (capture) {
    if (capture.timer) clearTimeout(capture.timer)
    capture.timer = window.setTimeout(() => {
      executeCapture(task, input.value, isRecurring)
    }, 1500)
  }
}

function resetCaptureTimer(task: Task, input: HTMLInputElement, isRecurring: boolean): void {
  if (capture) {
    if (capture.timer) clearTimeout(capture.timer)
    capture.timer = window.setTimeout(() => {
      executeCapture(task, input.value, isRecurring)
    }, 1500)
  }
}

function executeCapture(task: Task, note: string, isRecurring: boolean): void {
  if (capture?.timer) clearTimeout(capture.timer)
  capture = null
  if (isRecurring) {
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
