import type { FollowUp, Task } from './types'
import { createTask, getSettings } from './store'
import { el, CADENCE_OPTIONS, formatCadence } from './utils'
import { navigate } from './app'

// Persists across re-renders within the create view
let stickyRecurring = true
let stickyDomain = ''
let createdTasks: Task[] = []

export function renderCreate(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, 'forget me not')
  headerTitle.onclick = () => { createdTasks = []; navigate('panel') }
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle, el('div', { className: 'fmn-section', style: 'margin:0;' }, 'New Task')))

  const card = el('div', { className: 'fmn-card' })

  // Title row: input + recurring toggle
  const titleRow = el('div', { style: 'display:flex;align-items:center;gap:10px;' })
  const titleInput = el('input', { type: 'text', placeholder: 'What needs doing...' }) as HTMLInputElement
  titleInput.style.flex = '1'
  titleRow.appendChild(titleInput)

  const recurLabel = el('label', { className: 'fmn-toggle' })
  const recurCheckbox = el('input', { type: 'checkbox' }) as HTMLInputElement
  recurCheckbox.checked = stickyRecurring
  recurCheckbox.onchange = () => {
    stickyRecurring = recurCheckbox.checked
    cadenceGroup.style.display = recurCheckbox.checked ? 'block' : 'none'
    recurText.textContent = recurCheckbox.checked ? 'repeats' : ''
  }
  recurLabel.appendChild(recurCheckbox)
  recurLabel.appendChild(el('span', { className: 'fmn-toggle-track' }))
  recurLabel.appendChild(el('span', { className: 'fmn-toggle-thumb' }))
  titleRow.appendChild(recurLabel)
  const recurText = el('span', { style: 'font-size:11px;color:var(--dim);white-space:nowrap;' }, stickyRecurring ? 'repeats' : '')
  titleRow.appendChild(recurText)

  card.appendChild(titleRow)

  // Cadence + Category side by side
  const secondRow = el('div', { className: 'fmn-form-row', style: 'margin-top:12px;' })

  const cadenceGroup = el('div', { className: 'fmn-form-group', style: stickyRecurring ? 'display:block;' : 'display:none;' })
  cadenceGroup.appendChild(el('label', {}, 'Every'))
  const cadenceSelect = el('select', {}) as HTMLSelectElement
  for (const opt of CADENCE_OPTIONS) {
    cadenceSelect.appendChild(el('option', { value: String(opt.value) }, opt.label))
  }
  cadenceGroup.appendChild(cadenceSelect)
  secondRow.appendChild(cadenceGroup)

  const domainGroup = el('div', { className: 'fmn-form-group' })
  domainGroup.appendChild(el('label', {}, 'Category'))
  const domainSelect = el('select', {}) as HTMLSelectElement
  domainSelect.appendChild(el('option', { value: '' }, '\u2014'))
  for (const d of settings.domains) {
    const opt = el('option', { value: d }, d)
    if (d === stickyDomain) opt.selected = true
    domainSelect.appendChild(opt)
  }
  domainGroup.appendChild(domainSelect)
  secondRow.appendChild(domainGroup)

  card.appendChild(secondRow)

  // Follow-ups
  const followUps: FollowUp[] = []
  const fuGroup = el('div', { className: 'fmn-form-group', style: 'margin-top:12px;' })
  fuGroup.appendChild(el('label', {}, 'Follow-ups'))
  const fuList = el('div', { className: 'fmn-chain', style: 'margin-bottom:6px;' })
  fuGroup.appendChild(fuList)

  const fuAddRow = el('div', { className: 'fmn-inline-add' })
  const fuTitleInput = el('input', { type: 'text', placeholder: 'Next step...' }) as HTMLInputElement
  const fuCadenceSelect = el('select', {}) as HTMLSelectElement
  for (const opt of CADENCE_OPTIONS) {
    fuCadenceSelect.appendChild(el('option', { value: String(opt.value) }, opt.label))
  }
  const fuAddBtn = el('button', { className: 'btn-accent btn-sm' }, '+') as HTMLButtonElement
  fuAddBtn.onclick = () => {
    if (!fuTitleInput.value.trim()) return
    followUps.push({ title: fuTitleInput.value.trim(), cadenceSeconds: parseInt(fuCadenceSelect.value) })
    fuTitleInput.value = ''
    renderFollowUpList()
  }
  fuAddRow.appendChild(fuTitleInput)
  fuAddRow.appendChild(fuCadenceSelect)
  fuAddRow.appendChild(fuAddBtn)
  fuGroup.appendChild(fuAddRow)
  card.appendChild(fuGroup)

  function renderFollowUpList(): void {
    fuList.innerHTML = ''
    followUps.forEach((fu, idx) => {
      if (idx > 0) fuList.appendChild(el('span', { className: 'fmn-chain-arrow' }, '\u2192'))
      const item = el('span', { className: 'fmn-chain-item' }, `${fu.title} (${formatCadence(fu.cadenceSeconds)})`)
      const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
      removeBtn.onclick = () => { followUps.splice(idx, 1); renderFollowUpList() }
      item.appendChild(removeBtn)
      fuList.appendChild(item)
    })
  }

  // Reminders
  const prompts: string[] = []
  const promptGroup = el('div', { className: 'fmn-form-group', style: 'margin-top:12px;' })
  promptGroup.appendChild(el('label', {}, 'Reminders'))
  const promptList = el('div', { className: 'fmn-domain-list', style: 'margin-bottom:6px;' })
  promptGroup.appendChild(promptList)

  const promptAddRow = el('div', { className: 'fmn-inline-add' })
  const promptInput = el('input', { type: 'text', placeholder: 'e.g. Did you check the pockets?' }) as HTMLInputElement
  promptInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && promptInput.value.trim()) {
      e.preventDefault()
      prompts.push(promptInput.value.trim())
      promptInput.value = ''
      renderPromptList()
    }
  })
  promptAddRow.appendChild(promptInput)
  promptGroup.appendChild(promptAddRow)
  card.appendChild(promptGroup)

  function renderPromptList(): void {
    promptList.innerHTML = ''
    prompts.forEach((p, idx) => {
      const tag = el('span', { className: 'fmn-domain-tag' }, p)
      const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
      removeBtn.onclick = () => { prompts.splice(idx, 1); renderPromptList() }
      tag.appendChild(removeBtn)
      promptList.appendChild(tag)
    })
  }

  // Advanced fold
  const advWrap = el('div', { style: 'margin-top:12px;' })
  const advTrigger = el('button', { className: 'fmn-back', style: 'margin-bottom:0;font-size:12px;' }, '\u25B8 More options')
  const advContent = el('div', { style: 'display:none;margin-top:8px;' })
  let advOpen = false

  advTrigger.onclick = () => {
    advOpen = !advOpen
    advContent.style.display = advOpen ? 'block' : 'none'
    advTrigger.textContent = advOpen ? '\u25BE More options' : '\u25B8 More options'
  }

  // Priority
  const priorityGroup = el('div', { className: 'fmn-form-group' })
  priorityGroup.appendChild(el('label', {}, 'Priority'))
  const prioritySelect = el('select', {}) as HTMLSelectElement
  for (const p of ['low', 'normal', 'high', 'critical']) {
    const opt = el('option', { value: p }, p)
    if (p === 'normal') opt.selected = true
    prioritySelect.appendChild(opt)
  }
  priorityGroup.appendChild(prioritySelect)
  advContent.appendChild(priorityGroup)

  // Due date
  const dueDateGroup = el('div', { className: 'fmn-form-group' })
  dueDateGroup.appendChild(el('label', {}, 'Due date'))
  const dueDateInput = el('input', { type: 'datetime-local' }) as HTMLInputElement
  dueDateGroup.appendChild(dueDateInput)
  advContent.appendChild(dueDateGroup)

  // Tags
  const tagsGroup = el('div', { className: 'fmn-form-group' })
  tagsGroup.appendChild(el('label', {}, 'Tags'))
  const tagsInput = el('input', { type: 'text', placeholder: 'comma separated...' }) as HTMLInputElement
  tagsGroup.appendChild(tagsInput)
  advContent.appendChild(tagsGroup)

  // Description
  const descGroup = el('div', { className: 'fmn-form-group' })
  descGroup.appendChild(el('label', {}, 'Notes'))
  const descArea = el('textarea', { placeholder: 'Any extra details...' }) as HTMLTextAreaElement
  descGroup.appendChild(descArea)
  advContent.appendChild(descGroup)

  advWrap.appendChild(advTrigger)
  advWrap.appendChild(advContent)
  card.appendChild(advWrap)

  // Submit
  const submitRow = el('div', { className: 'fmn-form-row', style: 'margin-top:16px;' })
  const submitBtn = el('button', { className: 'btn-accent' }, 'Create') as HTMLButtonElement
  submitBtn.onclick = () => {
    const t = titleInput.value.trim()
    if (!t) { titleInput.style.borderColor = 'var(--red)'; return }

    const isRecurring = recurCheckbox.checked
    const tags = tagsInput.value.split(',').map((s) => s.trim()).filter(Boolean)
    const dueDate = dueDateInput.value ? new Date(dueDateInput.value).toISOString() : null

    // Remember sticky state
    stickyRecurring = isRecurring
    stickyDomain = domainSelect.value

    const task = createTask({
      title: t,
      description: descArea.value,
      domain: domainSelect.value,
      priority: prioritySelect.value as any,
      tags,
      recurring: isRecurring,
      cadenceSeconds: isRecurring ? parseInt(cadenceSelect.value) : null,
      dueDate: isRecurring ? null : dueDate,
      startedAt: dueDate ? new Date().toISOString() : null,
      followUps: [...followUps],
      prompts: [...prompts],
    })

    createdTasks.push(task)

    // Re-render to reset form but keep sticky state + show created list
    navigate('create')
  }
  submitRow.appendChild(submitBtn)

  card.appendChild(submitRow)
  container.appendChild(card)

  // Show created tasks this session
  if (createdTasks.length > 0) {
    container.appendChild(el('div', { className: 'fmn-section' }, `Created (${createdTasks.length})`))
    for (const task of [...createdTasks].reverse()) {
      const row = el('div', { className: 'fmn-card', style: 'cursor:pointer;' })
      const inner = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      inner.appendChild(el('span', { style: 'flex:1;font-size:14px;' }, task.title))
      if (task.recurring && task.cadenceSeconds) inner.appendChild(el('span', { className: 'fmn-badge fmn-badge-recurring' }, `every ${formatCadence(task.cadenceSeconds)}`))
      if (task.domain) inner.appendChild(el('span', { style: 'font-size:11px;color:var(--cyan);' }, task.domain))
      row.appendChild(inner)
      row.onclick = () => { createdTasks = []; navigate('detail', task.id) }
      container.appendChild(row)
    }
  }

  requestAnimationFrame(() => titleInput.focus())
}
