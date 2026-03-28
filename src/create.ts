import type { FollowUp } from './types'
import { createTask, getSettings } from './store'
import { el, CADENCE_OPTIONS, formatCadence } from './utils'
import { navigate } from './app'

export function renderCreate(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  // Back
  const back = el('button', { className: 'fmn-back' }, '\u2190 back')
  back.onclick = () => navigate('panel')
  container.appendChild(back)

  container.appendChild(el('div', { className: 'fmn-section' }, 'New Task'))

  const card = el('div', { className: 'fmn-card' })

  // Title
  const titleGroup = el('div', { className: 'fmn-form-group' })
  titleGroup.appendChild(el('label', {}, 'Title'))
  const titleInput = el('input', { type: 'text', placeholder: 'What needs doing...' }) as HTMLInputElement
  titleGroup.appendChild(titleInput)
  card.appendChild(titleGroup)

  // Domain + Priority
  const row1 = el('div', { className: 'fmn-form-row' })

  const domainGroup = el('div', { className: 'fmn-form-group' })
  domainGroup.appendChild(el('label', {}, 'Category'))
  const domainSelect = el('select', {}) as HTMLSelectElement
  domainSelect.appendChild(el('option', { value: '' }, '—'))
  for (const d of settings.domains) {
    domainSelect.appendChild(el('option', { value: d }, d))
  }
  domainGroup.appendChild(domainSelect)
  row1.appendChild(domainGroup)

  const priorityGroup = el('div', { className: 'fmn-form-group' })
  priorityGroup.appendChild(el('label', {}, 'Priority'))
  const prioritySelect = el('select', {}) as HTMLSelectElement
  for (const p of ['low', 'normal', 'high', 'critical']) {
    const opt = el('option', { value: p }, p)
    if (p === 'normal') opt.selected = true
    prioritySelect.appendChild(opt)
  }
  priorityGroup.appendChild(prioritySelect)
  row1.appendChild(priorityGroup)

  card.appendChild(row1)

  // Recurring toggle + cadence
  const recurGroup = el('div', { className: 'fmn-form-group' })
  recurGroup.appendChild(el('label', {}, 'Type'))

  const typeRow = el('div', { style: 'display:flex;gap:8px;align-items:center;' })
  const recurCheckbox = el('input', { type: 'checkbox', style: 'width:auto;' }) as HTMLInputElement
  typeRow.appendChild(recurCheckbox)
  typeRow.appendChild(el('span', { style: 'font-size:13px;' }, 'Recurring'))
  recurGroup.appendChild(typeRow)

  const cadenceGroup = el('div', { className: 'fmn-form-group', style: 'display:none;' })
  cadenceGroup.appendChild(el('label', {}, 'Cadence'))
  const cadenceSelect = el('select', {}) as HTMLSelectElement
  for (const opt of CADENCE_OPTIONS) {
    cadenceSelect.appendChild(el('option', { value: String(opt.value) }, opt.label))
  }
  cadenceGroup.appendChild(cadenceSelect)

  recurCheckbox.onchange = () => {
    cadenceGroup.style.display = recurCheckbox.checked ? 'block' : 'none'
    dueDateGroup.style.display = recurCheckbox.checked ? 'none' : 'block'
  }

  card.appendChild(recurGroup)
  card.appendChild(cadenceGroup)

  // Due date (one-time)
  const dueDateGroup = el('div', { className: 'fmn-form-group' })
  dueDateGroup.appendChild(el('label', {}, 'Due Date (optional)'))
  const dueDateInput = el('input', { type: 'datetime-local' }) as HTMLInputElement
  dueDateGroup.appendChild(dueDateInput)
  card.appendChild(dueDateGroup)

  // Tags
  const tagsGroup = el('div', { className: 'fmn-form-group' })
  tagsGroup.appendChild(el('label', {}, 'Tags (comma separated)'))
  const tagsInput = el('input', { type: 'text', placeholder: 'tag1, tag2...' }) as HTMLInputElement
  tagsGroup.appendChild(tagsInput)
  card.appendChild(tagsGroup)

  // Description
  const descGroup = el('div', { className: 'fmn-form-group' })
  descGroup.appendChild(el('label', {}, 'Description'))
  const descArea = el('textarea', { placeholder: 'Optional details...' }) as HTMLTextAreaElement
  descGroup.appendChild(descArea)
  card.appendChild(descGroup)

  // Follow-ups
  const followUps: FollowUp[] = []
  const fuGroup = el('div', { className: 'fmn-form-group' })
  fuGroup.appendChild(el('label', {}, 'Follow-ups'))
  const fuList = el('div', { className: 'fmn-chain', style: 'margin-bottom:6px;' })
  fuGroup.appendChild(fuList)

  const fuAddRow = el('div', { className: 'fmn-inline-add' })
  const fuTitleInput = el('input', { type: 'text', placeholder: 'Follow-up title...' }) as HTMLInputElement
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

  // Decision prompts
  const prompts: string[] = []
  const promptGroup = el('div', { className: 'fmn-form-group' })
  promptGroup.appendChild(el('label', {}, 'Reminders'))
  const promptList = el('div', { style: 'margin-bottom:6px;' })
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
      const row = el('div', { style: 'display:flex;align-items:center;gap:6px;margin-bottom:4px;' })
      row.appendChild(el('span', { className: 'fmn-prompt', style: 'margin:0;' }, `? ${p}`))
      const removeBtn = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
      removeBtn.onclick = () => { prompts.splice(idx, 1); renderPromptList() }
      row.appendChild(removeBtn)
      promptList.appendChild(row)
    })
  }

  // Submit
  const submitRow = el('div', { className: 'fmn-form-row', style: 'margin-top:16px;' })
  const submitBtn = el('button', { className: 'btn-accent' }, 'Create Task') as HTMLButtonElement
  submitBtn.onclick = () => {
    const title = titleInput.value.trim()
    if (!title) { titleInput.style.borderColor = 'var(--red)'; return }

    const isRecurring = recurCheckbox.checked
    const tags = tagsInput.value.split(',').map((t) => t.trim()).filter(Boolean)
    const dueDate = dueDateInput.value ? new Date(dueDateInput.value).toISOString() : null

    createTask({
      title,
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

    navigate('panel')
  }
  submitRow.appendChild(submitBtn)

  const cancelBtn = el('button', { className: 'btn-ghost' }, 'Cancel') as HTMLButtonElement
  cancelBtn.onclick = () => navigate('panel')
  submitRow.appendChild(cancelBtn)

  card.appendChild(submitRow)
  container.appendChild(card)

  requestAnimationFrame(() => titleInput.focus())
}
