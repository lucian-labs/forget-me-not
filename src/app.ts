import type { View } from './types'
import { injectStyles } from './styles'
import { getSettings, getTasks, getUrgencyRatio, checkDoubleLapsed } from './store'
import { renderPanel, updatePanelTimers, isSleepMode } from './panel'
import { renderDetail } from './detail'
import { renderSettings } from './settings'
import { renderCreate } from './create'
import { renderShare } from './share'
import { initSound, requestNotificationPermission, playAlert, clearAlert, syncAlertsToSW } from './sounds'
import { applyTheme, getAllThemes, importThemeJson, THEMES } from './themes'
import { updateSettings, isFirstRun } from './store'
import { checkImportFromUrl } from './transfer'
import { applyIcon } from './icon'
import { renderVibe } from './taskyeet'
import { loadSeedIfEmpty } from './seed'

let currentView: View = 'panel'
let currentTaskId: string | null = null
let renderLoopId: number | null = null

function viewToPath(view: View, taskId?: string | null): string {
  switch (view) {
    case 'panel': return '/'
    case 'settings': return '/settings'
    case 'share': return '/settings/share'
    case 'create': return '/new'
    case 'detail': return `/task/${taskId}`
    case 'taskyeet': return '/vibe'
  }
}

function pathToRoute(): { view: View; taskId: string | null } {
  const path = location.pathname
  if (path === '/vibe') return { view: 'taskyeet', taskId: null }
  if (path === '/settings/share') return { view: 'share', taskId: null }
  if (path === '/settings') return { view: 'settings', taskId: null }
  if (path === '/new') return { view: 'create', taskId: null }
  if (path.startsWith('/task/')) return { view: 'detail', taskId: path.slice(6) }
  return { view: 'panel', taskId: null }
}

export function navigate(view: View, taskId?: string): void {
  const path = viewToPath(view, taskId)
  if (location.pathname !== path) {
    history.pushState(null, '', path)
  }
  currentView = view
  currentTaskId = taskId ?? null
  render()
  // Sync alerts after task mutations (reset, complete, snooze, etc.)
  lastSyncCount = -1
}

function onPopState(): void {
  const route = pathToRoute()
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
    footer.innerHTML = `v${__APP_VERSION__} <span class="fmn-sw-version"></span> · by <a href="https://lucianlabs.ca" target="_blank" rel="noopener">lucianlabs.ca</a> · <a href="https://github.com/lucian-labs/forget-me-not" target="_blank" rel="noopener">source code</a> · <a href="/vibe" style="opacity:0.5;">\u2726 vibe</a>`
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
    case 'share':
      renderShare(content)
      break
    case 'taskyeet':
      renderVibe(content)
      break
  }
}

const alertedIds = new Set<string>()
let lastSyncCount = -1

function checkAlerts(): void {
  // Auto-reset tasks overdue for 2x their cadence — restarts the notification loop
  if (!isSleepMode()) checkDoubleLapsed()

  const tasks = getTasks().filter((t) => t.status !== 'done' && t.status !== 'archived' && t.status !== 'cancelled')
  for (const task of tasks) {
    const ratio = getUrgencyRatio(task)
    if (ratio >= 1.0) {
      alertedIds.add(task.id)
      playAlert(task.id, task)
    } else if (alertedIds.has(task.id)) {
      alertedIds.delete(task.id)
      clearAlert(task.id)
    }
  }
  // Sync to SW periodically (every 10 ticks) to avoid flooding
  if (lastSyncCount === -1 || tasks.length !== lastSyncCount) {
    syncAlertsToSW(tasks)
  }
  lastSyncCount = tasks.length
}

function startRenderLoop(): void {
  if (renderLoopId) return
  renderLoopId = window.setInterval(() => {
    checkAlerts()

    const active = document.activeElement
    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.tagName === 'SELECT')) return
    if (currentView === 'panel') {
      const content = document.querySelector('.fmn-content') as HTMLElement
      if (content && updatePanelTimers(content)) renderPanel(content)
    }
  }, 1000)
}

function initTheme(): void {
  // Randomize theme on first visit
  if (isFirstRun()) {
    const random = THEMES[Math.floor(Math.random() * THEMES.length)]
    const settings = updateSettings({ themePreset: random.name })
    applyTheme(settings)
    applyIcon()
    return
  }

  const settings = getSettings()

  const params = new URLSearchParams(location.search)
  const themeParam = params.get('theme')

  if (themeParam) {
    const result = applyThemeParam(themeParam, settings)
    if (result) { applyIcon(); return }
  }

  applyTheme(settings)
  applyIcon()
}

function applyThemeParam(param: string, settings: ReturnType<typeof getSettings>): boolean {
  const allThemes = getAllThemes(settings)
  const byName = allThemes.find((t) => t.name === param)
  if (byName) {
    applyTheme(updateSettings({ themePreset: byName.name }))
    return true
  }

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

  const imported = await checkImportFromUrl()
  if (imported) return

  // ?seeded — load helper tasks if none exist
  const params = new URLSearchParams(location.search)
  if (params.has('seeded')) {
    loadSeedIfEmpty()
    history.replaceState(null, '', location.pathname)
  }

  const route = pathToRoute()
  currentView = route.view
  currentTaskId = route.taskId

  window.addEventListener('popstate', onPopState)

  render()
  startRenderLoop()

  await initSound()

  document.addEventListener('click', () => requestNotificationPermission(), { once: true })

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return
    const active = document.activeElement
    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.tagName === 'SELECT')) {
      ;(active as HTMLElement).blur()
      return
    }
    if (currentView !== 'panel') navigate('panel')
  })

  // Capture install prompt for on-demand triggering
  let installPrompt: any = null
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault()
    installPrompt = e
    // Show install button in footer
    const footer = document.querySelector('.fmn-footer')
    if (footer && !footer.querySelector('.fmn-install')) {
      const btn = document.createElement('a')
      btn.className = 'fmn-install'
      btn.textContent = 'install app'
      btn.style.cssText = 'color:var(--accent);cursor:pointer;margin-left:4px;'
      btn.onclick = () => {
        installPrompt?.prompt()
        installPrompt = null
        btn.remove()
      }
      footer.appendChild(document.createTextNode(' · '))
      footer.appendChild(btn)
    }
  })

  // Keep screen on
  if ('wakeLock' in navigator) {
    const requestWakeLock = () => {
      (navigator as any).wakeLock.request('screen').catch(() => {})
    }
    requestWakeLock()
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') requestWakeLock()
    })
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js', { updateViaCache: 'none' }).catch(() => {})
    navigator.serviceWorker.addEventListener('message', (e) => {
      if (e.data?.type === 'sw-version') {
        document.querySelectorAll('.fmn-sw-version').forEach((el) => {
          el.textContent = `(${e.data.version})`
        })
      }
    })
    navigator.serviceWorker.ready.then((reg) => {
      reg.active?.postMessage({ type: 'get-version' })
    })
  }

  const shopScript = document.createElement('script')
  shopScript.src = 'https://cdn.lucianlabs.ca/scripts/ll-shop.js'
  document.body.appendChild(shopScript)
}

init()
