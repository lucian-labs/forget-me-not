# fmn-push — Web Push backend for Forget Me Not

A single Cloudflare Worker + D1 + a 1-minute cron that delivers task reminders as
real Web Push notifications — even when the PWA is fully closed.

```
browser (tasks.lucianlabs.ca)
  │  POST /subscribe   → stores this device's push subscription
  │  POST /schedule    → stores each active task's next-due time + title
  ▼
fmn-push Worker ── D1 (subscriptions, schedules)
  ▲
  └─ cron "* * * * *": find tasks due & not-yet-fired → encrypt + send Web Push
```

The client keeps `/schedule` current (debounced, on every change). The browser
still does its own in-tab alerts (sounds + `sw.js`); this covers the app-closed case.

## One-time deploy

```bash
cd worker
npm install
npx wrangler login                       # interactive, opens a browser

# 1. Create the database, then paste the printed database_id into wrangler.toml
npx wrangler d1 create fmn-push

# 2. Create the tables on the remote DB
npm run db:remote

# 3. Set the VAPID private key as a secret. Paste the value of VAPID_PRIVATE_KEY
#    from worker/.dev.vars (gitignored) when prompted:
npx wrangler secret put VAPID_PRIVATE_KEY

# 4. Ship it
npm run deploy
```

### Custom domain

The client calls `https://fmn-push.lucianlabs.ca` (see `DEFAULT_PUSH_API` in
`../src/push.ts`). Since `lucianlabs.ca` is on Cloudflare, add it in the dashboard:
**Workers & Pages → fmn-push → Settings → Domains & Routes → Add → Custom domain →
`fmn-push.lucianlabs.ca`**. (Or use the `*.workers.dev` URL wrangler prints and
change `DEFAULT_PUSH_API` to match.)

## VAPID keys

- Public key is shipped in `wrangler.toml` (var) and `src/push.ts` (client).
- Private key is a Worker **secret** — never committed. Locally it's read from
  `.dev.vars` (gitignored). To rotate: generate a new pair, update both places,
  `wrangler secret put`, and every browser must re-subscribe.

## Local dev

```bash
npm run db:local          # create local tables
npm run dev               # wrangler dev on :8787
# point the client at it:  localStorage.setItem('fmn-push-endpoint','http://localhost:8787')
# trigger the cron by hand:  curl "http://localhost:8787/cdn-cgi/handler/scheduled"
```

## Verifying end-to-end

1. Open `tasks.lucianlabs.ca` → Settings → **Notifications** → toggle on → Allow.
   (On iPhone: add to Home Screen first, iOS 16.4+.)
2. Create a recurring task with a ~1-minute cadence.
3. Close the tab entirely. Within ~1 minute of it coming due you get a push.
4. Watch the backend live: `npx wrangler tail`.

## Notes / future hardening

- Endpoints are unauthenticated (a personal app; CORS limits browsers). If abused,
  add an API key or per-origin rate limiting. Worst case today is DB spam.
- Free tier is ample: cron = 1440 invocations/day; D1 rows are tiny.
- Cron granularity is 1 minute (Cloudflare minimum) — a task fires within ~60s of due.
