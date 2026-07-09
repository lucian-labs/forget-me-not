// fmn-push — Web Push backend for Forget Me Not.
// Runs on the droplet under pm2, behind nginx at push.lucianlabs.ca.
// Delivers task reminders as real Web Push even when the PWA is fully closed.
//
//   browser  --POST /subscribe--> stores this device's push subscription
//            --POST /schedule---> mirrors each active task's next-due + title
//   every 60s: find tasks due & not-yet-fired -> encrypt (VAPID) -> Web Push

import express from 'express'
import Database from 'better-sqlite3'
import webpush from 'web-push'

const PORT = Number(process.env.PORT || 3900)
const DB_PATH = process.env.DB_PATH || './fmn-push.db'
const APP_NAME = 'forget me not'
const ALLOWED = (process.env.ALLOWED_ORIGINS || 'https://tasks.lucianlabs.ca,http://localhost:5173')
  .split(',')
  .map((s) => s.trim())

webpush.setVapidDetails(
  process.env.VAPID_SUBJECT || 'mailto:elijahlucian@gmail.com',
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY,
)

const db = new Database(DB_PATH)
db.pragma('journal_mode = WAL')
db.exec(`
  CREATE TABLE IF NOT EXISTS subscriptions (
    device_id  TEXT PRIMARY KEY,
    endpoint   TEXT NOT NULL,
    p256dh     TEXT NOT NULL,
    auth       TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS schedules (
    device_id TEXT NOT NULL,
    task_id   TEXT NOT NULL,
    title     TEXT NOT NULL,
    next_due  INTEGER NOT NULL,
    notified  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (device_id, task_id)
  );
  CREATE INDEX IF NOT EXISTS idx_sched_due ON schedules(notified, next_due);
`)

const upsertSub = db.prepare(`
  INSERT INTO subscriptions (device_id, endpoint, p256dh, auth, updated_at)
  VALUES (@device_id, @endpoint, @p256dh, @auth, @updated_at)
  ON CONFLICT(device_id) DO UPDATE SET
    endpoint = excluded.endpoint, p256dh = excluded.p256dh,
    auth = excluded.auth, updated_at = excluded.updated_at`)

const upsertSched = db.prepare(`
  INSERT INTO schedules (device_id, task_id, title, next_due, notified)
  VALUES (@device_id, @task_id, @title, @next_due, 0)
  ON CONFLICT(device_id, task_id) DO UPDATE SET
    title = excluded.title,
    notified = CASE WHEN schedules.next_due != excluded.next_due THEN 0 ELSE schedules.notified END,
    next_due = excluded.next_due`)

const listTaskIds = db.prepare(`SELECT task_id FROM schedules WHERE device_id = ?`)
const delSched = db.prepare(`DELETE FROM schedules WHERE device_id = ? AND task_id = ?`)
const delDeviceSched = db.prepare(`DELETE FROM schedules WHERE device_id = ?`)
const delDeviceSub = db.prepare(`DELETE FROM subscriptions WHERE device_id = ?`)
const markNotified = db.prepare(`UPDATE schedules SET notified = 1 WHERE device_id = ? AND task_id = ?`)
const dueRows = db.prepare(`
  SELECT s.device_id, s.task_id, s.title, sub.endpoint, sub.p256dh, sub.auth
    FROM schedules s
    JOIN subscriptions sub ON sub.device_id = s.device_id
   WHERE s.notified = 0 AND s.next_due <= ?
   LIMIT 500`)

// Replace this device's schedule set with the incoming one (upsert + prune).
const syncSchedule = db.transaction((deviceId, tasks) => {
  const keep = new Set()
  for (const t of tasks) {
    if (!t.id || typeof t.nextDue !== 'number') continue
    upsertSched.run({ device_id: deviceId, task_id: t.id, title: t.title || APP_NAME, next_due: t.nextDue })
    keep.add(t.id)
  }
  for (const row of listTaskIds.all(deviceId)) {
    if (!keep.has(row.task_id)) delSched.run(deviceId, row.task_id)
  }
  return keep.size
})

const app = express()
app.use(express.json({ limit: '256kb' }))
app.use((req, res, next) => {
  const origin = req.headers.origin
  res.setHeader('Access-Control-Allow-Origin', origin && ALLOWED.includes(origin) ? origin : ALLOWED[0])
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') return res.sendStatus(204)
  next()
})

app.get('/ping', (_req, res) => res.json({ ok: true }))

app.post('/subscribe', (req, res) => {
  const { deviceId, subscription } = req.body || {}
  if (!deviceId || !subscription?.endpoint) return res.status(400).json({ error: 'bad request' })
  upsertSub.run({
    device_id: deviceId,
    endpoint: subscription.endpoint,
    p256dh: subscription.keys.p256dh,
    auth: subscription.keys.auth,
    updated_at: new Date().toISOString(),
  })
  res.json({ ok: true })
})

app.post('/schedule', (req, res) => {
  const { deviceId, tasks } = req.body || {}
  if (!deviceId || !Array.isArray(tasks)) return res.status(400).json({ error: 'bad request' })
  const count = syncSchedule(deviceId, tasks)
  res.json({ ok: true, count })
})

app.post('/unsubscribe', (req, res) => {
  const { deviceId } = req.body || {}
  if (!deviceId) return res.status(400).json({ error: 'bad request' })
  delDeviceSub.run(deviceId)
  delDeviceSched.run(deviceId)
  res.json({ ok: true })
})

// Scheduler: every 60s, push every task that's tipped overdue and not yet fired.
async function tick() {
  const now = Date.now()
  const rows = dueRows.all(now)
  for (const row of rows) {
    const subscription = { endpoint: row.endpoint, keys: { p256dh: row.p256dh, auth: row.auth } }
    const payload = JSON.stringify({ title: APP_NAME, body: row.title, taskId: row.task_id })
    try {
      await webpush.sendNotification(subscription, payload, { TTL: 3600 })
      markNotified.run(row.device_id, row.task_id)
    } catch (err) {
      if (err.statusCode === 404 || err.statusCode === 410) {
        // Subscription is dead — drop the device entirely.
        delDeviceSub.run(row.device_id)
        delDeviceSched.run(row.device_id)
      } else {
        markNotified.run(row.device_id, row.task_id) // don't spam retries on transient errors
        console.error('push failed', row.task_id, err.statusCode || err.message)
      }
    }
  }
}
setInterval(tick, Number(process.env.TICK_MS || 60_000))

app.listen(PORT, '127.0.0.1', () => console.log(`fmn-push listening on 127.0.0.1:${PORT}`))
