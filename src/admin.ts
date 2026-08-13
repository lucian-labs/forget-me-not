// Admin panel — build, save, and share "setups": a named bundle of the look, the
// sounds, the categories, and a set of starter loops. Share one as a link or QR
// and whoever opens it starts from your configuration.

import { el } from './utils'
import { navigate } from './app'
import { appName } from './brand'
import { getTasks, getSettings } from './store'
import { compress } from './transfer'
import {
  type Setup, getSetups, saveSetup, deleteSetup, captureSetup, applySetup,
  setupToJson, parseSetupJson, getDefaultSetupId, setDefaultSetupId,
} from './config'

// Draft state for the composer, kept across re-renders within a visit.
let draft = {
  name: '',
  description: '',
  includeTheme: true,
  includeSound: true,
  includeNaming: true,
  taskMode: 'all' as 'all' | 'pick' | 'none',
  picked: new Set<string>(),
  editingId: null as string | null,
}

export function renderAdmin(container: HTMLElement): void {
  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, appName())
  headerTitle.onclick = () => navigate('panel')
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle,
    el('div', { className: 'fmn-section', style: 'margin:0;' }, 'Setups')))

  container.appendChild(el('div', { className: 'fmn-card' },
    el('div', { style: 'font-size:13px;color:var(--text);' },
      'A setup is a starting point you can hand to someone: your colours, your sounds, your categories, and a set of loops to begin with.'),
    el('div', { style: 'font-size:11px;color:var(--dim);margin-top:6px;' },
      'Applying a setup never deletes anything — it only adds.')))

  container.appendChild(composer())
  container.appendChild(savedList(container))
  container.appendChild(importCard(container))
}

// --- composer ---

function composer(): HTMLElement {
  const card = el('div', { className: 'fmn-card' })
  card.appendChild(sectionLabel(draft.editingId ? 'Edit setup' : 'New setup'))

  const nameInput = el('input', { type: 'text', placeholder: 'Name it — "Morning routine"', value: draft.name }) as HTMLInputElement
  nameInput.oninput = () => { draft.name = nameInput.value }
  card.appendChild(nameInput)

  const descInput = el('input', { type: 'text', placeholder: 'A line about what it is (optional)', value: draft.description, style: 'margin-top:8px;' }) as HTMLInputElement
  descInput.oninput = () => { draft.description = descInput.value }
  card.appendChild(descInput)

  card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin:14px 0 6px;' }, 'Include:'))

  const settings = getSettings()
  card.appendChild(checkRow('The look', `Theme: ${settings.themePreset}`, draft.includeTheme, (v) => { draft.includeTheme = v }))
  card.appendChild(checkRow('The sounds', `Seed "${settings.soundSeed}", ${Math.round(settings.soundBpm)} BPM`, draft.includeSound, (v) => { draft.includeSound = v }))
  card.appendChild(checkRow('Name & categories', settings.domains.join(', ') || 'no categories yet', draft.includeNaming, (v) => { draft.includeNaming = v }))

  // Which loops
  card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin:14px 0 6px;' }, 'Loops to start with:'))
  const modeRow = el('div', { style: 'display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px;' })
  const active = getTasks().filter((t) => t.status !== 'archived' && t.status !== 'cancelled')
  for (const [mode, label] of [['all', `All of mine (${active.length})`], ['pick', 'Choose…'], ['none', 'None']] as const) {
    const b = el('button', {
      className: draft.taskMode === mode ? 'btn-accent' : 'btn-ghost',
      style: 'font-size:12px;padding:6px 10px;',
    }, label) as HTMLButtonElement
    b.onclick = () => { draft.taskMode = mode; rerender() }
    modeRow.appendChild(b)
  }
  card.appendChild(modeRow)

  if (draft.taskMode === 'pick') {
    const list = el('div', { style: 'max-height:220px;overflow-y:auto;border:1px solid var(--border);border-radius:6px;padding:8px;margin-bottom:8px;' })
    for (const t of active) {
      const row = el('label', { style: 'display:flex;align-items:center;gap:8px;padding:4px 0;font-size:13px;cursor:pointer;' })
      const cb = el('input', { type: 'checkbox' }) as HTMLInputElement
      cb.checked = draft.picked.has(t.id)
      cb.onchange = () => { cb.checked ? draft.picked.add(t.id) : draft.picked.delete(t.id) }
      row.appendChild(cb)
      row.appendChild(el('span', { style: 'color:var(--text);' }, t.title))
      if (t.domain) row.appendChild(el('span', { style: 'color:var(--dim);font-size:11px;' }, t.domain))
      list.appendChild(row)
    }
    if (!active.length) list.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);' }, 'No loops yet.'))
    card.appendChild(list)
  }

  const saveBtn = el('button', { className: 'btn-accent', style: 'width:100%;padding:12px;margin-top:8px;' },
    draft.editingId ? 'Save changes' : 'Save setup') as HTMLButtonElement
  saveBtn.onclick = () => {
    if (!draft.name.trim()) {
      nameInput.style.borderColor = 'var(--red)'
      nameInput.focus()
      return
    }
    const setup = captureSetup({
      name: draft.name,
      description: draft.description,
      includeTheme: draft.includeTheme,
      includeSound: draft.includeSound,
      includeNaming: draft.includeNaming,
      taskIds: draft.taskMode === 'all' ? 'all' : draft.taskMode === 'none' ? 'none' : [...draft.picked],
      id: draft.editingId ?? undefined,
    })
    saveSetup(setup)
    draft = { ...draft, name: '', description: '', taskMode: 'all', picked: new Set(), editingId: null }
    rerender()
  }
  card.appendChild(saveBtn)

  if (draft.editingId) {
    const cancel = el('button', { className: 'btn-ghost', style: 'width:100%;padding:10px;margin-top:6px;' }, 'Cancel') as HTMLButtonElement
    cancel.onclick = () => {
      draft = { ...draft, name: '', description: '', taskMode: 'all', picked: new Set(), editingId: null }
      rerender()
    }
    card.appendChild(cancel)
  }

  return card
}

// --- saved setups ---

function savedList(container: HTMLElement): HTMLElement {
  const card = el('div', { className: 'fmn-card' })
  card.appendChild(sectionLabel('Your setups'))

  const setups = getSetups()
  if (!setups.length) {
    card.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);' }, 'Nothing saved yet — build one above.'))
    return card
  }

  const defaultId = getDefaultSetupId()
  for (const setup of setups) {
    card.appendChild(setupRow(setup, setup.id === defaultId, container))
  }
  card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin-top:10px;' },
    'The "start here" setup is what a brand-new install begins with, instead of the built-in loops.'))
  return card
}

function setupRow(setup: Setup, isDefault: boolean, container: HTMLElement): HTMLElement {
  const row = el('div', { style: 'border:1px solid var(--border);border-radius:6px;padding:10px;margin-bottom:8px;' })

  const top = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
  top.appendChild(el('span', { style: 'font-size:14px;font-weight:600;color:var(--text);' }, setup.name))
  if (isDefault) {
    top.appendChild(el('span', {
      style: 'font-size:10px;background:var(--accent);color:var(--bg);padding:2px 6px;border-radius:3px;',
    }, 'start here'))
  }
  row.appendChild(top)

  if (setup.description) {
    row.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);margin-top:2px;' }, setup.description))
  }

  const bits: string[] = []
  if (setup.theme) bits.push(`look: ${setup.theme.label ?? setup.theme.name}`)
  if (setup.sound) bits.push('sounds')
  if (setup.appName !== undefined || setup.domains) bits.push('name & categories')
  if (setup.tasks?.length) bits.push(`${setup.tasks.length} loop${setup.tasks.length === 1 ? '' : 's'}`)
  row.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin-top:4px;' }, bits.join(' · ') || 'empty'))

  const actions = el('div', { style: 'display:flex;gap:6px;flex-wrap:wrap;margin-top:10px;' })

  actions.appendChild(smallBtn('Share', 'btn-accent', () => showShare(setup, container)))

  actions.appendChild(smallBtn('Apply', 'btn-ghost', () => {
    const r = applySetup(setup)
    const parts: string[] = []
    if (r.tasks) parts.push(`${r.tasks} loop${r.tasks === 1 ? '' : 's'} added`)
    if (r.theme) parts.push('look applied')
    if (r.sound) parts.push('sounds applied')
    if (r.naming) parts.push('name & categories applied')
    alert(parts.length ? parts.join(', ') + '.' : 'Nothing to apply.')
    navigate('panel')
  }))

  actions.appendChild(smallBtn(isDefault ? 'Not the start' : 'Start here', 'btn-ghost', () => {
    setDefaultSetupId(isDefault ? null : setup.id)
    rerender()
  }))

  actions.appendChild(smallBtn('Edit', 'btn-ghost', () => {
    draft = {
      ...draft,
      name: setup.name,
      description: setup.description,
      includeTheme: !!setup.theme,
      includeSound: !!setup.sound,
      includeNaming: setup.appName !== undefined || !!setup.domains,
      taskMode: setup.tasks?.length ? 'all' : 'none',
      picked: new Set(),
      editingId: setup.id,
    }
    rerender()
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }))

  actions.appendChild(smallBtn('Delete', 'btn-ghost', () => {
    if (!confirm(`Delete "${setup.name}"? This doesn't touch your tasks.`)) return
    deleteSetup(setup.id)
    rerender()
  }))

  row.appendChild(actions)
  return row
}

// --- share sheet ---

async function showShare(setup: Setup, _container: HTMLElement): Promise<void> {
  const overlay = el('div', {
    style: 'position:fixed;inset:0;background:var(--bg);z-index:100;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;overflow-y:auto;',
  })
  overlay.appendChild(el('div', { style: 'font-size:18px;font-weight:600;color:var(--accent);margin-bottom:4px;' }, 'Share this setup'))
  overlay.appendChild(el('div', { style: 'font-size:13px;color:var(--dim);margin-bottom:16px;' }, setup.name))

  const json = setupToJson(setup)
  const encoded = await compress(json)
  const url = `${location.origin}${location.pathname}#setup=${encoded}`

  overlay.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);text-align:center;max-width:420px;margin-bottom:16px;' },
    'Anyone who opens this link gets asked whether to use your setup.'))

  const copyLink = el('button', { className: 'btn-accent', style: 'margin-bottom:8px;min-width:220px;padding:12px;' }, 'Copy link') as HTMLButtonElement
  copyLink.onclick = () => {
    navigator.clipboard.writeText(url).then(() => {
      copyLink.textContent = 'Copied!'
      setTimeout(() => { copyLink.textContent = 'Copy link' }, 2000)
    })
  }
  overlay.appendChild(copyLink)

  if (navigator.share) {
    const shareBtn = el('button', { className: 'btn-ghost', style: 'margin-bottom:8px;min-width:220px;padding:12px;' }, 'Share…') as HTMLButtonElement
    shareBtn.onclick = async () => {
      try { await navigator.share({ title: `${setup.name} — a Forget Me Not setup`, url }) } catch { /* cancelled */ }
    }
    overlay.appendChild(shareBtn)
  }

  const copyJson = el('button', { className: 'btn-ghost', style: 'margin-bottom:8px;min-width:220px;padding:12px;' }, 'Copy as JSON') as HTMLButtonElement
  copyJson.onclick = () => {
    navigator.clipboard.writeText(json).then(() => {
      copyJson.textContent = 'Copied!'
      setTimeout(() => { copyJson.textContent = 'Copy as JSON' }, 2000)
    })
  }
  overlay.appendChild(copyJson)

  const dl = el('button', { className: 'btn-ghost', style: 'margin-bottom:16px;min-width:220px;padding:12px;' }, 'Download file') as HTMLButtonElement
  dl.onclick = () => {
    const blob = new Blob([json], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `${setup.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-setup.json`
    a.click()
    URL.revokeObjectURL(a.href)
  }
  overlay.appendChild(dl)

  if (url.length > 4000) {
    overlay.appendChild(el('div', { style: 'font-size:11px;color:var(--orange);max-width:420px;text-align:center;margin-bottom:12px;' },
      'This setup is large, so the link is long — some apps may cut it off. The JSON or file always works.'))
  }

  const close = el('button', { className: 'btn-ghost' }, 'Close') as HTMLButtonElement
  close.onclick = () => overlay.remove()
  overlay.appendChild(close)

  document.body.appendChild(overlay)
}

// --- import ---

function importCard(_container: HTMLElement): HTMLElement {
  const card = el('div', { className: 'fmn-card' })
  card.appendChild(sectionLabel('Add someone else’s setup'))
  const ta = el('textarea', { placeholder: 'Paste a setup link or its JSON here...', style: 'width:100%;min-height:70px;' }) as HTMLTextAreaElement
  card.appendChild(ta)

  const btn = el('button', { className: 'btn-accent', style: 'width:100%;padding:12px;margin-top:8px;' }, 'Add it') as HTMLButtonElement
  btn.onclick = async () => {
    const val = ta.value.trim()
    if (!val) return
    let setup: Setup | null = null
    if (val.includes('#setup=')) {
      try {
        const { decompress } = await import('./transfer')
        setup = parseSetupJson(await decompress(val.split('#setup=')[1]))
      } catch { setup = null }
    } else {
      setup = parseSetupJson(val)
    }
    if (!setup) {
      btn.textContent = 'That didn’t look like a setup'
      setTimeout(() => { btn.textContent = 'Add it' }, 2200)
      return
    }
    saveSetup(setup)
    ta.value = ''
    rerender()
  }
  card.appendChild(btn)
  return card
}

// --- setup link on arrival (called from app.ts) ---

/** Handle a `#setup=` link: offer to apply it, and keep a copy either way. */
export async function checkSetupFromUrl(): Promise<boolean> {
  if (!location.hash.startsWith('#setup=')) return false
  const encoded = location.hash.slice(7)
  try {
    const { decompress } = await import('./transfer')
    const setup = parseSetupJson(await decompress(encoded))
    if (!setup) throw new Error('bad setup')
    history.replaceState(null, '', location.pathname)
    saveSetup(setup)
    const bits: string[] = []
    if (setup.theme) bits.push('a look')
    if (setup.sound) bits.push('sounds')
    if (setup.tasks?.length) bits.push(`${setup.tasks.length} loops`)
    const summary = bits.length ? ` (${bits.join(', ')})` : ''
    if (confirm(`Use the setup "${setup.name}"${summary}?\n\nThis adds to what you have — nothing gets deleted.`)) {
      applySetup(setup)
    }
    navigate('panel')
    return true
  } catch {
    history.replaceState(null, '', location.pathname)
    alert('That setup link looks broken.')
    return false
  }
}

// --- small helpers (match the settings panel's look) ---

function rerender(): void {
  navigate('admin')
}

function sectionLabel(text: string): HTMLElement {
  return el('div', {
    style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;',
  }, text)
}

function smallBtn(label: string, cls: string, onClick: () => void): HTMLElement {
  const b = el('button', { className: cls, style: 'font-size:12px;padding:6px 10px;' }, label) as HTMLButtonElement
  b.onclick = onClick
  return b
}

function checkRow(label: string, hint: string, checked: boolean, onChange: (v: boolean) => void): HTMLElement {
  const row = el('label', { style: 'display:flex;align-items:flex-start;gap:8px;padding:5px 0;cursor:pointer;' })
  const cb = el('input', { type: 'checkbox' }) as HTMLInputElement
  cb.checked = checked
  cb.onchange = () => onChange(cb.checked)
  row.appendChild(cb)
  const text = el('div', {})
  text.appendChild(el('div', { style: 'font-size:13px;color:var(--text);' }, label))
  text.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);' }, hint))
  row.appendChild(text)
  return row
}
