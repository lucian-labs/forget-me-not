import { getSettings, updateSettings, exportAll, importAll, clearAll } from './store'
import { el, downloadJson } from './utils'
import { refreshSound, playTest } from './sounds'
import { THEMES, applyTheme, resolveTheme } from './themes'
import { navigate } from './app'

const SOUND_PRESETS: { value: number; label: string }[] = [
  { value: 88, label: 'Crystal' },
  { value: 90, label: 'Hand Bell' },
  { value: 91, label: 'Chimes' },
  { value: 59, label: 'Music Box' },
  { value: 17, label: 'Vibraphone' },
  { value: 77, label: 'Raindrop' },
  { value: 0, label: 'Piano' },
  { value: 30, label: 'Flute' },
  { value: 92, label: 'Bell' },
  { value: 74, label: 'Whistle' },
]

export function renderSettings(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  // Back
  const back = el('button', { className: 'fmn-back' }, '\u2190 back')
  back.onclick = () => navigate('panel')
  container.appendChild(back)

  container.appendChild(el('div', { className: 'fmn-section' }, 'Settings'))

  // Categories (at top)
  const domainCard = el('div', { className: 'fmn-card' })
  domainCard.appendChild(sectionLabel('Categories'))

  const domainList = el('div', { className: 'fmn-domain-list' })
  for (const d of settings.domains) {
    const tag = el('span', { className: 'fmn-domain-tag' }, d)
    const remove = el('span', { className: 'fmn-domain-remove' }, '\u00D7')
    remove.onclick = () => {
      updateSettings({ domains: settings.domains.filter((x) => x !== d) })
      navigate('settings')
    }
    tag.appendChild(remove)
    domainList.appendChild(tag)
  }
  domainCard.appendChild(domainList)

  const domainAdd = el('div', { className: 'fmn-inline-add', style: 'margin-top:8px;' })
  const domainInput = el('input', { type: 'text', placeholder: 'Add category...' }) as HTMLInputElement
  domainInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && domainInput.value.trim()) {
      const val = domainInput.value.trim().toLowerCase()
      if (!settings.domains.includes(val)) {
        updateSettings({ domains: [...settings.domains, val] })
        navigate('settings')
      }
    }
  })
  domainAdd.appendChild(domainInput)
  domainCard.appendChild(domainAdd)
  container.appendChild(domainCard)

  // Theme
  const themeCard = el('div', { className: 'fmn-card' })
  themeCard.appendChild(sectionLabel('Theme'))

  themeCard.appendChild(settingsRow('Style', () => {
    const select = el('select', {}) as HTMLSelectElement
    for (const t of THEMES) {
      const opt = el('option', { value: t.name }, t.label)
      if (t.name === settings.themePreset) opt.selected = true
      select.appendChild(opt)
    }
    select.onchange = () => {
      const updated = updateSettings({ themePreset: select.value, customColors: {}, customBorderRadius: null, customFontSize: null, customSpacing: null })
      applyTheme(updated)
      navigate('settings')
    }
    return select
  }))

  // Theme advanced
  const themeAdvanced = collapsible('Customize', () => {
    const wrap = el('div', {})
    const resolved = resolveTheme(settings)

    wrap.appendChild(settingsRow('Corners', () => {
      const range = el('input', { type: 'range', value: String(resolved.borderRadius) }) as HTMLInputElement
      range.min = '0'
      range.max = '20'
      const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${resolved.borderRadius}px`)
      range.oninput = () => {
        label.textContent = `${range.value}px`
        applyTheme(updateSettings({ customBorderRadius: parseInt(range.value) }))
      }
      const row = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      row.appendChild(range)
      row.appendChild(label)
      return row
    }))

    wrap.appendChild(settingsRow('Text size', () => {
      const range = el('input', { type: 'range', value: String(resolved.fontSize) }) as HTMLInputElement
      range.min = '11'
      range.max = '20'
      const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${resolved.fontSize}px`)
      range.oninput = () => {
        label.textContent = `${range.value}px`
        applyTheme(updateSettings({ customFontSize: parseInt(range.value) }))
      }
      const row = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      row.appendChild(range)
      row.appendChild(label)
      return row
    }))

    wrap.appendChild(settingsRow('Spacing', () => {
      const select = el('select', {}) as HTMLSelectElement
      for (const s of ['compact', 'normal', 'relaxed']) {
        const opt = el('option', { value: s }, s)
        if (s === resolved.spacing) opt.selected = true
        select.appendChild(opt)
      }
      select.onchange = () => applyTheme(updateSettings({ customSpacing: select.value }))
      return select
    }))

    const colorLabels: { key: string; label: string }[] = [
      { key: 'accent', label: 'Accent' },
      { key: 'bg', label: 'Background' },
      { key: 'surface', label: 'Cards' },
      { key: 'text', label: 'Text' },
      { key: 'green', label: 'On track' },
      { key: 'orange', label: 'Warning' },
      { key: 'red', label: 'Overdue' },
    ]
    for (const { key, label } of colorLabels) {
      wrap.appendChild(settingsRow(label, () => {
        const input = el('input', { type: 'color', value: resolved.colors[key as keyof typeof resolved.colors], style: 'width:40px;height:28px;padding:0;border:none;cursor:pointer;' }) as HTMLInputElement
        input.oninput = () => applyTheme(updateSettings({ customColors: { ...settings.customColors, [key]: input.value } }))
        return input
      }))
    }

    return wrap
  })
  themeCard.appendChild(themeAdvanced)
  container.appendChild(themeCard)

  // Sound
  const soundCard = el('div', { className: 'fmn-card' })
  soundCard.appendChild(sectionLabel('Sound'))

  // Basic row: enabled toggle, preset dropdown, test button — all inline
  const soundBasicRow = el('div', { style: 'display:flex;align-items:center;gap:10px;flex-wrap:wrap;' })

  soundBasicRow.appendChild(toggle(settings.soundEnabled, (v) => updateSettings({ soundEnabled: v })))

  const presetSelect = el('select', { style: 'flex:1;min-width:100px;' }) as HTMLSelectElement
  for (const p of SOUND_PRESETS) {
    const opt = el('option', { value: String(p.value) }, p.label)
    if (p.value === settings.soundPreset) opt.selected = true
    presetSelect.appendChild(opt)
  }
  // If current preset isn't in the friendly list, add it
  if (!SOUND_PRESETS.some((p) => p.value === settings.soundPreset)) {
    const opt = el('option', { value: String(settings.soundPreset) }, `#${settings.soundPreset}`)
    opt.selected = true
    presetSelect.appendChild(opt)
  }
  presetSelect.onchange = () => { updateSettings({ soundPreset: parseInt(presetSelect.value) }); refreshSound() }
  soundBasicRow.appendChild(presetSelect)

  soundBasicRow.appendChild(createBtn('\u25B6', 'btn-ghost btn-sm', () => playTest()))

  soundCard.appendChild(soundBasicRow)

  // Sound advanced
  const soundAdvanced = collapsible('Fine-tune', () => {
    const wrap = el('div', {})

    wrap.appendChild(settingsRow('Preset #', () => {
      const input = el('input', { type: 'number', value: String(settings.soundPreset), style: 'width:60px;' }) as HTMLInputElement
      input.min = '0'
      input.max = '99'
      input.onchange = () => { updateSettings({ soundPreset: parseInt(input.value) }); refreshSound() }
      return input
    }))

    wrap.appendChild(settingsRow('BPM', () => {
      const range = el('input', { type: 'range', value: String(settings.soundBpm) }) as HTMLInputElement
      range.min = '60'
      range.max = '240'
      const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, String(settings.soundBpm))
      range.oninput = () => { label.textContent = range.value; updateSettings({ soundBpm: parseInt(range.value) }); refreshSound() }
      const row = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      row.appendChild(range)
      row.appendChild(label)
      return row
    }))

    wrap.appendChild(settingsRow('Volume', () => {
      const range = el('input', { type: 'range', value: String(Math.round(settings.soundVolume * 100)) }) as HTMLInputElement
      range.min = '0'
      range.max = '100'
      const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${Math.round(settings.soundVolume * 100)}%`)
      range.oninput = () => { label.textContent = `${range.value}%`; updateSettings({ soundVolume: parseInt(range.value) / 100 }); refreshSound() }
      const row = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
      row.appendChild(range)
      row.appendChild(label)
      return row
    }))

    wrap.appendChild(settingsRow('Mood', () => {
      const input = el('input', { type: 'number', value: String(settings.soundMode), style: 'width:60px;' }) as HTMLInputElement
      input.min = '0'
      input.max = '9'
      input.onchange = () => { updateSettings({ soundMode: parseInt(input.value) }); refreshSound() }
      return input
    }))

    return wrap
  })
  soundCard.appendChild(soundAdvanced)
  container.appendChild(soundCard)

  // Sync
  const syncCard = el('div', { className: 'fmn-card' })
  syncCard.appendChild(sectionLabel('Sync'))
  syncCard.appendChild(el('div', { style: 'font-size:13px;color:var(--dim);' }, 'Coming soon \u2014 sync your tasks across devices.'))
  container.appendChild(syncCard)

  // Data
  const dataCard = el('div', { className: 'fmn-card' })
  dataCard.appendChild(sectionLabel('Data'))

  const dataRow = el('div', { className: 'fmn-form-row' })

  dataRow.appendChild(createBtn('Export JSON', 'btn-ghost', () => {
    const data = exportAll()
    downloadJson(data, `forget-me-not-${new Date().toISOString().slice(0, 10)}.json`)
  }))

  const importBtn = createBtn('Import JSON', 'btn-ghost', () => {
    const fileInput = document.createElement('input')
    fileInput.type = 'file'
    fileInput.accept = '.json'
    fileInput.onchange = () => {
      const file = fileInput.files?.[0]
      if (!file) return
      const reader = new FileReader()
      reader.onload = () => {
        try {
          const result = importAll(reader.result as string)
          alert(`Imported ${result.tasks} tasks.`)
          navigate('panel')
        } catch {
          alert('Invalid JSON file.')
        }
      }
      reader.readAsText(file)
    }
    fileInput.click()
  })
  dataRow.appendChild(importBtn)

  dataRow.appendChild(createBtn('Clear All', 'btn-danger', () => {
    if (confirm('Delete all tasks and settings? This cannot be undone.')) {
      clearAll()
      navigate('panel')
    }
  }))

  dataCard.appendChild(dataRow)
  container.appendChild(dataCard)
}

function sectionLabel(text: string): HTMLElement {
  return el('div', { style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;' }, text)
}

function settingsRow(label: string, controlFactory: () => HTMLElement): HTMLElement {
  const row = el('div', { className: 'fmn-settings-row' })
  row.appendChild(el('span', { className: 'fmn-settings-label' }, label))
  const control = el('div', { className: 'fmn-settings-control' })
  control.appendChild(controlFactory())
  row.appendChild(control)
  return row
}

function collapsible(label: string, contentFactory: () => HTMLElement): HTMLElement {
  const wrap = el('div', { style: 'margin-top:8px;' })
  const trigger = el('button', { className: 'fmn-back', style: 'margin-bottom:0;font-size:12px;' }, `\u25B8 ${label}`)
  const content = el('div', { style: 'display:none;margin-top:4px;' })

  let open = false
  trigger.onclick = () => {
    open = !open
    content.style.display = open ? 'block' : 'none'
    trigger.textContent = open ? `\u25BE ${label}` : `\u25B8 ${label}`
    if (open && content.children.length === 0) {
      content.appendChild(contentFactory())
    }
  }

  wrap.appendChild(trigger)
  wrap.appendChild(content)
  return wrap
}

function toggle(checked: boolean, onChange: (val: boolean) => void): HTMLElement {
  const label = el('label', { className: 'fmn-toggle' })
  const input = el('input', { type: 'checkbox' }) as HTMLInputElement
  input.checked = checked
  input.onchange = () => onChange(input.checked)
  label.appendChild(input)
  label.appendChild(el('span', { className: 'fmn-toggle-track' }))
  label.appendChild(el('span', { className: 'fmn-toggle-thumb' }))
  return label
}

function createBtn(text: string, className: string, onClick: () => void): HTMLButtonElement {
  const btn = el('button', { className }, text) as HTMLButtonElement
  btn.onclick = onClick
  return btn
}
