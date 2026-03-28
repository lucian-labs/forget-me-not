import { getSettings } from './store'

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

export function playAlert(taskId: string): void {
  const settings = getSettings()
  if (!settings.soundEnabled || !notify) return
  if (alerted.get(taskId)) return
  alerted.set(taskId, true)
  notify.play(taskId)

  if (document.hidden && Notification.permission === 'granted') {
    new Notification('Forget Me Not', { body: 'A task is overdue!', icon: '/icon.svg' })
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
