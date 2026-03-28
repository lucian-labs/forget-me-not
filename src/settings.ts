import { getSettings, updateSettings, exportAll, importAll, clearAll } from './store'
import { el, downloadJson } from './utils'
import { refreshSound, playTest } from './sounds'
import { THEMES, applyTheme, resolveTheme } from './themes'
import { navigate } from './app'

export function renderSettings(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  // Back
  const back = el('button', { className: 'fmn-back' }, '\u2190 back')
  back.onclick = () => navigate('panel')
  container.appendChild(back)

  container.appendChild(el('div', { className: 'fmn-section' }, 'Settings'))

  // Theme presets
  const themeCard = el('div', { className: 'fmn-card' })
  themeCard.appendChild(sectionLabel('Theme'))

  themeCard.appendChild(settingsRow('Preset', () => {
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

  // Customization
  const resolved = resolveTheme(settings)

  themeCard.appendChild(settingsRow('Corners', () => {
    const range = el('input', { type: 'range', value: String(resolved.borderRadius) }) as HTMLInputElement
    range.min = '0'
    range.max = '20'
    const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${resolved.borderRadius}px`)
    range.oninput = () => {
      label.textContent = `${range.value}px`
      const updated = updateSettings({ customBorderRadius: parseInt(range.value) })
      applyTheme(updated)
    }
    const wrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
    wrap.appendChild(range)
    wrap.appendChild(label)
    return wrap
  }))

  themeCard.appendChild(settingsRow('Text size', () => {
    const range = el('input', { type: 'range', value: String(resolved.fontSize) }) as HTMLInputElement
    range.min = '11'
    range.max = '20'
    const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${resolved.fontSize}px`)
    range.oninput = () => {
      label.textContent = `${range.value}px`
      const updated = updateSettings({ customFontSize: parseInt(range.value) })
      applyTheme(updated)
    }
    const wrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
    wrap.appendChild(range)
    wrap.appendChild(label)
    return wrap
  }))

  themeCard.appendChild(settingsRow('Spacing', () => {
    const select = el('select', {}) as HTMLSelectElement
    for (const s of ['compact', 'normal', 'relaxed']) {
      const opt = el('option', { value: s }, s)
      if (s === resolved.spacing) opt.selected = true
      select.appendChild(opt)
    }
    select.onchange = () => {
      const updated = updateSettings({ customSpacing: select.value })
      applyTheme(updated)
    }
    return select
  }))

  // Color pickers
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
    themeCard.appendChild(settingsRow(label, () => {
      const input = el('input', { type: 'color', value: resolved.colors[key as keyof typeof resolved.colors], style: 'width:40px;height:28px;padding:0;border:none;cursor:pointer;' }) as HTMLInputElement
      input.oninput = () => {
        const updated = updateSettings({ customColors: { ...settings.customColors, [key]: input.value } })
        applyTheme(updated)
      }
      return input
    }))
  }

  container.appendChild(themeCard)

  // Sound
  const soundCard = el('div', { className: 'fmn-card' })
  soundCard.appendChild(sectionLabel('Sound'))

  soundCard.appendChild(settingsRow('Enabled', () => toggle(settings.soundEnabled, (v) => updateSettings({ soundEnabled: v }))))

  soundCard.appendChild(settingsRow('Test', () => createBtn('\u25B6 Play', 'btn-ghost btn-sm', () => playTest())))

  soundCard.appendChild(settingsRow('Preset', () => {
    const input = el('input', { type: 'number', value: String(settings.soundPreset), style: 'width:60px;' }) as HTMLInputElement
    input.min = '0'
    input.max = '98'
    input.onchange = () => { updateSettings({ soundPreset: parseInt(input.value) }); refreshSound() }
    return input
  }))

  soundCard.appendChild(settingsRow('BPM', () => {
    const range = el('input', { type: 'range', value: String(settings.soundBpm) }) as HTMLInputElement
    range.min = '60'
    range.max = '240'
    const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, String(settings.soundBpm))
    range.oninput = () => { label.textContent = range.value; updateSettings({ soundBpm: parseInt(range.value) }); refreshSound() }
    const wrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
    wrap.appendChild(range)
    wrap.appendChild(label)
    return wrap
  }))

  soundCard.appendChild(settingsRow('Volume', () => {
    const range = el('input', { type: 'range', value: String(Math.round(settings.soundVolume * 100)) }) as HTMLInputElement
    range.min = '0'
    range.max = '100'
    const label = el('span', { style: 'font-size:12px;color:var(--dim);width:30px;' }, `${Math.round(settings.soundVolume * 100)}%`)
    range.oninput = () => { label.textContent = `${range.value}%`; updateSettings({ soundVolume: parseInt(range.value) / 100 }); refreshSound() }
    const wrap = el('div', { style: 'display:flex;align-items:center;gap:8px;' })
    wrap.appendChild(range)
    wrap.appendChild(label)
    return wrap
  }))

  soundCard.appendChild(settingsRow('Mood', () => {
    const input = el('input', { type: 'number', value: String(settings.soundMode), style: 'width:60px;' }) as HTMLInputElement
    input.min = '0'
    input.max = '9'
    input.onchange = () => { updateSettings({ soundMode: parseInt(input.value) }); refreshSound() }
    return input
  }))

  container.appendChild(soundCard)

  // Categories
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

  // Sync config
  const syncCard = el('div', { className: 'fmn-card' })
  syncCard.appendChild(sectionLabel('Sync (Experimental)'))

  syncCard.appendChild(settingsRow('Enabled', () => toggle(settings.syncEnabled, (v) => {
    updateSettings({ syncEnabled: v })
    navigate('settings')
  })))

  const endpointGroup = el('div', { className: 'fmn-form-group', style: 'margin-top:8px;' })
  endpointGroup.appendChild(el('label', {}, 'Endpoint URL'))
  const endpointInput = el('input', { type: 'text', placeholder: 'https://your-server.com/sync', value: settings.syncEndpoint }) as HTMLInputElement
  endpointInput.onblur = () => updateSettings({ syncEndpoint: endpointInput.value })
  endpointGroup.appendChild(endpointInput)
  syncCard.appendChild(endpointGroup)

  const keyGroup = el('div', { className: 'fmn-form-group' })
  keyGroup.appendChild(el('label', {}, 'API Key'))
  const keyInput = el('input', { type: 'password', placeholder: 'your-api-key', value: settings.syncApiKey }) as HTMLInputElement
  keyInput.onblur = () => updateSettings({ syncApiKey: keyInput.value })
  keyGroup.appendChild(keyInput)
  syncCard.appendChild(keyGroup)

  syncCard.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin-top:4px;' },
    'Configure your own sync endpoint. Data stays on your device until you enable sync. Like Obsidian \u2014 you own the pipe.'))

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
