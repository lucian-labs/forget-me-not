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

function startOfDay(d: Date): number {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
}

/** Calendar-day label relative to today: "Today", "Yesterday", "May 10", "Apr 28, 2024". */
export function dayLabel(iso: string): string {
  const d = new Date(iso)
  const today = startOfDay(new Date())
  const day = startOfDay(d)
  const diffDays = Math.round((today - day) / 86400000)
  if (diffDays === 0) return 'Today'
  if (diffDays === 1) return 'Yesterday'
  const sameYear = d.getFullYear() === new Date().getFullYear()
  const opts: Intl.DateTimeFormatOptions = sameYear
    ? { month: 'short', day: 'numeric' }
    : { month: 'short', day: 'numeric', year: 'numeric' }
  return d.toLocaleDateString(undefined, opts)
}

/** Stable per-day key for grouping. */
export function dayKey(iso: string): string {
  const d = new Date(iso)
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`
}

export function timeOfDay(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
}

interface StreakPip {
  ratio: number
  action: 'reset' | 'complete' | 'note' | 'lapsed'
  at: string
}

/** Color thresholds (shared by streak pips, progress sparkline, labels):
 *    ratio ≤ 1.20  → green   (safe zone, up to 120% of cadence)
 *    ratio ≤ 3.00  → yellow  (warning zone, 120%–300%)
 *    ratio  > 3.00 → red     (critical zone, past 300%)
 *  Lapsed always reads red regardless of ratio. */
const GREEN_MAX = 1.2
const YELLOW_MAX = 3.0

function pipColor(p: StreakPip): string {
  if (p.action === 'lapsed') return 'var(--red)'
  if (p.ratio <= GREEN_MAX) return 'var(--green)'
  if (p.ratio <= YELLOW_MAX) return 'var(--orange)'
  return 'var(--red)'
}

function pipLabel(p: StreakPip): string {
  const pct = Math.round(p.ratio * 100)
  if (p.action === 'lapsed') return `lapsed (${pct}%)`
  if (p.ratio <= GREEN_MAX) return `on time (${pct}%)`
  if (p.ratio <= YELLOW_MAX) return `late (${pct}%)`
  return `very late (${pct}%)`
}

/** Map a pip's state to a 0–1 bar height. Tallest = inside the safe zone;
 *  shorter as the cycle drifts further past it. */
function pipHeight(p: StreakPip): number {
  if (p.action === 'lapsed') return 0.2
  if (p.ratio <= GREEN_MAX) return 1.0     // safe band: full height
  if (p.ratio <= YELLOW_MAX) return 0.6    // warning band: half-ish
  return 0.3                               // critical band: short
}


// Shared cursor-following tooltip for the streak strip. Sized + styled via
// the existing .fmn-tip class — only the positioning model differs (tracks
// the mouse instead of anchoring to a fixed element rect).
let streakTip: HTMLElement | null = null
let streakHideTimer: number | null = null

function getStreakTip(): HTMLElement {
  if (!streakTip) {
    streakTip = document.createElement('div')
    streakTip.className = 'fmn-tip fmn-streak-tip'
    document.body.appendChild(streakTip)
  }
  return streakTip
}

function showStreakTip(text: string, cx: number, cy: number): void {
  const tip = getStreakTip()
  if (streakHideTimer) { clearTimeout(streakHideTimer); streakHideTimer = null }
  if (tip.textContent !== text) tip.textContent = text

  // Measure off-screen first, then position above the cursor with clearance.
  tip.style.left = '0px'
  tip.style.top = '0px'
  const tipRect = tip.getBoundingClientRect()
  const offset = 14
  let x = cx - tipRect.width / 2
  let y = cy - tipRect.height - offset
  x = Math.max(4, Math.min(x, window.innerWidth - tipRect.width - 4))
  y = Math.max(4, Math.min(y, window.innerHeight - tipRect.height - 4))
  tip.style.left = `${x}px`
  tip.style.top = `${y}px`
  if (!tip.classList.contains('fmn-tip-visible')) {
    requestAnimationFrame(() => tip.classList.add('fmn-tip-visible'))
  }
}

function hideStreakTip(): void {
  if (!streakTip) return
  if (streakHideTimer) clearTimeout(streakHideTimer)
  streakHideTimer = window.setTimeout(() => {
    streakTip?.classList.remove('fmn-tip-visible')
  }, 50)
}

/** Render a horizontal strip of cycle-history pips.
 *
 *  Right-aligned and full-width. Renders every pip into the DOM, then measures
 *  the available width via ResizeObserver and hides the oldest pips when they
 *  don't fit — surfacing a "+N" badge at the left of the visible cluster.
 *  Newest pip is always visible at the right edge.
 *
 *  The hover target is the entire chart strip (not the individual narrow pips)
 *  and the tooltip follows the cursor so it never sits under the user's
 *  pointer or off-screen on a tiny target.
 *
 *  Returns null if there are no pips to show. */
export function renderStreakStrip(pips: StreakPip[], large = false): HTMLElement | null {
  if (pips.length === 0) return null

  const strip = el('div', { className: `fmn-streak${large ? ' fmn-streak-lg' : ''}` })

  const moreBadge = el('span', { className: 'fmn-streak-more' })
  moreBadge.style.display = 'none'
  strip.appendChild(moreBadge)

  const pipNodes: HTMLElement[] = []
  const pipLabels: string[] = []
  for (let i = 0; i < pips.length; i++) {
    const p = pips[i]
    const pip = el('span', { className: 'fmn-streak-pip' })
    pip.style.background = pipColor(p)
    pip.style.setProperty('--h', String(pipHeight(p)))
    const when = new Date(p.at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
    pipLabels.push(`${pipLabel(p)} · ${when}`)
    // No per-pip data-tip — strip-level mousemove drives the tooltip so the
    // hover area is the whole chart height, not just the narrow colored bar.
    if (i === pips.length - 1) pip.classList.add('fmn-streak-pip-latest')
    pipNodes.push(pip)
    strip.appendChild(pip)
  }

  // Whole-chart hover: figure out which pip the cursor is over, update the
  // tip text + position on every move, fade out on leave.
  strip.addEventListener('mousemove', (e) => {
    const stripRect = strip.getBoundingClientRect()
    const cursorX = e.clientX

    // Skip when hovering the "+N" badge — there's no pip behind it.
    if (moreBadge.style.display !== 'none') {
      const badgeRect = moreBadge.getBoundingClientRect()
      if (cursorX >= badgeRect.left && cursorX <= badgeRect.right) {
        hideStreakTip()
        return
      }
    }

    // Pips are uniform width with gap 0, right-aligned. Compute the index by
    // walking inward from the right edge.
    const pipW = pipNodes[pipNodes.length - 1]?.offsetWidth || 4
    if (pipW <= 0) { hideStreakTip(); return }
    const xFromRight = stripRect.right - cursorX
    const indexFromEnd = Math.floor(xFromRight / pipW)
    const hoveredIdx = pipNodes.length - 1 - indexFromEnd
    if (hoveredIdx < 0 || hoveredIdx >= pipNodes.length) { hideStreakTip(); return }
    if (pipNodes[hoveredIdx].style.display === 'none') { hideStreakTip(); return }

    showStreakTip(pipLabels[hoveredIdx], cursorX, e.clientY)
  })

  strip.addEventListener('mouseleave', hideStreakTip)

  const markEnds = (firstVisibleIdx: number): void => {
    // Clear all end markers, then tag the leftmost-visible and rightmost pips
    // so CSS can round only the outer corners. With gap: 0 the inner pips look
    // like a single bar; the ends keep the radius for shape on the outside.
    for (const pip of pipNodes) {
      pip.classList.remove('fmn-streak-pip-end-left', 'fmn-streak-pip-end-right')
    }
    const lastIdx = pipNodes.length - 1
    if (firstVisibleIdx <= lastIdx) {
      pipNodes[firstVisibleIdx].classList.add('fmn-streak-pip-end-left')
      pipNodes[lastIdx].classList.add('fmn-streak-pip-end-right')
    }
  }

  const updateOverflow = (): void => {
    // Reset state on each measure pass
    for (const pip of pipNodes) pip.style.display = ''
    moreBadge.style.display = 'none'
    moreBadge.textContent = ''

    const stripWidth = strip.clientWidth
    if (stripWidth === 0) { markEnds(0); return }

    const cs = getComputedStyle(strip)
    // Robust gap parse: 0px is valid and must not fall through to the default.
    const parsedGap = parseFloat(cs.gap)
    const gap = Number.isFinite(parsedGap) ? parsedGap : (large ? 4 : 3)
    const pipWidth = pipNodes[0]?.offsetWidth || (large ? 10 : 6)
    const slot = pipWidth + gap

    const totalWidth = pipNodes.length * slot - (pipNodes.length > 0 ? gap : 0)
    if (totalWidth <= stripWidth) {
      markEnds(0)
      return
    }

    // Reserve room for the "+N" badge — render placeholder text so we measure
    // a realistic width rather than guess.
    moreBadge.style.display = ''
    moreBadge.textContent = `+${pipNodes.length}`
    const badgeWidth = moreBadge.offsetWidth + gap

    const available = stripWidth - badgeWidth
    const visibleCount = Math.max(0, Math.floor((available + gap) / slot))
    const hideCount = pipNodes.length - visibleCount

    if (hideCount <= 0) {
      moreBadge.style.display = 'none'
      moreBadge.textContent = ''
      markEnds(0)
      return
    }

    for (let i = 0; i < hideCount; i++) pipNodes[i].style.display = 'none'
    moreBadge.textContent = `+${hideCount}`
    markEnds(hideCount)
  }

  // Initial layout: defer one frame so the strip has been inserted and sized
  requestAnimationFrame(updateOverflow)

  if ('ResizeObserver' in window) {
    const ro = new ResizeObserver(updateOverflow)
    ro.observe(strip)
  }

  return strip
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
