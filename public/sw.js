const CACHE_NAME = 'fmn-v16'
const PRECACHE = [
  '/',
  '/index.html',
  '/manifest.json',
]

// --- Overdue alert scheduling ---
let scheduledAlerts = new Map() // taskId -> timeoutId
let alertedTasks = new Set()    // taskIds already notified this cycle

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE))
  )
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  )
  self.clients.claim()
})

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return

  const url = new URL(event.request.url)

  // Never cache the service worker itself
  if (url.pathname === '/sw.js') return

  // SPA fallback for navigation
  if (event.request.mode === 'navigate' && url.origin === self.location.origin) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('/index.html'))
    )
    return
  }

  // Network-first for JS/CSS assets, cache fallback
  if (url.pathname.startsWith('/assets/')) {
    event.respondWith(
      fetch(event.request).then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone()
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone))
        }
        return response
      }).catch(() => caches.match(event.request))
    )
    return
  }

  // Cache-first for other static assets
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetched = fetch(event.request).then((response) => {
        if (response && response.status === 200 && response.type === 'basic') {
          const clone = response.clone()
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone))
        }
        return response
      }).catch(() => cached)

      return cached || fetched
    })
  )
})

// Listen for task schedule updates from main thread
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'schedule-alerts') {
    scheduleAlerts(event.data.tasks)
  }
  if (event.data && event.data.type === 'clear-alert') {
    alertedTasks.delete(event.data.taskId)
  }
  if (event.data && event.data.type === 'get-version') {
    event.source.postMessage({ type: 'sw-version', version: CACHE_NAME })
  }
})

function scheduleAlerts(tasks) {
  // Clear existing timers
  for (const [, timerId] of scheduledAlerts) {
    clearTimeout(timerId)
  }
  scheduledAlerts.clear()

  const now = Date.now()

  for (const task of tasks) {
    if (alertedTasks.has(task.id)) continue

    let overdueAt = null

    if (task.recurring && task.lastResetAt && task.cadenceSeconds) {
      overdueAt = new Date(task.lastResetAt).getTime() + task.cadenceSeconds * 1000
    } else if (task.dueDate) {
      overdueAt = new Date(task.dueDate).getTime()
    }

    if (!overdueAt) continue

    const delay = overdueAt - now

    if (delay <= 0) {
      // Already overdue — fire immediately
      fireAlert(task)
    } else {
      // Schedule for when it becomes overdue
      const timerId = setTimeout(() => fireAlert(task), delay)
      scheduledAlerts.set(task.id, timerId)
    }
  }
}

function fireAlert(task) {
  if (alertedTasks.has(task.id)) return
  alertedTasks.add(task.id)

  const appName = task._appName || 'forget me not'

  self.registration.showNotification(appName, {
    body: task.title,
    icon: '/icon.svg',
    tag: 'fmn-' + task.id,
    renotify: false,
    silent: false,
    vibrate: [200, 100, 200],
  })
}

// Clicking a notification focuses the app
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clients) => {
      if (clients.length > 0) {
        clients[0].focus()
      } else {
        self.clients.openWindow('/')
      }
    })
  )
})
