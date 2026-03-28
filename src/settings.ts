import { getSettings, updateSettings, exportAll, importAll, clearAll } from './store'
import { el, downloadJson } from './utils'
import { refreshSound } from './sounds'
import { navigate } from './app'

export function renderSettings(container: HTMLElement): void {
  const settings = getSettings()
  container.innerHTML = ''

  // Back
  const back = el('button', { className: 'fmn-back' }, '\u2190 back')
  back.onclick = () => navigate('panel')
  container.appendChild(back)

  container.appendChild(el('div', { className: 'fmn-section' }, 'Settings'))

  // Theme
  const themeCard = el('div', { className: 'fmn-card' })
  themeCard.appendChild(settingsRow('Theme', () => {
    const select = el('select', {}) as HTMLSelectElement
    select.appendChild(el('option', { value: 'dark' }, 'Dark'))
    select.appendChild(el('option', { value: 'light' }, 'Light'))
    select.value = settings.theme
    select.onchange = () => {
      updateSettings({ theme: select.value as 'dark' | 'light' })
      document.documentElement.setAttribute('data-theme', select.value)
    }
    return select
  }))
  container.appendChild(themeCard)

  // Sound
  const soundCard = el('div', { className: 'fmn-card' })
  soundCard.appendChild(el('div', { style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;' }, 'Sound'))

  soundCard.appendChild(settingsRow('Enabled', () => toggle(settings.soundEnabled, (v) => updateSettings({ soundEnabled: v }))))

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

  // Domains
  const domainCard = el('div', { className: 'fmn-card' })
  domainCard.appendChild(el('div', { style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;' }, 'Domains'))

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
  const domainInput = el('input', { type: 'text', placeholder: 'Add domain...' }) as HTMLInputElement
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
  syncCard.appendChild(el('div', { style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;' }, 'Sync (Experimental)'))

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
    'Configure your own sync endpoint. Data stays on your device until you enable sync. Like Obsidian — you own the pipe.'))

  container.appendChild(syncCard)

  // Data
  const dataCard = el('div', { className: 'fmn-card' })
  dataCard.appendChild(el('div', { style: 'font-size:12px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--dim);margin-bottom:8px;' }, 'Data'))

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
        } catch (err) {
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
