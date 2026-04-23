import { el, formatTime, formatCadence, timeAgo } from './utils'
import { navigate } from './app'

/**
 * Loops — concept landing + playground.
 *
 * The page has two halves:
 *   1. Concept section (top) — a visual demonstration of the loop model
 *      we've been shaping in plans/career-loops-concept.md. Serves as the
 *      reference until the aggregation pass collapses the three framings
 *      into one production model.
 *   2. Playground (bottom) — a throwaway CRUD so we can try the current
 *      data shape by hand. Storage isolated under fmn-loops.
 */

export type LoopCategory = 'personal' | 'professional' | 'creative' | 'mental' | 'physical' | 'money' | 'social' | 'other'

export interface Loop {
  id: string
  name: string
  category: LoopCategory
  cadenceSeconds: number
  description: string
  completions: string[] // ISO timestamps, oldest-first
  createdAt: string
}

const STORAGE_KEY = 'fmn-loops'

const CATEGORY_META: Record<LoopCategory, { label: string; color: string }> = {
  personal:     { label: 'personal',     color: '#f87171' }, // red — barrier-breaking against self
  professional: { label: 'professional', color: '#60a5fa' }, // blue — exposure to judgment
  creative:     { label: 'creative',     color: '#a78bfa' }, // purple — vulnerability in public
  // legacy categories still supported for existing loops in localStorage
  mental:       { label: 'mental',       color: '#a78bfa' },
  physical:     { label: 'physical',     color: '#f87171' },
  money:        { label: 'money',        color: '#34d399' },
  social:       { label: 'social',       color: '#60a5fa' },
  other:        { label: 'other',        color: '#9ca3af' },
}

const CADENCE_PRESETS: { label: string; seconds: number }[] = [
  { label: '1h',     seconds: 3600 },
  { label: '4h',     seconds: 14400 },
  { label: 'daily',  seconds: 86400 },
  { label: '2d',     seconds: 172800 },
  { label: 'weekly', seconds: 604800 },
]

function loadLoops(): Loop[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as Loop[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

function saveLoops(loops: Loop[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(loops))
}

function newId(): string {
  return 'loop-' + Math.random().toString(36).slice(2, 10)
}

function lastCompletion(loop: Loop): Date | null {
  if (loop.completions.length === 0) return null
  return new Date(loop.completions[loop.completions.length - 1])
}

function secondsUntilDue(loop: Loop): number {
  const last = lastCompletion(loop)
  if (!last) return 0
  const nextAt = last.getTime() + loop.cadenceSeconds * 1000
  return Math.round((nextAt - Date.now()) / 1000)
}

function streak(loop: Loop): number {
  if (loop.completions.length === 0) return 0
  const tolerance = loop.cadenceSeconds * 1500
  let count = 1
  for (let i = loop.completions.length - 1; i > 0; i--) {
    const gap = new Date(loop.completions[i]).getTime() - new Date(loop.completions[i - 1]).getTime()
    if (gap <= tolerance) count++
    else break
  }
  return count
}

// ---------------------------------------------------------------------------
// Page composition
// ---------------------------------------------------------------------------

export function renderLoops(container: HTMLElement): void {
  container.innerHTML = ''

  // Header
  const backBtn = el('button', { className: 'btn-ghost btn-sm', style: 'margin-right:8px;' }, '\u2190')
  backBtn.onclick = () => navigate('panel')

  const title = el('h1', { className: 'fmn-header-title' }, 'loops')

  const header = el('div', { className: 'fmn-header' },
    el('div', { style: 'display:flex;align-items:center;gap:8px;' }, backBtn, title),
    el('div', { className: 'fmn-header-actions' }),
  )
  container.appendChild(header)

  // Concept section (visual demo of the current loop model)
  container.appendChild(renderConcept())

  // Divider between "what a loop is" and "try one"
  container.appendChild(el('div', {
    style: 'margin:32px 0 16px;display:flex;align-items:center;gap:12px;',
  },
    el('div', { style: 'flex:1;height:1px;background:var(--border);' }),
    el('span', { style: 'font-size:10px;letter-spacing:2px;color:var(--dim);text-transform:uppercase;' }, 'playground'),
    el('div', { style: 'flex:1;height:1px;background:var(--border);' }),
  ))

  // Playground (live CRUD against localStorage)
  container.appendChild(renderPlayground())
}

// ---------------------------------------------------------------------------
// Concept section — visual forms of the loop model
// ---------------------------------------------------------------------------

function renderConcept(): HTMLElement {
  const root = el('div', { className: 'fmn-loops-concept', style: 'display:flex;flex-direction:column;gap:28px;margin-top:8px;' })

  root.appendChild(renderHero())
  root.appendChild(renderLoopVsTask())
  root.appendChild(renderCategories())
  root.appendChild(renderAnatomy())
  root.appendChild(renderCadenceTypes())
  root.appendChild(renderWorkedExamples())

  return root
}

function sectionHeader(eyebrow: string, title: string): HTMLElement {
  return el('div', { style: 'display:flex;flex-direction:column;gap:4px;margin-bottom:10px;' },
    el('span', {
      style: 'font-size:10px;letter-spacing:2px;color:var(--dim);text-transform:uppercase;',
    }, eyebrow),
    el('h2', { style: 'margin:0;font-size:18px;font-weight:600;letter-spacing:-0.2px;' }, title),
  )
}

function renderHero(): HTMLElement {
  return el('div', {
    style: 'border:1px solid var(--border);border-left:3px solid var(--accent);border-radius:10px;padding:20px;background:var(--surface);',
  },
    el('div', { style: 'font-size:11px;letter-spacing:2px;color:var(--accent);text-transform:uppercase;margin-bottom:8px;' }, 'the one-liner'),
    el('p', { style: 'margin:0;font-size:17px;line-height:1.5;font-style:italic;color:var(--text);' },
      '“A loop is a pre-committed structure that converts a resistance-laden decision into a mechanical rep — tracked by volume not outcome, at a pre-tiered stakes level, with the escape condition already defined.”'),
    el('p', { style: 'margin:12px 0 0;font-size:13px;color:var(--dim);line-height:1.5;' },
      'The block is always the decision, not the execution. Loops pre-decide what normally gets decided per-iteration, so what’s left is mechanical. The loop is the ', el('b', { style: 'color:var(--text);' }, 'behavior'), ' — the artifact is the byproduct that proves the rep happened.'),
  )
}

function renderLoopVsTask(): HTMLElement {
  const wrap = el('div', {})
  wrap.appendChild(sectionHeader('distinction', 'Loop vs. Task'))

  const cards = el('div', {
    style: 'display:grid;grid-template-columns:1fr 1fr;gap:10px;',
  })

  cards.appendChild(el('div', {
    style: 'border:1px solid var(--border);border-top:3px solid var(--accent);border-radius:10px;padding:14px;background:var(--surface);display:flex;flex-direction:column;gap:6px;',
  },
    el('div', { style: 'font-size:10px;letter-spacing:2px;color:var(--accent);text-transform:uppercase;' }, 'loop'),
    el('div', { style: 'font-weight:600;font-size:15px;' }, 'entered workout mode'),
    el('div', { style: 'font-size:12px;color:var(--dim);line-height:1.5;' },
      'A behavioral practice with a specific resistance attached. Evidence is the byproduct — 40 pushups, 45 the next day — proving the rep happened.'),
    el('div', { style: 'font-size:10px;color:var(--dim);margin-top:4px;' }, 'tracked by: repetition + evidence'),
  ))

  cards.appendChild(el('div', {
    style: 'border:1px solid var(--border);border-top:3px solid var(--dim);border-radius:10px;padding:14px;background:var(--surface);display:flex;flex-direction:column;gap:6px;',
  },
    el('div', { style: 'font-size:10px;letter-spacing:2px;color:var(--dim);text-transform:uppercase;' }, 'task'),
    el('div', { style: 'font-weight:600;font-size:15px;' }, 'do 40 pushups'),
    el('div', { style: 'font-size:12px;color:var(--dim);line-height:1.5;' },
      'A specific action to remember and complete. Evidence is optional; the doing is the point. Tasks can live inside a loop run — produced by it, not equal to it.'),
    el('div', { style: 'font-size:10px;color:var(--dim);margin-top:4px;' }, 'tracked by: done / not done'),
  ))

  wrap.appendChild(cards)
  return wrap
}

type CategoryDemo = {
  key: 'personal' | 'professional' | 'creative'
  title: string
  subtitle: string
  examples: { name: string; subtitle: string }[]
}

const CATEGORIES: CategoryDemo[] = [
  {
    key: 'personal',
    title: 'Personal',
    subtitle: 'Self-regulation, barrier-breaking against one’s own friction.',
    examples: [
      { name: 'Enter workout mode',    subtitle: 'byproduct: reps, session length' },
      { name: 'Get out the door',      subtitle: 'byproduct: leave-time, destinations' },
      { name: 'Wind down before bed',  subtitle: 'byproduct: sleep time, routine completed' },
    ],
  },
  {
    key: 'professional',
    title: 'Professional',
    subtitle: 'Career exposure, vulnerability to external judgment, making asks.',
    examples: [
      { name: 'Apply for a gig',           subtitle: 'byproduct: applications, responses, follow-ups' },
      { name: 'Cold outreach to a lead',   subtitle: 'byproduct: messages sent, replies, calls booked' },
      { name: 'Pitch an idea publicly',    subtitle: 'byproduct: posts, reactions, conversations' },
    ],
  },
  {
    key: 'creative',
    title: 'Creative',
    subtitle: 'Publishing, self-expression under exposure, making-for-others.',
    examples: [
      { name: 'Publish a piece',      subtitle: 'byproduct: posts, listings, audience reach' },
      { name: 'Ship a product rev',   subtitle: 'byproduct: shipped changes, changelog entries' },
      { name: 'Write in public',      subtitle: 'byproduct: essays, threads, newsletter sends' },
    ],
  },
]

function renderCategories(): HTMLElement {
  const wrap = el('div', {})
  wrap.appendChild(sectionHeader('three axes', '“Adulting plus” — personal, professional, creative'))

  const grid = el('div', { style: 'display:grid;grid-template-columns:repeat(auto-fit, minmax(240px, 1fr));gap:10px;' })
  for (const cat of CATEGORIES) {
    const color = CATEGORY_META[cat.key].color
    const card = el('div', {
      style: `border:1px solid var(--border);border-top:3px solid ${color};border-radius:10px;padding:14px;background:var(--surface);display:flex;flex-direction:column;gap:8px;`,
    })
    card.appendChild(el('div', { style: `font-size:10px;letter-spacing:2px;text-transform:uppercase;color:${color};` }, cat.title))
    card.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);line-height:1.5;' }, cat.subtitle))

    const list = el('div', { style: 'display:flex;flex-direction:column;gap:4px;margin-top:4px;border-top:1px dashed var(--border);padding-top:8px;' })
    for (const ex of cat.examples) {
      list.appendChild(el('div', { style: 'display:flex;flex-direction:column;' },
        el('span', { style: 'font-size:13px;font-weight:500;' }, ex.name),
        el('span', { style: 'font-size:10px;color:var(--dim);' }, ex.subtitle),
      ))
    }
    card.appendChild(list)
    grid.appendChild(card)
  }
  wrap.appendChild(grid)
  return wrap
}

const ANATOMY: { num: string; name: string; blurb: string }[] = [
  { num: '1', name: 'Cadence',          blurb: 'How often it fires — daily, weekly, bounded sprint, or event-triggered.' },
  { num: '2', name: 'Quantum',          blurb: 'The smallest indivisible complete unit. Never “work on X.” A specific countable thing.' },
  { num: '3', name: 'Selection rule',   blurb: 'How you pick this rep’s target. Mechanical, not judgmental. “First match,” not “best fit.”' },
  { num: '4', name: 'Stakes tier',      blurb: 'Training vs. real. Training lets you fail cheaply; real is reserved for higher-effort shots.' },
  { num: '5', name: 'Friction reducers', blurb: 'What’s explicitly deferred or reused — templates, price-on-request, same resumé every time.' },
  { num: '6', name: 'Rep counter',      blurb: 'Every attempt counts — including failures. Rejections are reps. Silence is a rep.' },
  { num: '7', name: 'Escape criterion', blurb: 'The conditional that levels you up. “After first sale → decide Stripe.” Prevents stuck training tier.' },
  { num: '8', name: 'Freeze antidote',  blurb: 'The named reframe that unlocks action. “List ≠ sell.” “Apply ≠ get hired.” Re-read when stuck.' },
]

function renderAnatomy(): HTMLElement {
  const wrap = el('div', {})
  wrap.appendChild(sectionHeader('components', 'Anatomy of a loop'))

  const grid = el('div', { style: 'display:grid;grid-template-columns:repeat(auto-fit, minmax(220px, 1fr));gap:8px;' })
  for (const a of ANATOMY) {
    const card = el('div', {
      style: 'border:1px solid var(--border);border-radius:10px;padding:12px;background:var(--surface);display:flex;flex-direction:column;gap:4px;',
    })
    card.appendChild(el('div', { style: 'display:flex;align-items:baseline;gap:8px;' },
      el('span', { style: 'font-size:10px;color:var(--dim);font-variant-numeric:tabular-nums;' }, a.num),
      el('span', { style: 'font-weight:600;font-size:13px;' }, a.name),
    ))
    card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);line-height:1.5;' }, a.blurb))
    grid.appendChild(card)
  }
  wrap.appendChild(grid)
  return wrap
}

const CADENCE_TYPES: { title: string; subtitle: string; example: string; tint: string }[] = [
  {
    title: 'Daily loops',
    subtitle: 'Habit-compounding. Low per-rep stakes. Training wheels.',
    example: '1 local job + 1 consulting outreach per day.',
    tint: '#34d399',
  },
  {
    title: 'Sprint loops',
    subtitle: 'Bounded volume burst. Medium stakes. Break freeze by overwhelming it.',
    example: '10 art pieces this weekend.',
    tint: '#fbbf24',
  },
  {
    title: 'Trigger loops',
    subtitle: 'Conditional, event-activated. Defers premature decisions.',
    example: 'After first sale → evaluate Stripe setup.',
    tint: '#60a5fa',
  },
]

function renderCadenceTypes(): HTMLElement {
  const wrap = el('div', {})
  wrap.appendChild(sectionHeader('cadence', 'Three types of firing'))

  const grid = el('div', { style: 'display:grid;grid-template-columns:repeat(auto-fit, minmax(220px, 1fr));gap:10px;' })
  for (const t of CADENCE_TYPES) {
    const card = el('div', {
      style: `border:1px solid var(--border);border-left:3px solid ${t.tint};border-radius:10px;padding:14px;background:var(--surface);display:flex;flex-direction:column;gap:6px;`,
    })
    card.appendChild(el('div', { style: 'font-weight:600;font-size:14px;' }, t.title))
    card.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);line-height:1.5;' }, t.subtitle))
    card.appendChild(el('div', {
      style: `margin-top:4px;font-size:11px;color:${t.tint};background:${t.tint}15;border:1px solid ${t.tint}33;border-radius:6px;padding:6px 8px;`,
    }, '\u2192 ' + t.example))
    grid.appendChild(card)
  }
  wrap.appendChild(grid)
  return wrap
}

type WorkedExample = {
  category: 'personal' | 'professional' | 'creative'
  name: string
  quantum: string
  selectionRule: string
  friction: string
  antidote: string
  byproducts: string
}

const WORKED: WorkedExample[] = [
  {
    category: 'creative',
    name: 'Publish creative work',
    quantum: '1 piece posted + listed',
    selectionRule: 'closest finished piece to the camera',
    friction: 'no pricing, no caption-optimization, same template',
    antidote: 'List ≠ sell. The act of publishing is the rep.',
    byproducts: 'posts, listings, reach, comments',
  },
  {
    category: 'professional',
    name: 'Apply for a gig',
    quantum: '1 application submitted',
    selectionRule: 'first listing matching 2+ skills on my shortlist',
    friction: 'no tailoring, same resumé, price-on-request',
    antidote: 'Apply ≠ get hired. The act of applying is the rep.',
    byproducts: 'applications, responses, follow-ups, interviews',
  },
  {
    category: 'personal',
    name: 'Enter workout mode',
    quantum: '1 session started (any duration)',
    selectionRule: 'whichever routine is already laid out',
    friction: 'clothes pre-laid, no program decision, playlist queued',
    antidote: 'Start ≠ finish. Getting past the wall is the rep.',
    byproducts: 'session log, reps done, duration',
  },
]

function renderWorkedExamples(): HTMLElement {
  const wrap = el('div', {})
  wrap.appendChild(sectionHeader('worked', 'The anatomy filled in'))

  const grid = el('div', { style: 'display:flex;flex-direction:column;gap:10px;' })
  for (const w of WORKED) {
    const color = CATEGORY_META[w.category].color
    const card = el('div', {
      style: `border:1px solid var(--border);border-left:3px solid ${color};border-radius:10px;padding:14px;background:var(--surface);display:flex;flex-direction:column;gap:8px;`,
    })

    card.appendChild(el('div', { style: 'display:flex;align-items:center;justify-content:space-between;gap:8px;' },
      el('div', { style: 'font-weight:600;font-size:15px;' }, w.name),
      el('span', {
        style: `font-size:10px;padding:2px 8px;border-radius:999px;background:${color}22;color:${color};border:1px solid ${color}44;`,
      }, w.category),
    ))

    const kv = (label: string, value: string) =>
      el('div', { style: 'display:grid;grid-template-columns:120px 1fr;gap:8px;font-size:12px;line-height:1.5;' },
        el('span', { style: 'color:var(--dim);text-transform:uppercase;font-size:10px;letter-spacing:1px;padding-top:2px;' }, label),
        el('span', { style: 'color:var(--text);' }, value),
      )

    card.appendChild(kv('Quantum',        w.quantum))
    card.appendChild(kv('Selection',      w.selectionRule))
    card.appendChild(kv('Friction cut',   w.friction))
    card.appendChild(kv('Antidote',       w.antidote))
    card.appendChild(kv('Byproducts',     w.byproducts))
    grid.appendChild(card)
  }
  wrap.appendChild(grid)
  return wrap
}

// ---------------------------------------------------------------------------
// Playground section (existing CRUD) — lets us touch the data shape by hand
// ---------------------------------------------------------------------------

function renderPlayground(): HTMLElement {
  const wrap = el('div', { style: 'display:flex;flex-direction:column;gap:8px;' })

  const loops = loadLoops()

  const toolbar = el('div', { style: 'display:flex;justify-content:space-between;align-items:center;' },
    el('div', { style: 'font-size:12px;color:var(--dim);' },
      loops.length === 0
        ? 'No loops saved yet. Add one to test the shape.'
        : `${loops.length} loop${loops.length === 1 ? '' : 's'} in localStorage.`),
    (() => {
      const addBtn = el('button', { className: 'btn-accent btn-sm' }, '+ new loop')
      addBtn.onclick = () => toggleForm(wrap)
      return addBtn
    })(),
  )
  wrap.appendChild(toolbar)

  // Inline create form slot
  wrap.appendChild(el('div', { className: 'fmn-loops-form-slot' }))

  // List
  const list = el('div', { className: 'fmn-loops-list', style: 'display:flex;flex-direction:column;gap:8px;margin-top:8px;' })
  wrap.appendChild(list)

  if (loops.length > 0) {
    const sorted = [...loops].sort((a, b) => secondsUntilDue(a) - secondsUntilDue(b))
    for (const loop of sorted) list.appendChild(renderLoopCard(loop))
  }

  return wrap
}

function renderLoopCard(loop: Loop): HTMLElement {
  const meta = CATEGORY_META[loop.category] ?? CATEGORY_META.other
  const due = secondsUntilDue(loop)
  const last = lastCompletion(loop)
  const s = streak(loop)

  const card = el('div', {
    className: 'fmn-loop-card',
    style: 'border:1px solid var(--border);border-radius:10px;padding:12px;background:var(--surface);display:flex;flex-direction:column;gap:6px;',
  })

  const titleRow = el('div', { style: 'display:flex;align-items:center;gap:8px;justify-content:space-between;' })
  const nameAndPill = el('div', { style: 'display:flex;align-items:center;gap:8px;flex:1;min-width:0;' })
  const name = el('span', { style: 'font-weight:600;font-size:15px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;' }, loop.name)
  const pill = el('span', {
    style: `font-size:10px;padding:2px 8px;border-radius:999px;background:${meta.color}22;color:${meta.color};border:1px solid ${meta.color}44;`,
  }, meta.label)
  nameAndPill.appendChild(name)
  nameAndPill.appendChild(pill)

  const delBtn = el('button', { className: 'btn-ghost btn-sm', title: 'delete loop', style: 'opacity:0.5;' }, '\u00d7')
  delBtn.onclick = () => {
    if (!confirm(`Delete loop "${loop.name}"?`)) return
    const all = loadLoops().filter((l) => l.id !== loop.id)
    saveLoops(all)
    navigate('loops')
  }

  titleRow.appendChild(nameAndPill)
  titleRow.appendChild(delBtn)

  card.appendChild(titleRow)
  if (loop.description) {
    card.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);' }, loop.description))
  }

  const statsRow = el('div', { style: 'display:flex;gap:14px;font-size:11px;color:var(--dim);flex-wrap:wrap;' })
  statsRow.appendChild(el('span', {}, `every ${formatCadence(loop.cadenceSeconds)}`))
  statsRow.appendChild(el('span', {}, `streak: ${s}`))
  statsRow.appendChild(el('span', {}, `done: ${loop.completions.length}`))
  statsRow.appendChild(el('span', {}, last ? `last: ${timeAgo(last.toISOString())}` : 'never done'))
  card.appendChild(statsRow)

  const dueText = due <= 0
    ? el('span', { style: 'color:var(--red);font-weight:600;' }, due <= -3600 ? `overdue ${formatTime(-due)}` : 'due now')
    : el('span', { style: 'color:var(--dim);' }, `due in ${formatTime(due)}`)

  const actionRow = el('div', { style: 'display:flex;align-items:center;gap:8px;margin-top:4px;' })
  const doneBtn = el('button', { className: 'btn-accent btn-sm' }, '\u2713 did it')
  doneBtn.onclick = () => {
    const all = loadLoops()
    const target = all.find((l) => l.id === loop.id)
    if (!target) return
    target.completions.push(new Date().toISOString())
    saveLoops(all)
    navigate('loops')
  }
  actionRow.appendChild(doneBtn)
  actionRow.appendChild(dueText)
  card.appendChild(actionRow)

  return card
}

function toggleForm(wrap: HTMLElement): void {
  const slot = wrap.querySelector('.fmn-loops-form-slot') as HTMLElement
  if (!slot) return
  if (slot.firstChild) {
    slot.innerHTML = ''
    return
  }

  const nameInput = el('input', { type: 'text', placeholder: 'loop name (e.g. "publish creative work")', className: 'fmn-input' }) as HTMLInputElement
  const descInput = el('input', { type: 'text', placeholder: 'optional description', className: 'fmn-input' }) as HTMLInputElement

  const catSelect = el('select', { className: 'fmn-input' }) as HTMLSelectElement
  for (const key of ['personal', 'professional', 'creative'] as LoopCategory[]) {
    const opt = el('option', { value: key }, CATEGORY_META[key].label)
    catSelect.appendChild(opt)
  }

  const cadSelect = el('select', { className: 'fmn-input' }) as HTMLSelectElement
  for (const preset of CADENCE_PRESETS) {
    const opt = el('option', { value: String(preset.seconds) }, preset.label)
    cadSelect.appendChild(opt)
  }
  cadSelect.value = '86400'

  const row = (...kids: HTMLElement[]) =>
    el('div', { style: 'display:flex;gap:8px;' }, ...kids)

  const saveBtn = el('button', { className: 'btn-accent btn-sm' }, 'save')
  saveBtn.onclick = () => {
    const name = nameInput.value.trim()
    if (!name) {
      nameInput.focus()
      return
    }
    const loop: Loop = {
      id: newId(),
      name,
      description: descInput.value.trim(),
      category: catSelect.value as LoopCategory,
      cadenceSeconds: parseInt(cadSelect.value, 10) || 86400,
      completions: [],
      createdAt: new Date().toISOString(),
    }
    const all = loadLoops()
    all.push(loop)
    saveLoops(all)
    navigate('loops')
  }

  const cancelBtn = el('button', { className: 'btn-ghost btn-sm' }, 'cancel')
  cancelBtn.onclick = () => { slot.innerHTML = '' }

  const form = el('div', {
    style: 'border:1px solid var(--border);border-radius:10px;padding:12px;margin-top:8px;display:flex;flex-direction:column;gap:8px;background:var(--surface);',
  },
    nameInput,
    descInput,
    row(catSelect, cadSelect),
    row(saveBtn, cancelBtn),
  )

  slot.appendChild(form)
  nameInput.focus()
}
