import type { View } from './types'
import { injectStyles } from './styles'
import { getSettings } from './store'
import { renderPanel } from './panel'
import { renderDetail } from './detail'
import { renderSettings } from './settings'
import { renderCreate } from './create'
import { initSound, requestNotificationPermission } from './sounds'
import { applyTheme, getAllThemes, importThemeJson } from './themes'
import { updateSettings } from './store'

let currentView: View = 'panel'
let currentTaskId: string | null = null
let renderLoopId: number | null = null

function viewToHash(view: View, taskId?: string | null): string {
  switch (view) {
    case 'panel': return '#/'
    case 'settings': return '#/settings'
    case 'create': return '#/new'
    case 'detail': return `#/task/${taskId}`
  }
}

function hashToRoute(): { view: View; taskId: string | null } {
  const hash = location.hash.slice(1) || '/'
  if (hash === '/settings') return { view: 'settings', taskId: null }
  if (hash === '/new') return { view: 'create', taskId: null }
  if (hash.startsWith('/task/')) return { view: 'detail', taskId: hash.slice(6) }
  return { view: 'panel', taskId: null }
}

export function navigate(view: View, taskId?: string): void {
  const hash = viewToHash(view, taskId)
  if (location.hash !== hash) {
    location.hash = hash
  } else {
    // Same hash — just re-render
    currentView = view
    currentTaskId = taskId ?? null
    render()
  }
}

function onHashChange(): void {
  const route = hashToRoute()
  currentView = route.view
  currentTaskId = route.taskId
  render()
}

function render(): void {
  const app = document.getElementById('app')
  if (!app) return

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
    const active = document.activeElement
    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.tagName === 'SELECT')) return
    if (currentView === 'panel') render()
  }, 1000)
}

function initTheme(): void {
  const settings = getSettings()

  // Check query param for theme (e.g. ?theme=sakura or ?theme=base64...)
  const params = new URLSearchParams(location.search)
  const themeParam = params.get('theme')

  if (themeParam) {
    const result = applyThemeParam(themeParam, settings)
    if (result) return
  }

  // Check hash for theme (e.g. #theme=sakura or #theme=base64...)
  const hash = location.hash
  if (hash.startsWith('#theme=')) {
    const val = hash.slice(7)
    const result = applyThemeParam(val, settings)
    if (result) return
  }

  applyTheme(settings)
}

function applyThemeParam(param: string, settings: ReturnType<typeof getSettings>): boolean {
  // Try as theme name first
  const allThemes = getAllThemes(settings)
  const byName = allThemes.find((t) => t.name === param)
  if (byName) {
    applyTheme(updateSettings({ themePreset: byName.name }))
    return true
  }

  // Try as base64-encoded theme JSON
  try {
    const json = decodeURIComponent(escape(atob(param)))
    const theme = importThemeJson(json, settings)
    if (theme) {
      const userThemes = [...(settings.userThemes ?? []).filter((t) => t.name !== theme.name), theme]
      applyTheme(updateSettings({ userThemes, themePreset: theme.name }))
      return true
    }
  } catch {
    // not valid base64
  }

  return false
}

async function init(): Promise<void> {
  injectStyles()
  initTheme()

  const route = hashToRoute()
  currentView = route.view
  currentTaskId = route.taskId

  window.addEventListener('hashchange', onHashChange)

  render()
  startRenderLoop()

  await initSound()

  document.addEventListener('click', () => requestNotificationPermission(), { once: true })

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {})
  }

  const shopScript = document.createElement('script')
  shopScript.src = 'https://cdn.lucianlabs.ca/scripts/choppa-badge.js'
  document.body.appendChild(shopScript)
}

init()
