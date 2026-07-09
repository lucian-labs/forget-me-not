import { buildPushPayload, type PushSubscription, type VapidKeys } from '@block65/webcrypto-web-push'

interface Env {
  DB: D1Database
  VAPID_SUBJECT: string
  VAPID_PUBLIC_KEY: string
  VAPID_PRIVATE_KEY: string
  ALLOWED_ORIGINS: string
}

// What the client POSTs to /subscribe.
interface SubscribeBody {
  deviceId: string
  subscription: PushSubscription
}

// What the client POSTs to /schedule — its full current active set.
interface ScheduleBody {
  deviceId: string
  tasks: { id: string; title: string; nextDue: number }[]
}

const APP_NAME = 'forget me not'

function corsHeaders(origin: string | null, env: Env): Record<string, string> {
  const allowed = env.ALLOWED_ORIGINS.split(',').map((s) => s.trim())
  const allow = origin && allowed.includes(origin) ? origin : allowed[0]
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  }
}

function json(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors },
  })
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url)
    const cors = corsHeaders(req.headers.get('Origin'), env)

    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors })
    if (req.method === 'GET' && url.pathname === '/ping') return json({ ok: true }, 200, cors)
    if (req.method !== 'POST') return json({ error: 'method' }, 405, cors)

    try {
      if (url.pathname === '/subscribe') {
        const { deviceId, subscription } = (await req.json()) as SubscribeBody
        if (!deviceId || !subscription?.endpoint) return json({ error: 'bad request' }, 400, cors)
        await env.DB.prepare(
          `INSERT INTO subscriptions (device_id, endpoint, p256dh, auth, updated_at)
           VALUES (?1, ?2, ?3, ?4, ?5)
           ON CONFLICT(device_id) DO UPDATE SET
             endpoint = ?2, p256dh = ?3, auth = ?4, updated_at = ?5`,
        )
          .bind(deviceId, subscription.endpoint, subscription.keys.p256dh, subscription.keys.auth, new Date().toISOString())
          .run()
        return json({ ok: true }, 200, cors)
      }

      if (url.pathname === '/schedule') {
        const { deviceId, tasks } = (await req.json()) as ScheduleBody
        if (!deviceId || !Array.isArray(tasks)) return json({ error: 'bad request' }, 400, cors)
        const stmts: D1PreparedStatement[] = []
        // Upsert each active task. If its next_due changed, re-arm (notified = 0).
        for (const t of tasks) {
          if (!t.id || typeof t.nextDue !== 'number') continue
          stmts.push(
            env.DB.prepare(
              `INSERT INTO schedules (device_id, task_id, title, next_due, notified)
               VALUES (?1, ?2, ?3, ?4, 0)
               ON CONFLICT(device_id, task_id) DO UPDATE SET
                 title = ?3,
                 notified = CASE WHEN schedules.next_due != ?4 THEN 0 ELSE schedules.notified END,
                 next_due = ?4`,
            ).bind(deviceId, t.id, t.title || APP_NAME, t.nextDue),
          )
        }
        // Drop any schedule rows for this device whose task is no longer active.
        const keepIds = tasks.map((t) => t.id).filter(Boolean)
        const placeholders = keepIds.map((_, i) => `?${i + 2}`).join(',')
        const delSql = keepIds.length
          ? `DELETE FROM schedules WHERE device_id = ?1 AND task_id NOT IN (${placeholders})`
          : `DELETE FROM schedules WHERE device_id = ?1`
        stmts.push(env.DB.prepare(delSql).bind(deviceId, ...keepIds))
        await env.DB.batch(stmts)
        return json({ ok: true, count: keepIds.length }, 200, cors)
      }

      if (url.pathname === '/unsubscribe') {
        const { deviceId } = (await req.json()) as { deviceId: string }
        if (!deviceId) return json({ error: 'bad request' }, 400, cors)
        await env.DB.batch([
          env.DB.prepare(`DELETE FROM subscriptions WHERE device_id = ?1`).bind(deviceId),
          env.DB.prepare(`DELETE FROM schedules WHERE device_id = ?1`).bind(deviceId),
        ])
        return json({ ok: true }, 200, cors)
      }

      return json({ error: 'not found' }, 404, cors)
    } catch (err) {
      return json({ error: String(err) }, 500, cors)
    }
  },

  // Cron (every minute): push every task that has tipped overdue and not yet fired.
  async scheduled(_event: ScheduledController, env: Env): Promise<void> {
    const now = Date.now()
    const vapid: VapidKeys = {
      subject: env.VAPID_SUBJECT,
      publicKey: env.VAPID_PUBLIC_KEY,
      privateKey: env.VAPID_PRIVATE_KEY,
    }

    const due = await env.DB.prepare(
      `SELECT s.device_id, s.task_id, s.title, sub.endpoint, sub.p256dh, sub.auth
         FROM schedules s
         JOIN subscriptions sub ON sub.device_id = s.device_id
        WHERE s.notified = 0 AND s.next_due <= ?1
        LIMIT 500`,
    )
      .bind(now)
      .all<{ device_id: string; task_id: string; title: string; endpoint: string; p256dh: string; auth: string }>()

    for (const row of due.results) {
      const subscription: PushSubscription = {
        endpoint: row.endpoint,
        expirationTime: null,
        keys: { p256dh: row.p256dh, auth: row.auth },
      }
      try {
        const payload = await buildPushPayload(
          { data: JSON.stringify({ title: APP_NAME, body: row.title, taskId: row.task_id }), options: { ttl: 3600 } },
          subscription,
          vapid,
        )
        const res = await fetch(subscription.endpoint, payload)
        if (res.status === 404 || res.status === 410) {
          // Subscription is dead — drop the device entirely.
          await env.DB.batch([
            env.DB.prepare(`DELETE FROM subscriptions WHERE device_id = ?1`).bind(row.device_id),
            env.DB.prepare(`DELETE FROM schedules WHERE device_id = ?1`).bind(row.device_id),
          ])
        } else {
          // 201 (sent) or any transient error: mark fired so we don't spam retries.
          await env.DB.prepare(`UPDATE schedules SET notified = 1 WHERE device_id = ?1 AND task_id = ?2`)
            .bind(row.device_id, row.task_id)
            .run()
        }
      } catch (e) {
        console.error('push send failed', row.task_id, String(e))
        await env.DB.prepare(`UPDATE schedules SET notified = 1 WHERE device_id = ?1 AND task_id = ?2`)
          .bind(row.device_id, row.task_id)
          .run()
      }
    }
  },
}
