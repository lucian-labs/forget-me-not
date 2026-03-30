export function formatTime(seconds: number): string {
  const abs = Math.abs(seconds)
  if (abs < 60) return `${Math.round(abs)}s`
  if (abs < 3600) return `${Math.round(abs / 60)}m`
  if (abs < 86400) {
    const h = Math.floor(abs / 3600)
    const m = Math.round((abs % 3600) / 60)
    return m > 0 ? `${h}h ${m}m` : `${h}h`
  }
  const d = Math.floor(abs / 86400)
  const h = Math.round((abs % 86400) / 3600)
  return h > 0 ? `${d}d ${h}h` : `${d}d`
}

export function formatCadence(seconds: number): string {
  const map: Record<number, string> = {
    900: '15m', 1800: '30m', 3600: '1h', 5400: '1.5h',
    7200: '2h', 14400: '4h', 28800: '8h', 86400: '1d',
    172800: '2d', 604800: '1w',
  }
  if (map[seconds]) return map[seconds]
  return formatTime(seconds)
}

export function timeAgo(iso: string): string {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.round(diff / 60)}m ago`
  if (diff < 86400) return `${Math.round(diff / 3600)}h ago`
  return `${Math.round(diff / 86400)}d ago`
}

export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attrs?: Record<string, string>,
  ...children: (Node | string)[]
): HTMLElementTagNameMap[K] {
  const elem = document.createElement(tag)
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      if (k === 'className') elem.className = v
      else if (k.startsWith('data-')) elem.setAttribute(k, v)
      else elem.setAttribute(k, v)
    }
  }
  for (const child of children) {
    elem.append(typeof child === 'string' ? document.createTextNode(child) : child)
  }
  return elem
}

export function downloadJson(data: string, filename: string): void {
  const blob = new Blob([data], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export const CADENCE_OPTIONS: { label: string; value: number }[] = [
  { label: '15 min', value: 900 },
  { label: '30 min', value: 1800 },
  { label: '1 hour', value: 3600 },
  { label: '1.5 hours', value: 5400 },
  { label: '2 hours', value: 7200 },
  { label: '4 hours', value: 14400 },
  { label: '8 hours', value: 28800 },
  { label: '1 day', value: 86400 },
  { label: '2 days', value: 172800 },
  { label: '1 week', value: 604800 },
]

export function createCadencePicker(currentSeconds: number | null, onChange: (seconds: number) => void): HTMLElement {
  const total = currentSeconds ?? 0
  const days = Math.floor(total / 86400)
  const hours = Math.floor((total % 86400) / 3600)
  const mins = Math.floor((total % 3600) / 60)

  const row = el('div', { style: 'display:flex;gap:6px;' })

  const dayOpts = [0, 1, 2, 3, 4, 5, 6, 7, 14, 28]
  const daySelect = el('select', { style: 'flex:1;' }) as HTMLSelectElement
  for (const d of dayOpts) {
    const o = el('option', { value: String(d) }, `${d}d`)
    if (d === days) o.selected = true
    daySelect.appendChild(o)
  }
  // If current value not in list, add it
  if (!dayOpts.includes(days) && days > 0) {
    const o = el('option', { value: String(days) }, `${days}d`)
    o.selected = true
    daySelect.appendChild(o)
  }

  const hourOpts = [0, 1, 2, 3, 4, 6, 8, 12]
  const hourSelect = el('select', { style: 'flex:1;' }) as HTMLSelectElement
  for (const h of hourOpts) {
    const o = el('option', { value: String(h) }, `${h}h`)
    if (h === hours) o.selected = true
    hourSelect.appendChild(o)
  }
  if (!hourOpts.includes(hours) && hours > 0) {
    const o = el('option', { value: String(hours) }, `${hours}h`)
    o.selected = true
    hourSelect.appendChild(o)
  }

  const minOpts = [0, 5, 10, 15, 30, 45, 55]
  const minSelect = el('select', { style: 'flex:1;' }) as HTMLSelectElement
  for (const m of minOpts) {
    const o = el('option', { value: String(m) }, `${m}m`)
    if (m === mins) o.selected = true
    minSelect.appendChild(o)
  }
  if (!minOpts.includes(mins) && mins > 0) {
    const o = el('option', { value: String(mins) }, `${mins}m`)
    o.selected = true
    minSelect.appendChild(o)
  }

  const fire = () => {
    const sec = parseInt(daySelect.value) * 86400 + parseInt(hourSelect.value) * 3600 + parseInt(minSelect.value) * 60
    onChange(sec || 60) // minimum 1 minute
  }
  daySelect.onchange = fire
  hourSelect.onchange = fire
  minSelect.onchange = fire

  row.appendChild(daySelect)
  row.appendChild(hourSelect)
  row.appendChild(minSelect)
  return row
}
