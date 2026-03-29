import { getSettings } from './store'
import type { Task } from './types'
import { appName } from './brand'

declare class YamaBruhNotify {
  constructor(opts: { seed: string; preset: number; bpm: number; volume: number; mode: number })
  play(id?: string): void
}

let notify: YamaBruhNotify | null = null
const alerted = new Map<string, boolean>()

let loaded = false
let keepAliveAudio: HTMLAudioElement | null = null
let keepAliveStarted = false

// Minimal silent WAV: 44-byte header + 2 bytes of silence (1 sample, mono, 8-bit)
const SILENT_WAV = 'data:audio/wav;base64,UklGRiYAAABXQVZFZm10IBAAAAABAAEARKwAAESsAAABAAgAZGF0YQIAAACA'

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

/**
 * Start a silent audio loop with media session registration.
 * Keeps the audio pipeline alive when the PWA is backgrounded,
 * allowing YamaBruh to play notification sounds in the background.
 * Must be called from a user gesture (click/tap).
 */
export function startKeepAlive(): void {
  if (keepAliveStarted) return
  keepAliveStarted = true

  keepAliveAudio = new Audio(SILENT_WAV)
  keepAliveAudio.loop = true
  keepAliveAudio.volume = 0.01

  keepAliveAudio.play().catch(() => {
    // Autoplay blocked — will retry on next interaction
    keepAliveStarted = false
  })

  // Register media session so OS treats us as an active audio app
  if ('mediaSession' in navigator) {
    navigator.mediaSession.metadata = new MediaMetadata({
      title: appName(),
      artist: 'Task Reminders',
      album: appName(),
    })
    // Prevent media controls from doing anything unexpected
    navigator.mediaSession.setActionHandler('play', () => {})
    navigator.mediaSession.setActionHandler('pause', () => {})
    navigator.mediaSession.setActionHandler('stop', () => {})
  }
}

export function stopKeepAlive(): void {
  if (keepAliveAudio) {
    keepAliveAudio.pause()
    keepAliveAudio.src = ''
    keepAliveAudio = null
  }
  keepAliveStarted = false
}

export function playAlert(taskId: string, task?: Task): void {
  const settings = getSettings()
  if (!settings.soundEnabled) return
  if (alerted.get(taskId)) return
  alerted.set(taskId, true)

  // Start keep-alive if not already running (piggybacks on this being called from render)
  if (!keepAliveStarted) startKeepAlive()

  // YamaBruh synth — with keep-alive, should work even when backgrounded
  if (notify) {
    notify.play(taskId)
  }

  // System notification as backup + visual alert
  if ('Notification' in window && Notification.permission === 'granted') {
    const title = task?.title ?? 'Task overdue'
    const opts: NotificationOptions & { renotify?: boolean } = {
      body: title,
      icon: '/icon.svg',
      tag: `fmn-${taskId}`,
      renotify: false,
      silent: false,
    }
    const n = new Notification(appName(), opts)
    if ('vibrate' in navigator) {
      navigator.vibrate([200, 100, 200])
    }
    n.onclick = () => {
      window.focus()
      n.close()
    }
  }
}

export function playTest(): void {
  if (!keepAliveStarted) startKeepAlive()
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
