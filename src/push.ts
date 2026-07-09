// Web Push client. Subscribes the browser to the fmn-push Cloudflare Worker and
// keeps it informed of each active task's next-due time, so the Worker's cron can
// deliver a notification even when the app is fully closed. Local in-SW alerts
// (sounds.ts / sw.js scheduleAlerts) still cover the app-open case.

import type { Task } from './types'
import { getTasks, getSettings } from './store'

// Public VAPID key (safe to ship). Private key lives only as a Worker secret.
const VAPID_PUBLIC_KEY = 'BGuVyu-qrtAg-SdnuhPbS_FjsVqDEwBiFIT9UNSLC1QDHY4Uvfncivoj0G5_JdYbG-_vqF8tERHW-U3HcXOXzfw'

// Push backend base URL (fmn-push Node service on the droplet). Override at
// runtime for testing: localStorage.setItem('fmn-push-endpoint', 'http://localhost:3900')
const DEFAULT_PUSH_API = 'https://push.lucianlabs.ca'
const PUSH_FLAG = 'fmn-push-enabled'

function pushApi(): string {
  return localStorage.getItem('fmn-push-endpoint') || DEFAULT_PUSH_API
}

function getDeviceId(): string {
  let id = localStorage.getItem('fmn-device-id')
  if (!id) {
    id = crypto.randomUUID()
    localStorage.setItem('fmn-device-id', id)
  }
  return id
}

export function isPushEnabled(): boolean {
  return localStorage.getItem(PUSH_FLAG) === '1'
}

export function isPushSupported(): boolean {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
}

function urlBase64ToUint8Array(base64: string): Uint8Array<ArrayBuffer> {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const b64 = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = atob(b64)
  const arr = new Uint8Array(new ArrayBuffer(raw.length))
  for (let i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i)
  return arr
}

// Epoch ms when a task next tips overdue, or null if it has no live schedule.
function nextDueMs(t: Task): number | null {
  if (t.recurring && t.instance) {
    return new Date(t.instance.startedAt).getTime() + t.instance.actualCadenceSeconds * 1000
  }
  if (t.dueDate) return new Date(t.dueDate).getTime()
  return null
}

interface ScheduleItem {
  id: string
  title: string
  nextDue: number
}

function activeSchedule(tasks: Task[]): ScheduleItem[] {
  const appName = getSettings().appName || 'forget me not'
  const items: ScheduleItem[] = []
  for (const t of tasks) {
    if (t.status === 'done' || t.status === 'archived' || t.status === 'cancelled') continue
    const due = nextDueMs(t)
    if (due === null) continue
    items.push({ id: t.id, title: t.title || appName, nextDue: due })
  }
  return items
}

// Enable push: request permission, subscribe, register with the backend, and
// push the current schedule. Returns true on success.
export async function enablePush(): Promise<boolean> {
  if (!isPushSupported()) return false
  const perm = await Notification.requestPermission()
  if (perm !== 'granted') return false

  const reg = await navigator.serviceWorker.ready
  let sub = await reg.pushManager.getSubscription()
  if (!sub) {
    sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
    })
  }

  const res = await fetch(`${pushApi()}/subscribe`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: getDeviceId(), subscription: sub.toJSON() }),
  })
  if (!res.ok) return false

  localStorage.setItem(PUSH_FLAG, '1')
  lastSig = '' // force the next sync to send
  syncPushSchedule(getTasks())
  return true
}

export async function disablePush(): Promise<void> {
  localStorage.setItem(PUSH_FLAG, '0')
  const deviceId = getDeviceId()
  try {
    const reg = await navigator.serviceWorker.ready
    const sub = await reg.pushManager.getSubscription()
    if (sub) await sub.unsubscribe()
  } catch {
    /* ignore */
  }
  try {
    await fetch(`${pushApi()}/unsubscribe`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId }),
    })
  } catch {
    /* ignore */
  }
}

// Push the current active schedule to the backend, debounced, and only when it
// actually changed (task added/removed/reset/snoozed shifts a next-due time).
let lastSig = ''
let debounce: number | null = null
export function syncPushSchedule(tasks: Task[]): void {
  if (!isPushEnabled()) return
  const sched = activeSchedule(tasks)
  const sig = JSON.stringify(sched.map((s) => [s.id, s.nextDue]))
  if (sig === lastSig) return
  lastSig = sig
  if (debounce) clearTimeout(debounce)
  debounce = window.setTimeout(() => {
    fetch(`${pushApi()}/schedule`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deviceId: getDeviceId(), tasks: sched }),
    }).catch(() => {
      lastSig = '' // let the next tick retry
    })
  }, 1500)
}
