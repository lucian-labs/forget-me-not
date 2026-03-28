import type { Task, TaskStatus, TaskPriority } from './types'
import {
  getTask, updateTask, resetTask, completeTask, archiveTask,
  getUrgencyRatio, getUrgencyColor, addActionNote,
} from './store'
import { el, timeAgo, formatCadence, formatTime, CADENCE_OPTIONS } from './utils'
import { navigate } from './app'

export function renderDetail(container: HTMLElement, taskId: string): void {
  const task = getTask(taskId)
  if (!task) {
    container.innerHTML = ''
    const title = el('h1', { className: 'fmn-header-title' }, 'forget me not')
    title.onclick = () => navigate('panel')
    container.appendChild(el('div', { className: 'fmn-header' }, title))
    container.appendChild(el('div', { className: 'fmn-empty' }, 'Task not found.'))
    return
  }

  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, 'forget me not')
  headerTitle.onclick = () => navigate('panel')
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle))

  // Header
  const header = el('div', { className: 'fmn-detail-header' })
  const titleInput = el('input', { type: 'text', className: 'fmn-detail-title', value: task.title }) as HTMLInputElement
  titleInput.style.background = 'transparent'
  titleInput.style.border = 'none'
  titleInput.style.fontSize = '20px'
  titleInput.style.fontWeight = '600'
  titleInput.style.color = 'var(--text)'
  titleInput.style.padding = '0'
  titleInput.style.width = '100%'
  titleInput.onblur = () => { if (titleInput.value !== task.title) updateTask(task.id, { title: titleInput.value }) }
  header.appendChild(titleInput)

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
  header.appendChild(statusSelect)

  // Priority badge
  const prioritySelect = el('select', { className: `fmn-badge fmn-badge-${task.priority}` }) as HTMLSelectElement
  prioritySelect.style.border = 'none'
  prioritySelect.style.fontSize = '10px'
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
  header.appendChild(prioritySelect)

  if (task.recurring) {
    header.appendChild(el('span', { className: 'fmn-badge fmn-badge-recurring' }, 'recurring'))
  }

  container.appendChild(header)

  // Description
  const descSection = el('div', { className: 'fmn-detail-section' })
  descSection.appendChild(el('h3', {}, 'Description'))
  const descArea = el('textarea', { placeholder: 'Add a description...' }) as HTMLTextAreaElement
  descArea.value = task.description
  descArea.onblur = () => { if (descArea.value !== task.description) updateTask(task.id, { description: descArea.value }) }
  descSection.appendChild(descArea)
  container.appendChild(descSection)

  // Decision prompts
  renderPrompts(container, task)

  // Follow-up chain
  renderFollowUps(container, task)

  // Details + Action log side by side
  const columns = el('div', { className: 'fmn-detail-columns' })

  // Details grid
  const detailSection = el('div', { className: 'fmn-detail-section' })
  detailSection.appendChild(el('h3', {}, 'Details'))
  const grid = el('div', { className: 'fmn-detail-grid' })

  addGridRow(grid, 'Category', task.domain || '—')
  addGridRow(grid, 'Tags', task.tags.length > 0 ? task.tags.join(', ') : '—')
  addGridRow(grid, 'Created', timeAgo(task.createdAt))
  addGridRow(grid, 'Updated', timeAgo(task.updatedAt))
  if (task.dueDate) addGridRow(grid, 'Due', new Date(task.dueDate).toLocaleString())
  if (task.estimatedHours) addGridRow(grid, 'Estimate', `${task.estimatedHours}h`)
  if (task.recurring && task.cadenceSeconds) addGridRow(grid, 'Cadence', `every ${formatCadence(task.cadenceSeconds)}`)

  if (task.recurring && task.lastResetAt && task.cadenceSeconds) {
    const ratio = getUrgencyRatio(task)
    const elapsed = (Date.now() - new Date(task.lastResetAt).getTime()) / 1000
    const remaining = task.cadenceSeconds - elapsed
    const urgencyText = remaining > 0 ? `${formatTime(remaining)} left` : `${formatTime(Math.abs(remaining))} over`
    const urgencyEl = el('span', {}, urgencyText)
    urgencyEl.style.color = getUrgencyColor(ratio)
    const labelEl = el('span', { className: 'fmn-detail-label' }, 'Urgency')
    grid.appendChild(labelEl)
    grid.appendChild(urgencyEl)
  }

  if (task.parentTaskId) {
    const parentLink = el('span', { className: 'fmn-task-title' }, 'View parent')
    parentLink.style.fontSize = '13px'
    parentLink.onclick = () => navigate('detail', task.parentTaskId!)
    const labelEl = el('span', { className: 'fmn-detail-label' }, 'Parent')
    grid.appendChild(labelEl)
    grid.appendChild(parentLink)
  }

  detailSection.appendChild(grid)
  columns.appendChild(detailSection)

  // Action log
  renderActionLog(columns, task)

  container.appendChild(columns)

  // Actions
  const actionsSection = el('div', { className: 'fmn-detail-section' })
  actionsSection.appendChild(el('h3', {}, 'Actions'))
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
  container.appendChild(actionsSection)
}

function renderFollowUps(container: HTMLElement, task: Task): void {
  const section = el('div', { className: 'fmn-detail-section' })
  section.appendChild(el('h3', {}, 'Follow-up Chain'))

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

  // Add form
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

  container.appendChild(section)
}

function renderPrompts(container: HTMLElement, task: Task): void {
  const section = el('div', { className: 'fmn-detail-section' })
  section.appendChild(el('h3', {}, 'Decision Prompts'))

  for (let i = 0; i < task.prompts.length; i++) {
    const promptRow = el('div', { style: 'display:flex;align-items:center;gap:6px;margin-bottom:4px;' })
    promptRow.appendChild(el('span', { className: 'fmn-prompt', style: 'margin:0;' }, `? ${task.prompts[i]}`))
    const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
    removeBtn.onclick = () => {
      const newPrompts = task.prompts.filter((_, idx) => idx !== i)
      updateTask(task.id, { prompts: newPrompts })
      navigate('detail', task.id)
    }
    promptRow.appendChild(removeBtn)
    section.appendChild(promptRow)
  }

  const addRow = el('div', { className: 'fmn-inline-add' })
  const input = el('input', { type: 'text', placeholder: 'Add a prompt...' }) as HTMLInputElement
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
      row.appendChild(el('span', { className: 'fmn-log-note' }, entry.note || '—'))
      row.appendChild(el('span', { className: 'fmn-log-time' }, timeAgo(entry.at)))
      section.appendChild(row)
    }
  }

  // Add note
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
