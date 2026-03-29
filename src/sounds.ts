import { getSettings } from './store'
import type { Task } from './types'

declare class YamaBruhNotify {
  constructor(opts: { seed: string; preset: number; bpm: number; volume: number; mode: number })
  play(id?: string): void
}

let notify: YamaBruhNotify | null = null
const alerted = new Map<string, boolean>()

let loaded = false

function loadScript(): Promise<void> {
  if (loaded) return Promise.resolve()
  return new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = 'https://cdn.lucianlabs.ca/scripts/yamabruh-notify.js'
    s.onload = () => { loaded = true; resolve() }
    s.onerror = () => reject(new Error('Failed to load YamaBruh'))
    document.head.appendChild(s)
  })
}

export async function initSound(): Promise<void> {
  try {
    await loadScript()
    const settings = getSettings()
    notify = new (window as any).YamaBruhNotify({
      seed: 'forgetmenot',
      preset: settings.soundPreset,
      bpm: settings.soundBpm,
      volume: settings.soundVolume,
      mode: settings.soundMode,
    })
  } catch {
    // sound is optional
  }
}

export function refreshSound(): void {
  if (!loaded) return
  const settings = getSettings()
  notify = new (window as any).YamaBruhNotify({
    seed: 'forgetmenot',
    preset: settings.soundPreset,
    bpm: settings.soundBpm,
    volume: settings.soundVolume,
    mode: settings.soundMode,
  })
}

export function playAlert(taskId: string, task?: Task): void {
  const settings = getSettings()
  if (!settings.soundEnabled) return
  if (alerted.get(taskId)) return
  alerted.set(taskId, true)

  // Web Audio synth — only works in foreground
  if (notify && !document.hidden) {
    notify.play(taskId)
  }

  // System notification — works in background, plays device notification sound
  if ('Notification' in window && Notification.permission === 'granted') {
    const title = task?.title ?? 'Task overdue'
    const opts: NotificationOptions & { renotify?: boolean } = {
      body: title,
      icon: '/icon.svg',
      tag: `fmn-${taskId}`,
      renotify: false,
      silent: false,
    }
    const n = new Notification('Forget Me Not', opts)
    // Vibrate on supported devices
    if ('vibrate' in navigator) {
      navigator.vibrate([200, 100, 200])
    }
    // Tap notification → focus app
    n.onclick = () => {
      window.focus()
      n.close()
    }
  }
}

export function playTest(): void {
  if (!notify) return
  notify.play('test-' + Date.now())
}

export function clearAlert(taskId: string): void {
  alerted.delete(taskId)
}

export function requestNotificationPermission(): void {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission()
  }
}
