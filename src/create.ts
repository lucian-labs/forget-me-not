import type { FollowUp } from './types'
import { createTask, getSettings } from './store'
import { el, CADENCE_OPTIONS, formatCadence } from './utils'
import { navigate } from './app'

export function renderCreate(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, 'forget me not')
  headerTitle.onclick = () => navigate('panel')
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle, el('div', { className: 'fmn-section', style: 'margin:0;' }, 'New Task')))

  const card = el('div', { className: 'fmn-card' })

  // Title row: input + recurring toggle
  const titleRow = el('div', { style: 'display:flex;align-items:center;gap:10px;' })
  const titleInput = el('input', { type: 'text', placeholder: 'What needs doing...' }) as HTMLInputElement
  titleInput.style.flex = '1'
  titleRow.appendChild(titleInput)

  const recurLabel = el('label', { className: 'fmn-toggle' })
  const recurCheckbox = el('input', { type: 'checkbox' }) as HTMLInputElement
  recurCheckbox.onchange = () => {
    cadencePriorityRow.style.display = 'flex'
    cadenceGroup.style.display = recurCheckbox.checked ? 'block' : 'none'
    recurText.textContent = recurCheckbox.checked ? 'repeats' : ''
  }
  recurLabel.appendChild(recurCheckbox)
  recurLabel.appendChild(el('span', { className: 'fmn-toggle-track' }))
  recurLabel.appendChild(el('span', { className: 'fmn-toggle-thumb' }))
  titleRow.appendChild(recurLabel)
  const recurText = el('span', { style: 'font-size:11px;color:var(--dim);white-space:nowrap;' }, '')
  titleRow.appendChild(recurText)

  card.appendChild(titleRow)

  // Cadence + Priority side by side
  const cadencePriorityRow = el('div', { className: 'fmn-form-row', style: 'margin-top:12px;' })

  const cadenceGroup = el('div', { className: 'fmn-form-group', style: 'display:none;' })
  cadenceGroup.appendChild(el('label', {}, 'Every'))
  const cadenceSelect = el('select', {}) as HTMLSelectElement
  for (const opt of CADENCE_OPTIONS) {
    cadenceSelect.appendChild(el('option', { value: String(opt.value) }, opt.label))
  }
  cadenceGroup.appendChild(cadenceSelect)
  cadencePriorityRow.appendChild(cadenceGroup)

  const priorityGroup = el('div', { className: 'fmn-form-group' })
  priorityGroup.appendChild(el('label', {}, 'Priority'))
  const prioritySelect = el('select', {}) as HTMLSelectElement
  for (const p of ['low', 'normal', 'high', 'critical']) {
    const opt = el('option', { value: p }, p)
    if (p === 'normal') opt.selected = true
    prioritySelect.appendChild(opt)
  }
  priorityGroup.appendChild(prioritySelect)
  cadencePriorityRow.appendChild(priorityGroup)

  card.appendChild(cadencePriorityRow)

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

  // Category
  const domainGroup = el('div', { className: 'fmn-form-group' })
  domainGroup.appendChild(el('label', {}, 'Category'))
  const domainSelect = el('select', {}) as HTMLSelectElement
  domainSelect.appendChild(el('option', { value: '' }, '\u2014'))
  for (const d of settings.domains) {
    domainSelect.appendChild(el('option', { value: d }, d))
  }
  domainGroup.appendChild(domainSelect)
  advContent.appendChild(domainGroup)

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

  // Reminders
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
  advContent.appendChild(promptGroup)

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

    createTask({
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
