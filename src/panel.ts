import type { Task } from './types'
import {
  getTasks, getSettings, updateSettings, getUrgencyRatio, getUrgencyColor, getUrgencyClass,
  getRemainingSeconds, resetTask, completeTask, snoozeTask, archiveTask, addActionNote,
} from './store'
import { formatTime, formatCadence, el } from './utils'
import { navigate } from './app'
import { animateOut } from './animate'
import { appName } from './brand'
import { renderHeaderIcon } from './icon'

type CaptureState = { timer: number | null; mode: 'check' | 'note'; card: HTMLElement | null; startedAt: number }

const captures = new Map<string, CaptureState>()
let groupByCategory = localStorage.getItem('fmn-categorize') === 'true'
let sortByTime = localStorage.getItem('fmn-sort') !== 'pct'
const promptCache = new Map<string, { text: string; at: number }>()
let catWrap: HTMLElement
const prevOverdue = new Set<string>()

export function renderPanel(container: HTMLElement): void {
  const allTasks = getTasks()
  const tasks = allTasks.filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')

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

  catWrap = el('div', { style: 'display:flex;align-items:center;' })
  catToggle.style.transform = 'scale(0.75)'
  catToggle.style.transformOrigin = 'left center'
  catWrap.appendChild(catToggle)

  // Sound toggle
  const settings = getSettings()
  const sndToggle = el('label', { className: 'fmn-toggle', style: 'margin:0;' })
  const sndInput = el('input', { type: 'checkbox' }) as HTMLInputElement
  sndInput.checked = settings.soundEnabled
  sndInput.onchange = () => { updateSettings({ soundEnabled: sndInput.checked }); navigate('panel') }
  sndToggle.appendChild(sndInput)
  sndToggle.appendChild(el('span', { className: 'fmn-toggle-track' }))
  sndToggle.appendChild(el('span', { className: 'fmn-toggle-thumb' }))

  const sndWrap = el('div', { style: 'display:flex;align-items:center;gap:4px;' })
  sndWrap.appendChild(el('span', { style: 'font-size:11px;color:var(--dim);' }, '\u266B'))
  sndWrap.appendChild(sndToggle)

  // Sort toggle
  const sortToggle = el('label', { className: 'fmn-toggle', style: 'margin:0;' })
  const sortInput = el('input', { type: 'checkbox' }) as HTMLInputElement
  sortInput.checked = !sortByTime
  sortInput.onchange = () => {
    sortByTime = !sortInput.checked
    localStorage.setItem('fmn-sort', sortByTime ? 'time' : 'pct')
    // Pick a random animation
    const anims = ['sortFlip', 'sortBounce', 'sortSpin', 'sortPop', 'sortWobble']
    const pick = anims[Math.floor(Math.random() * anims.length)]
    sortIcon.style.setProperty('--sort-anim', pick)
    sortIcon.classList.remove('fmn-sort-animate')
    void sortIcon.offsetWidth // force reflow
    sortIcon.textContent = sortByTime ? '\u29D7' : '\u2630'
    sortIcon.classList.add('fmn-sort-animate')
    navigate('panel')
  }
  sortToggle.appendChild(sortInput)
  sortToggle.appendChild(el('span', { className: 'fmn-toggle-track' }))
  sortToggle.appendChild(el('span', { className: 'fmn-toggle-thumb' }))

  const sortIcon = el('span', { className: 'fmn-sort-icon', style: 'font-size:11px;color:var(--dim);display:inline-block;' }, sortByTime ? '\u29D7' : '\u2630')

  const sortWrap = el('div', { style: 'display:flex;align-items:center;gap:4px;' })
  sortWrap.appendChild(sortIcon)
  sortWrap.appendChild(sortToggle)

  const titleWrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
  titleWrap.appendChild(renderHeaderIcon())
  titleWrap.appendChild(title)
  titleWrap.appendChild(createBtn('+', 'btn-accent btn-sm', () => navigate('create')))

  const header = el('div', { className: 'fmn-header' },
    titleWrap,
    el('div', { className: 'fmn-header-actions' },
      sortWrap,
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

function sectionWithToggle(label: string, toggleEl: HTMLElement): HTMLElement {
  const row = el('div', { className: 'fmn-section', style: 'display:flex;align-items:center;justify-content:space-between;' })
  row.appendChild(document.createTextNode(label))
  row.appendChild(toggleEl)
  return row
}

function sortTasks(tasks: Task[]): Task[] {
  if (sortByTime) return [...tasks].sort((a, b) => getRemainingSeconds(a) - getRemainingSeconds(b))
  return [...tasks].sort((a, b) => getUrgencyRatio(b) - getUrgencyRatio(a))
}

function renderByType(container: HTMLElement, tasks: Task[]): void {
  const sorted = sortTasks(tasks)
  container.appendChild(sectionWithToggle('Reminders', catWrap))
  for (const task of sorted) container.appendChild(renderTaskItem(task))
}

function renderGroupedByCategory(container: HTMLElement, tasks: Task[]): void {
  const groups = new Map<string, Task[]>()
  for (const t of tasks) {
    const cat = t.domain || 'uncategorized'
    if (!groups.has(cat)) groups.set(cat, [])
    groups.get(cat)!.push(t)
  }
  let first = true
  for (const [cat, catTasks] of groups) {
    container.appendChild(first ? sectionWithToggle(cat, catWrap) : el('div', { className: 'fmn-section' }, cat))
    first = false
    const sorted = sortTasks(catTasks)
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

  const card = el('div', { className: `fmn-card fmn-task ${urgencyClass}` })
  card.dataset.taskId = task.id
  const row = el('div', { className: 'fmn-task-row' })

  const checkBtn = createBtn('\u2713', 'btn-icon', () => startCapture(task.id, 'check'))
  row.appendChild(checkBtn)

  if (isRecurring) {
    row.appendChild(createBtn('zz', 'btn-icon btn-sm', () => {
      animateOut(card).then(() => { snoozeTask(task.id); navigate('panel') })
    }))
  } else {
    row.appendChild(createBtn('\u00D7', 'btn-icon btn-sm', () => {
      animateOut(card).then(() => { archiveTask(task.id); navigate('panel') })
    }))
  }

  const titleEl = el('span', { className: 'fmn-task-title' }, task.title)
  titleEl.onclick = () => navigate('detail', task.id)
  row.appendChild(titleEl)

  // Overdue prompt — inline next to title
  if (isOverdue && task.prompts.length > 0) {
    const now = Date.now()
    const cached = promptCache.get(task.id)
    if (!cached || now - cached.at > 10000) {
      promptCache.set(task.id, { text: task.prompts[Math.floor(Math.random() * task.prompts.length)], at: now })
    }
    row.appendChild(el('span', { className: 'fmn-prompt' }, `? ${promptCache.get(task.id)!.text}`))
  }

  if (!isRecurring && task.priority !== 'normal') {
    row.appendChild(el('span', { className: `fmn-badge fmn-badge-${task.priority}` }, task.priority))
  }

  // Meta line — right-aligned in the row (hidden in bar/percentage mode)
  if (sortByTime) {
    let metaText = ''
    let metaOverdue = false
    if (isRecurring && task.instance) {
      const elapsed = (Date.now() - new Date(task.instance.startedAt).getTime()) / 1000
      const remaining = task.instance.actualCadenceSeconds - elapsed
      if (remaining > 0) metaText = `${formatTime(remaining)} left`
      else { metaText = `${formatTime(Math.abs(remaining))} over`; metaOverdue = true }
    } else if (isRecurring && !task.instance) {
      metaText = 'paused'
    } else if (task.dueDate) {
      const remaining = (new Date(task.dueDate).getTime() - Date.now()) / 1000
      if (remaining > 0) metaText = `${formatTime(remaining)} left`
      else { metaText = `${formatTime(Math.abs(remaining))} over`; metaOverdue = true }
    }
    if (metaText) {
      const meta = el('span', { className: 'fmn-task-meta' })
      if (metaOverdue) {
        meta.appendChild(el('span', { style: 'color:var(--red);font-weight:700;margin-right:3px;' }, '!'))
      }
      meta.appendChild(document.createTextNode(metaText))
      row.appendChild(meta)
    }
  }

  card.appendChild(row)

  // Progress bar — hidden in clock mode via height transition
  const progress = el('div', { className: `fmn-progress${sortByTime ? ' fmn-progress-hidden' : ''}` })
  const fill = el('div', { className: 'fmn-progress-fill' })
  fill.style.width = sortByTime ? '0%' : `${Math.min(ratio * 100, 100)}%`
  fill.style.background = color
  progress.appendChild(fill)
  card.appendChild(progress)


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
    captures.set(taskId, { timer: null, mode, card: null, startedAt: Date.now() })
  }
  navigate('panel')
}

function startCaptureTimer(task: Task, input: HTMLInputElement): void {
  const cap = captures.get(task.id)
  if (cap) {
    if (cap.timer) clearTimeout(cap.timer)
    const elapsed = Date.now() - cap.startedAt
    const remaining = Math.max(2000 - elapsed, 0)
    cap.timer = window.setTimeout(() => executeCapture(task, input.value), remaining)
  }
}

function resetCaptureTimer(task: Task, input: HTMLInputElement): void {
  const cap = captures.get(task.id)
  if (cap) {
    if (cap.timer) clearTimeout(cap.timer)
    cap.startedAt = Date.now()
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

/** Update only dynamic time-based content in existing cards — no DOM rebuild.
 *  Returns true if a full rebuild is needed (task count changed or new overdue). */
export function updatePanelTimers(container: HTMLElement): boolean {
  const tasks = getTasks().filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')
  const taskMap = new Map(tasks.map((t) => [t.id, t]))

  const cards = container.querySelectorAll<HTMLElement>('.fmn-card[data-task-id]')

  // Task count changed — need structural rebuild
  if (cards.length === 0 || cards.length !== tasks.length) return true

  let needsRebuild = false

  for (const card of cards) {
    const task = taskMap.get(card.dataset.taskId!)
    if (!task) { needsRebuild = true; continue }

    const ratio = getUrgencyRatio(task)
    const color = getUrgencyColor(ratio)
    const urgencyClass = getUrgencyClass(ratio)
    const isOverdue = ratio >= 1.0

    // New overdue transition — trigger full rebuild for re-sort + structural changes
    if (isOverdue && !prevOverdue.has(task.id)) {
      prevOverdue.add(task.id)
      needsRebuild = true
    } else if (!isOverdue) {
      prevOverdue.delete(task.id)
    }

    // Update urgency class
    card.classList.toggle('fmn-overdue', urgencyClass === 'fmn-overdue')

    // Update meta line
    const metaEl = card.querySelector('.fmn-task-meta')
    if (metaEl) {
      let metaText = ''
      let metaOverdue = false
      if (task.recurring && task.instance) {
        const elapsed = (Date.now() - new Date(task.instance.startedAt).getTime()) / 1000
        const remaining = task.instance.actualCadenceSeconds - elapsed
        if (remaining > 0) metaText = `${formatTime(remaining)} left`
        else { metaText = `${formatTime(Math.abs(remaining))} over`; metaOverdue = true }
      } else if (task.recurring && !task.instance) {
        metaText = 'paused'
      } else if (task.dueDate) {
        const remaining = (new Date(task.dueDate).getTime() - Date.now()) / 1000
        if (remaining > 0) metaText = `${formatTime(remaining)} left`
        else { metaText = `${formatTime(Math.abs(remaining))} over`; metaOverdue = true }
      }
      metaEl.innerHTML = ''
      if (metaOverdue) metaEl.appendChild(el('span', { style: 'color:var(--red);font-weight:700;margin-right:3px;' }, '!'))
      metaEl.appendChild(document.createTextNode(metaText))
    }

    // Update progress bar
    const progressEl = card.querySelector<HTMLElement>('.fmn-progress')
    if (progressEl) progressEl.classList.toggle('fmn-progress-hidden', sortByTime)
    const fill = card.querySelector<HTMLElement>('.fmn-progress-fill')
    if (fill) {
      fill.style.width = sortByTime ? '0%' : `${Math.min(ratio * 100, 100)}%`
      fill.style.background = color
    }

    // Update overdue prompt (lives in the task row, next to title)
    const row = card.querySelector('.fmn-task-row')
    const existingPrompt = row?.querySelector('.fmn-prompt')
    if (isOverdue && task.prompts.length > 0) {
      const now = Date.now()
      const cached = promptCache.get(task.id)
      if (!cached || now - cached.at > 10000) {
        promptCache.set(task.id, { text: task.prompts[Math.floor(Math.random() * task.prompts.length)], at: now })
      }
      const promptText = `? ${promptCache.get(task.id)!.text}`
      if (existingPrompt) {
        existingPrompt.textContent = promptText
      } else if (row) {
        const titleEl = row.querySelector('.fmn-task-title')
        const promptEl = el('span', { className: 'fmn-prompt' }, promptText)
        if (titleEl?.nextSibling) row.insertBefore(promptEl, titleEl.nextSibling)
        else row.appendChild(promptEl)
      }
    } else if (existingPrompt) {
      existingPrompt.remove()
    }
  }

  return needsRebuild
}
