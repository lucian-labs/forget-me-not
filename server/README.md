# fmn-push — Web Push backend for Forget Me Not

A small Node service (Express + SQLite + `web-push`) that delivers task reminders
as real Web Push notifications — even when the PWA is fully closed. Runs on the
droplet under pm2, behind nginx at `https://push.lucianlabs.ca`.

```
browser (tasks.lucianlabs.ca)
  POST /subscribe   -> stores this device's push subscription
  POST /schedule    -> mirrors each active task's next-due time + title
        │
        ▼
fmn-push (pm2, :3900)  ── SQLite (subscriptions, schedules)
  every 60s: due & not-yet-fired  ->  web-push.sendNotification()
```

The browser still does its own in-tab alerts (sounds + `sw.js`); this covers the
app-closed case. Titles are included in the payload.

## Deploy (on the droplet)

```sh
ssh root@138.197.174.255
mkdir -p /opt/fmn-push
cd /opt/src/forget-me-not && git pull
cp -r server/* /opt/fmn-push/           # or rsync
cd /opt/fmn-push
npm install --omit=dev

# secret env (gitignored). Copy .env.example -> .env and set VAPID_PRIVATE_KEY.
cp .env.example .env && "$EDITOR" .env

pm2 start server.mjs --name fmn-push
pm2 save
```

### nginx (`/etc/nginx/conf.d/push.lucianlabs.ca.conf`)

```nginx
server {
  listen 80;
  server_name push.lucianlabs.ca;
  location / {
    proxy_pass http://127.0.0.1:3900;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

```sh
nginx -t && systemctl reload nginx
certbot --nginx -d push.lucianlabs.ca      # TLS, same as the other subdomains
```

### DNS

`push.lucianlabs.ca` → A record → `138.197.174.255` (DigitalOcean DNS, since the
zone is on DO nameservers). From a machine with `doctl`:

```sh
doctl compute domain records create lucianlabs.ca --record-type A \
  --record-name push --record-data 138.197.174.255 --record-ttl 300
```

## VAPID keys

- Public key: shipped in the client (`src/push.ts`) and `.env` here.
- Private key: **secret**, lives only in `/opt/fmn-push/.env` on the droplet.
  To rotate: generate a new pair, update both, restart, and every browser must
  re-subscribe.

## Verify end-to-end

1. `tasks.lucianlabs.ca` → Settings → **Notifications** → on → Allow.
   (iPhone: add to Home Screen first, iOS 16.4+.)
2. Create a recurring task with a ~1-minute cadence, close the tab.
3. Within ~60s of it coming due, a push arrives.
4. Logs: `pm2 logs fmn-push`.

## Notes

- Endpoints are unauthenticated (personal app; CORS-limited to the site origin).
- Scheduler granularity is 60s — a task fires within a minute of due.
