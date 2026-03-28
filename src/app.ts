import type { View } from './types'
import { injectStyles } from './styles'
import { getSettings } from './store'
import { renderPanel } from './panel'
import { renderDetail } from './detail'
import { renderSettings } from './settings'
import { renderCreate } from './create'
import { initSound, requestNotificationPermission } from './sounds'
import { applyTheme } from './themes'

let currentView: View = 'panel'
let currentTaskId: string | null = null
let renderLoopId: number | null = null

export function navigate(view: View, taskId?: string): void {
  currentView = view
  currentTaskId = taskId ?? null
  render()
}

function render(): void {
  const app = document.getElementById('app')
  if (!app) return

  switch (currentView) {
    case 'panel':
      renderPanel(app)
      break
    case 'detail':
      if (currentTaskId) renderDetail(app, currentTaskId)
      break
    case 'settings':
      renderSettings(app)
      break
    case 'create':
      renderCreate(app)
      break
  }
}

function startRenderLoop(): void {
  if (renderLoopId) return
  renderLoopId = window.setInterval(() => {
    // Skip re-render if any input/textarea/select is focused — prevents keyboard destruction
    const active = document.activeElement
    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.tagName === 'SELECT')) return
    if (currentView === 'panel') render()
  }, 1000)
}

function initTheme(): void {
  applyTheme(getSettings())
}

async function init(): Promise<void> {
  injectStyles()
  initTheme()
  render()
  startRenderLoop()

  await initSound()

  // Request notification permission on first user interaction
  document.addEventListener('click', () => requestNotificationPermission(), { once: true })

  // Register service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {})
  }
}

init()
