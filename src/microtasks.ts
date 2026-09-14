// Overdue microtasks. A task's `prompts` used to surface as one rotating line of
// text; now they populate a small checklist that grows the longer the task sits
// overdue — one step at first, another every quarter-cycle past due. One tiny
// thing to start is the point; the list only gets longer if you're still stuck.

import type { Task } from './types'
import { el } from './utils'

const STORE_KEY = 'fmn-microtasks'
const STEP = 0.25 // one more item per 25% of the cycle past due

type DoneMap = Record<string, { cycle: string; done: string[] }>

function readDone(): DoneMap {
  try { return JSON.parse(localStorage.getItem(STORE_KEY) || '{}') as DoneMap } catch { return {} }
}

function writeDone(map: DoneMap): void {
  localStorage.setItem(STORE_KEY, JSON.stringify(map))
}

/** Identifies the current cycle, so ticks reset when the loop does. */
function cycleKey(task: Task): string {
  return task.instance?.startedAt ?? task.dueDate ?? task.createdAt
}

/** Stable per-cycle order: same list across re-renders, a fresh shuffle each cycle. */
function orderFor(task: Task): string[] {
  let seed = 0
  for (const ch of task.id + cycleKey(task)) seed = (seed * 31 + ch.charCodeAt(0)) | 0
  const rand = (): number => {
    seed = (seed * 1103515245 + 12345) | 0
    return ((seed >>> 0) % 10000) / 10000
  }
  const items = [...new Set(task.prompts.map((p) => p.trim()).filter(Boolean))]
  for (let i = items.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1))
    ;[items[i], items[j]] = [items[j], items[i]]
  }
  return items
}

export function visibleMicrotasks(task: Task, ratio: number): string[] {
  if (ratio < 1 || !task.prompts?.length) return []
  const order = orderFor(task)
  return order.slice(0, Math.min(order.length, 1 + Math.floor((ratio - 1) / STEP)))
}

function doneFor(task: Task): Set<string> {
  const entry = readDone()[task.id]
  return new Set(entry && entry.cycle === cycleKey(task) ? entry.done : [])
}

function toggle(task: Task, item: string): void {
  const map = readDone()
  const done = doneFor(task)
  if (done.has(item)) done.delete(item)
  else done.add(item)
  map[task.id] = { cycle: cycleKey(task), done: [...done] }
  writeDone(map)
}

/** Signature of what's on screen, so the 1s tick only rebuilds when it changes. */
function signature(task: Task, ratio: number): string {
  const done = doneFor(task)
  return visibleMicrotasks(task, ratio).map((m) => (done.has(m) ? '+' : '-') + m).join('|')
}

export function renderMicrotasks(task: Task, ratio: number): HTMLElement | null {
  const items = visibleMicrotasks(task, ratio)
  if (!items.length) return null
  const done = doneFor(task)
  const list = el('ul', { className: 'fmn-micro' })
  list.dataset.sig = signature(task, ratio)
  for (const item of items) {
    const li = el('li', { className: done.has(item) ? 'fmn-micro-item fmn-micro-done' : 'fmn-micro-item' })
    li.appendChild(el('span', { className: 'fmn-micro-box' }, done.has(item) ? '✓' : ''))
    li.appendChild(el('span', { className: 'fmn-micro-text' }, item))
    li.addEventListener('click', (e) => {
      e.stopPropagation()
      toggle(task, item)
      const fresh = renderMicrotasks(task, ratio)
      if (fresh) list.replaceWith(fresh)
    })
    list.appendChild(li)
  }
  return list
}

/** Tick-time update: insert, grow, or remove the list without a full re-render. */
export function syncMicrotasks(card: HTMLElement, task: Task, ratio: number): void {
  const existing = card.querySelector<HTMLElement>('.fmn-micro')
  const sig = signature(task, ratio)
  if (!sig) { existing?.remove(); return }
  if (existing?.dataset.sig === sig) return
  const fresh = renderMicrotasks(task, ratio)
  if (!fresh) return
  if (existing) { existing.replaceWith(fresh); return }
  card.querySelector('.fmn-task-row')?.after(fresh)
}
