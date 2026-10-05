// Overdue hints. A task's `prompts` surface as plain-text hints once the task
// hits its deadline, one at a time, rotating every 10s. They are hints, not a
// checklist: nothing to tick, nothing stored.

import type { Task } from './types'
import { el } from './utils'


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

/** One hint at a time, rotating every 10s through this cycle's shuffled order. */
export function visibleMicrotasks(task: Task, ratio: number): string[] {
  if (ratio < 1 || !task.prompts?.length) return []
  const order = orderFor(task)
  return [order[Math.floor(Date.now() / 10000) % order.length]]
}

/** Signature of what's on screen, so the 1s tick only rebuilds when it changes. */
function signature(task: Task, ratio: number): string {
  return visibleMicrotasks(task, ratio).join('|')
}

export function renderMicrotasks(task: Task, ratio: number): HTMLElement | null {
  const items = visibleMicrotasks(task, ratio)
  if (!items.length) return null
  const list = el('ul', { className: 'fmn-micro' })
  list.dataset.sig = signature(task, ratio)
  for (const item of items) {
    list.appendChild(el('li', { className: 'fmn-micro-item' }, `? ${item}`))
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
