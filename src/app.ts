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

  // Ensure shell structure: .fmn-content + .fmn-footer
  let content = app.querySelector('.fmn-content') as HTMLElement
  if (!content) {
    app.innerHTML = ''
    content = document.createElement('div')
    content.className = 'fmn-content'
    app.appendChild(content)

    const footer = document.createElement('footer')
    footer.className = 'fmn-footer'
    footer.innerHTML = 'by <a href="https://lucianlabs.ca" target="_blank" rel="noopener">lucianlabs.ca</a> · <a href="https://github.com/lucian-labs/forget-me-not" target="_blank" rel="noopener">source code</a>'
    app.appendChild(footer)
  }

  switch (currentView) {
    case 'panel':
      renderPanel(content)
      break
    case 'detail':
      if (currentTaskId) renderDetail(content, currentTaskId)
      break
    case 'settings':
      renderSettings(content)
      break
    case 'create':
      renderCreate(content)
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

  // Lucian Labs shop widget
  const shopScript = document.createElement('script')
  shopScript.src = 'https://cdn.lucianlabs.ca/scripts/choppa-badge.js'
  document.body.appendChild(shopScript)
}

init()
