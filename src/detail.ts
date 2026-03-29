import type { Task, TaskStatus, TaskPriority } from './types'
import {
  getTask, getTasks, updateTask, resetTask, completeTask, archiveTask,
  getUrgencyRatio, getUrgencyColor, addActionNote, getSettings,
} from './store'
import { el, timeAgo, formatCadence, formatTime, CADENCE_OPTIONS } from './utils'
import { navigate } from './app'
import { appName } from './brand'

export function renderDetail(container: HTMLElement, taskId: string): void {
  const task = getTask(taskId)
  if (!task) {
    container.innerHTML = ''
    const title = el('h1', { className: 'fmn-header-title' }, appName())
    title.onclick = () => navigate('panel')
    container.appendChild(el('div', { className: 'fmn-header' }, title))
    container.appendChild(el('div', { className: 'fmn-empty' }, 'Task not found.'))
    return
  }

  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, appName())
  headerTitle.onclick = () => navigate('panel')
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle))

  const card = el('div', { className: 'fmn-card' })

  // Title row — title + category inline
  const titleRow = el('div', { style: 'display:flex;align-items:baseline;gap:10px;margin-bottom:12px;' })

  const titleDisplay = el('h2', { style: 'font-size:20px;font-weight:600;color:var(--accent);cursor:text;font-family:var(--font-header);flex:1;' }, task.title)
  const titleInput = el('input', { type: 'text', value: task.title, style: 'display:none;font-size:20px;font-weight:600;color:var(--accent);background:var(--bg);border:1px solid var(--accent);border-radius:var(--radius);padding:4px 8px;flex:1;font-family:var(--font-header);' }) as HTMLInputElement

  titleDisplay.onclick = () => {
    titleDisplay.style.display = 'none'
    titleInput.style.display = 'block'
    titleInput.focus()
    titleInput.select()
  }
  titleInput.onblur = () => {
    titleDisplay.style.display = 'block'
    titleInput.style.display = 'none'
    if (titleInput.value.trim() && titleInput.value !== task.title) {
      updateTask(task.id, { title: titleInput.value.trim() })
      titleDisplay.textContent = titleInput.value.trim()
    }
  }
  titleInput.onkeydown = (e) => { if (e.key === 'Enter') titleInput.blur() }

  titleRow.appendChild(titleDisplay)
  titleRow.appendChild(titleInput)

  if (task.domain) {
    titleRow.appendChild(el('span', { style: 'font-size:11px;color:var(--cyan);white-space:nowrap;' }, task.domain))
  }

  card.appendChild(titleRow)

  // Badges row
  const badgeRow = el('div', { style: 'display:flex;align-items:center;gap:8px;margin-bottom:12px;flex-wrap:wrap;' })

  if (task.recurring) {
    badgeRow.appendChild(el('span', { className: 'fmn-badge fmn-badge-recurring' }, 'recurring'))
    if (task.cadenceSeconds) {
      badgeRow.appendChild(el('span', { style: 'font-size:12px;color:var(--dim);' }, `every ${formatCadence(task.cadenceSeconds)}`))
    }
    if (task.lastResetAt && task.cadenceSeconds) {
      const ratio = getUrgencyRatio(task)
      const elapsed = (Date.now() - new Date(task.lastResetAt).getTime()) / 1000
      const remaining = task.cadenceSeconds - elapsed
      const urgencyText = remaining > 0 ? `${formatTime(remaining)} left` : `${formatTime(Math.abs(remaining))} over`
      const urgencyEl = el('span', { style: `font-size:12px;font-weight:600;color:${getUrgencyColor(ratio)};` }, urgencyText)
      badgeRow.appendChild(urgencyEl)
    }
  } else {
    // Status select
    const statusSelect = el('select', { className: 'fmn-status-select' }) as HTMLSelectElement
    const statuses: TaskStatus[] = ['open', 'in_progress', 'blocked', 'done', 'cancelled']
    for (const s of statuses) {
      const opt = el('option', { value: s }, s.replace('_', ' '))
      if (s === task.status) opt.selected = true
      statusSelect.appendChild(opt)
    }
    statusSelect.onchange = () => {
      updateTask(task.id, { status: statusSelect.value as TaskStatus })
      navigate('detail', task.id)
    }
    badgeRow.appendChild(statusSelect)
  }

  card.appendChild(badgeRow)

  // Description
  const descSection = el('div', { className: 'fmn-detail-section' })
  descSection.appendChild(el('h3', {}, 'Description'))
  const descArea = el('textarea', { placeholder: 'Add a description...' }) as HTMLTextAreaElement
  descArea.value = task.description
  descArea.onblur = () => { if (descArea.value !== task.description) updateTask(task.id, { description: descArea.value }) }
  descSection.appendChild(descArea)
  card.appendChild(descSection)

  // Decision prompts
  renderPrompts(card, task)

  // Follow-up chain
  renderFollowUps(card, task)

  // Actions
  const actionsSection = el('div', { className: 'fmn-detail-section' })
  const actionRow = el('div', { className: 'fmn-form-row' })

  if (task.recurring) {
    actionRow.appendChild(createActionBtn('Reset', 'btn-accent', () => {
      resetTask(task.id, '')
      navigate('panel')
    }))
  }
  actionRow.appendChild(createActionBtn('Complete', 'btn-ghost', () => {
    completeTask(task.id, '')
    navigate('panel')
  }))
  actionRow.appendChild(createActionBtn('Archive', 'btn-danger', () => {
    archiveTask(task.id)
    navigate('panel')
  }))

  actionsSection.appendChild(actionRow)
  card.appendChild(actionsSection)

  // More — collapsible details
  const moreWrap = el('div', { style: 'margin-top:4px;' })
  const moreTrigger = el('button', { className: 'fmn-back', style: 'margin-bottom:0;font-size:12px;' }, '\u25B8 More')
  const moreContent = el('div', { style: 'display:none;margin-top:8px;' })
  let moreOpen = false

  moreTrigger.onclick = () => {
    moreOpen = !moreOpen
    moreContent.style.display = moreOpen ? 'block' : 'none'
    moreTrigger.textContent = moreOpen ? '\u25BE More' : '\u25B8 More'
  }

  const moreGrid = el('div', { className: 'fmn-detail-grid' })

  // Category dropdown
  const settings = getSettings()
  const catSelect = el('select', { style: 'width:auto;font-size:13px;' }) as HTMLSelectElement
  catSelect.appendChild(el('option', { value: '' }, '\u2014'))
  for (const d of settings.domains) {
    const opt = el('option', { value: d }, d)
    if (d === task.domain) opt.selected = true
    catSelect.appendChild(opt)
  }
  catSelect.onchange = () => {
    updateTask(task.id, { domain: catSelect.value })
    navigate('detail', task.id)
  }
  moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Category'))
  moreGrid.appendChild(catSelect)

  // Type dropdown (recurring / one-time)
  const typeSelect = el('select', { style: 'width:auto;font-size:13px;' }) as HTMLSelectElement
  typeSelect.appendChild(el('option', { value: 'recurring' }, 'recurring'))
  typeSelect.appendChild(el('option', { value: 'one-time' }, 'one-time'))
  typeSelect.value = task.recurring ? 'recurring' : 'one-time'
  typeSelect.onchange = () => {
    const isRecurring = typeSelect.value === 'recurring'
    updateTask(task.id, {
      recurring: isRecurring,
      lastResetAt: isRecurring && !task.lastResetAt ? new Date().toISOString() : task.lastResetAt,
    })
    navigate('detail', task.id)
  }
  moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Type'))
  moreGrid.appendChild(typeSelect)

  // Cadence dropdown (for recurring tasks)
  if (task.recurring) {
    const cadenceSelect = el('select', { style: 'width:auto;font-size:13px;' }) as HTMLSelectElement
    for (const opt of CADENCE_OPTIONS) {
      const o = el('option', { value: String(opt.value) }, opt.label)
      if (opt.value === task.cadenceSeconds) o.selected = true
      cadenceSelect.appendChild(o)
    }
    cadenceSelect.onchange = () => {
      updateTask(task.id, { cadenceSeconds: parseInt(cadenceSelect.value) })
      navigate('detail', task.id)
    }
    moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Every'))
    moreGrid.appendChild(cadenceSelect)

    // Variance: less / more (in minutes)
    const lessInput = el('input', { type: 'number', value: String(Math.round((task.cadenceLess ?? 0) / 60)), style: 'width:60px;font-size:13px;' }) as HTMLInputElement
    lessInput.min = '0'
    lessInput.placeholder = '0'
    lessInput.onchange = () => updateTask(task.id, { cadenceLess: parseInt(lessInput.value || '0') * 60 })
    moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Less (min)'))
    moreGrid.appendChild(lessInput)

    const moreInput = el('input', { type: 'number', value: String(Math.round((task.cadenceMore ?? 0) / 60)), style: 'width:60px;font-size:13px;' }) as HTMLInputElement
    moreInput.min = '0'
    moreInput.placeholder = '0'
    moreInput.onchange = () => updateTask(task.id, { cadenceMore: parseInt(moreInput.value || '0') * 60 })
    moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'More (min)'))
    moreGrid.appendChild(moreInput)
  }

  // Priority dropdown
  const prioritySelect = el('select', { className: `fmn-badge fmn-badge-${task.priority}`, style: 'border:none;font-size:10px;' }) as HTMLSelectElement
  const priorities: TaskPriority[] = ['low', 'normal', 'high', 'critical']
  for (const p of priorities) {
    const opt = el('option', { value: p }, p)
    if (p === task.priority) opt.selected = true
    prioritySelect.appendChild(opt)
  }
  prioritySelect.onchange = () => {
    updateTask(task.id, { priority: prioritySelect.value as TaskPriority })
    navigate('detail', task.id)
  }
  moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Priority'))
  moreGrid.appendChild(prioritySelect)

  // Static details
  addGridRow(moreGrid, 'Tags', task.tags.length > 0 ? task.tags.join(', ') : '\u2014')
  addGridRow(moreGrid, 'Created', timeAgo(task.createdAt))
  addGridRow(moreGrid, 'Updated', timeAgo(task.updatedAt))
  if (task.dueDate) addGridRow(moreGrid, 'Due', new Date(task.dueDate).toLocaleString())
  if (task.estimatedHours) addGridRow(moreGrid, 'Estimate', `${task.estimatedHours}h`)

  if (task.parentTaskId) {
    const parentLink = el('span', { className: 'fmn-task-title' }, 'View parent')
    parentLink.style.fontSize = '13px'
    parentLink.onclick = () => navigate('detail', task.parentTaskId!)
    moreGrid.appendChild(el('span', { className: 'fmn-detail-label' }, 'Parent'))
    moreGrid.appendChild(parentLink)
  }

  moreContent.appendChild(moreGrid)

  // Action log inside More
  renderActionLog(moreContent, task)

  moreWrap.appendChild(moreTrigger)
  moreWrap.appendChild(moreContent)
  card.appendChild(moreWrap)

  container.appendChild(card)
}

function renderFollowUps(container: HTMLElement, task: Task): void {
  const section = el('div', { className: 'fmn-detail-section' })
  section.appendChild(el('h3', {}, 'Follow-up Chain'))

  // Queued follow-ups (not yet spawned)
  if (task.followUps.length > 0) {
    const chain = el('div', { className: 'fmn-chain' })
    task.followUps.forEach((fu, idx) => {
      if (idx > 0) chain.appendChild(el('span', { className: 'fmn-chain-arrow' }, '\u2192'))
      const item = el('span', { className: 'fmn-chain-item' },
        `${fu.title} (${formatCadence(fu.cadenceSeconds)})`,
      )
      const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
      removeBtn.onclick = () => {
        const newFollowUps = task.followUps.filter((_, i) => i !== idx)
        updateTask(task.id, { followUps: newFollowUps })
        navigate('detail', task.id)
      }
      item.appendChild(removeBtn)
      chain.appendChild(item)
    })
    section.appendChild(chain)
  }

  // Add follow-up
  const addRow = el('div', { className: 'fmn-inline-add' })
  const titleInput = el('input', { type: 'text', placeholder: 'Follow-up title...' }) as HTMLInputElement
  const cadenceSelect = el('select', {}) as HTMLSelectElement
  for (const opt of CADENCE_OPTIONS) {
    cadenceSelect.appendChild(el('option', { value: String(opt.value) }, opt.label))
  }
  const addBtn = createActionBtn('+', 'btn-accent btn-sm', () => {
    if (!titleInput.value.trim()) return
    const newFollowUps = [...task.followUps, {
      title: titleInput.value.trim(),
      cadenceSeconds: parseInt(cadenceSelect.value),
    }]
    updateTask(task.id, { followUps: newFollowUps })
    navigate('detail', task.id)
  })
  addRow.appendChild(titleInput)
  addRow.appendChild(cadenceSelect)
  addRow.appendChild(addBtn)
  section.appendChild(addRow)

  // Spawned child tasks (already created from previous completions)
  const children = getTasks().filter((t) => t.parentTaskId === task.id)
  if (children.length > 0) {
    section.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);text-transform:uppercase;letter-spacing:0.5px;margin-top:12px;margin-bottom:6px;' }, 'Spawned'))
    for (const child of children) {
      const row = el('div', { className: 'fmn-card', style: 'cursor:pointer;padding:8px 12px;' })
      const inner = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      inner.appendChild(el('span', { style: 'flex:1;font-size:13px;color:var(--accent);' }, child.title))
      inner.appendChild(el('span', { className: `fmn-badge fmn-badge-${child.status === 'done' ? 'normal' : 'recurring'}`, style: 'font-size:9px;' }, child.status))
      if (child.followUps.length > 0) {
        inner.appendChild(el('span', { style: 'font-size:10px;color:var(--dim);' }, `+${child.followUps.length} queued`))
      }
      row.appendChild(inner)
      row.onclick = () => navigate('detail', child.id)
      section.appendChild(row)
    }
  }

  container.appendChild(section)
}

function renderPrompts(container: HTMLElement, task: Task): void {
  const section = el('div', { className: 'fmn-detail-section' })
  section.appendChild(el('h3', {}, 'Reminders'))

  if (task.prompts.length > 0) {
    const list = el('div', { className: 'fmn-domain-list', style: 'margin-bottom:6px;' })
    for (let i = 0; i < task.prompts.length; i++) {
      const tag = el('span', { className: 'fmn-domain-tag' }, task.prompts[i])
      const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
      removeBtn.onclick = () => {
        const newPrompts = task.prompts.filter((_, idx) => idx !== i)
        updateTask(task.id, { prompts: newPrompts })
        navigate('detail', task.id)
      }
      tag.appendChild(removeBtn)
      list.appendChild(tag)
    }
    section.appendChild(list)
  }

  const addRow = el('div', { className: 'fmn-inline-add' })
  const input = el('input', { type: 'text', placeholder: 'Add a reminder...' }) as HTMLInputElement
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && input.value.trim()) {
      const newPrompts = [...task.prompts, input.value.trim()]
      updateTask(task.id, { prompts: newPrompts })
      navigate('detail', task.id)
    }
  })
  addRow.appendChild(input)
  section.appendChild(addRow)

  container.appendChild(section)
}

function renderActionLog(container: HTMLElement, task: Task): void {
  const section = el('div', { className: 'fmn-detail-section' })
  section.appendChild(el('h3', {}, 'Action Log'))

  if (task.actionLog.length === 0) {
    section.appendChild(el('div', { style: 'color:var(--dim);font-size:12px;' }, 'No actions yet.'))
  } else {
    const entries = [...task.actionLog].reverse()
    for (const entry of entries) {
      const row = el('div', { className: 'fmn-log-entry' })
      row.appendChild(el('span', { className: `fmn-log-badge fmn-log-badge-${entry.action}` }, entry.action))
      row.appendChild(el('span', { className: 'fmn-log-note' }, entry.note || '\u2014'))
      row.appendChild(el('span', { className: 'fmn-log-time' }, timeAgo(entry.at)))
      section.appendChild(row)
    }
  }

  const addRow = el('div', { className: 'fmn-inline-add', style: 'margin-top:8px;' })
  const noteInput = el('input', { type: 'text', placeholder: 'Add a note...' }) as HTMLInputElement
  noteInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && noteInput.value.trim()) {
      addActionNote(task.id, noteInput.value.trim())
      navigate('detail', task.id)
    }
  })
  addRow.appendChild(noteInput)
  section.appendChild(addRow)

  container.appendChild(section)
}

function addGridRow(grid: HTMLElement, label: string, value: string): void {
  grid.appendChild(el('span', { className: 'fmn-detail-label' }, label))
  grid.appendChild(el('span', {}, value))
}

function createActionBtn(text: string, className: string, onClick: () => void): HTMLButtonElement {
  const btn = el('button', { className }, text) as HTMLButtonElement
  btn.onclick = onClick
  return btn
}
