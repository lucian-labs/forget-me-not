# Forget Me Not — Sync Server Spec

Self-hostable sync server for Forget Me Not. Runs on a $5 droplet, a Raspberry Pi, or anywhere Node.js runs. One binary, one SQLite file, one env var.

## Philosophy

The client is the source of truth. The server is a mirror that enables multi-device access. If the server dies, nothing is lost — every client has a full copy. Obsidian vault model: you own the pipe.

## Architecture

```
┌─────────────┐     HTTPS/API Key     ┌──────────────┐
│  Browser A  │ ◄──────────────────► │              │
│  (localStorage)                     │  fmn-sync    │
└─────────────┘                       │  (Node.js)   │
                                      │              │
┌─────────────┐     HTTPS/API Key     │  SQLite DB   │
│  Browser B  │ ◄──────────────────► │              │
│  (localStorage)                     └──────────────┘
└─────────────┘
```

- **Server:** Single Node.js process, Express, SQLite (via better-sqlite3)
- **Auth:** API key in `X-API-Key` header. One key per user. Set via env var.
- **Transport:** HTTPS REST. No WebSocket needed for v1.
- **Conflict resolution:** Last-write-wins on `updatedAt` per task.
- **Storage:** Single SQLite file. Portable. Back it up with `cp`.

## Setup

```bash
# Install
git clone https://github.com/lucian-labs/fmn-sync
cd fmn-sync
npm install

# Configure
echo "FMN_API_KEY=$(openssl rand -hex 32)" > .env
echo "FMN_PORT=3847" >> .env

# Run
npm start

# Or with Docker
docker run -d -p 3847:3847 -e FMN_API_KEY=your-key -v fmn-data:/data lucianlabs/fmn-sync
```

In the PWA: Settings → Sync → paste `https://your-server:3847` + your API key → enable.

## Database Schema

Single table. Tasks are stored as JSON blobs with indexed metadata for querying.

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,           -- UUID from client
  data TEXT NOT NULL,            -- Full Task JSON
  updated_at TEXT NOT NULL,      -- ISO 8601, indexed for sync
  deleted INTEGER DEFAULT 0,    -- Soft delete flag
  created_at TEXT NOT NULL
);

CREATE INDEX idx_tasks_updated ON tasks(updated_at);
CREATE INDEX idx_tasks_deleted ON tasks(deleted);

CREATE TABLE sync_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- Stores: settings JSON, last compaction timestamp
```

## API

All endpoints require `X-API-Key` header.

### `GET /ping`

Health check. Returns `{ "ok": true, "tasks": <count> }`.

### `POST /sync`

**The only sync endpoint.** Client sends its state, server returns merged state.

Request:
```json
{
  "tasks": [ ...Task[] ],
  "settings": { ...Settings },
  "since": "2026-03-28T12:00:00Z",
  "deviceId": "browser-uuid"
}
```

- `tasks` — all tasks modified since `since` (client tracks last sync time)
- `settings` — current settings (optional, omit to skip settings sync)
- `since` — ISO timestamp of last successful sync. `null` for first sync (full dump)
- `deviceId` — stable per-browser UUID (generated once, stored in localStorage)

Response:
```json
{
  "tasks": [ ...Task[] ],
  "settings": { ...Settings },
  "syncedAt": "2026-03-28T12:05:00Z",
  "conflicts": [
    {
      "taskId": "uuid",
      "resolution": "server_wins",
      "serverUpdatedAt": "...",
      "clientUpdatedAt": "..."
    }
  ]
}
```

- `tasks` — all tasks the server has that are newer than client's `since`
- `settings` — merged settings (if client sent them)
- `syncedAt` — timestamp to use as `since` on next sync
- `conflicts` — informational, logged but not blocking

### `GET /export`

Full dump in the same format as `exportAll()`:
```json
{
  "tasks": [...],
  "settings": {...},
  "exportedAt": "...",
  "version": 1
}
```

### `POST /import`

Full import (overwrites). Same format as export. Dangerous — confirm in UI.

### `DELETE /tasks/:id`

Soft-delete a single task. Sets `deleted = 1`.

## Conflict Resolution

**Last-write-wins on `updatedAt` per task.**

```
For each incoming task from client:
  1. Look up server copy by task.id
  2. If not found → INSERT (new task)
  3. If found and client.updatedAt > server.updatedAt → UPDATE (client wins)
  4. If found and client.updatedAt <= server.updatedAt → SKIP (server wins)
  5. Log conflict in response
```

**Action logs are append-only.** On merge, union both action logs sorted by `at` timestamp. Never drop entries.

**Settings merge:** Last-write-wins on the entire settings object. `updatedAt` tracked in `sync_meta`.

**Deleted tasks:** Soft-deleted on server. Client removes from localStorage. Server keeps tombstone for 30 days, then hard-deletes on compaction.

## Client Sync Logic (to implement in store.ts)

```typescript
// New localStorage key
const SYNC_KEY = 'fmn-sync-state'
// Stores: { lastSyncAt: string, deviceId: string }

async function sync(): Promise<void> {
  const settings = getSettings()
  if (!settings.syncEnabled || !settings.syncEndpoint) return

  const syncState = getSyncState()
  const allTasks = getTasks()

  // Send tasks modified since last sync
  const modified = syncState.lastSyncAt
    ? allTasks.filter(t => t.updatedAt > syncState.lastSyncAt)
    : allTasks

  const res = await fetch(`${settings.syncEndpoint}/sync`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': settings.syncApiKey,
    },
    body: JSON.stringify({
      tasks: modified,
      settings,
      since: syncState.lastSyncAt,
      deviceId: syncState.deviceId,
    }),
  })

  const data = await res.json()

  // Merge server tasks into local
  const local = getTasks()
  const localMap = new Map(local.map(t => [t.id, t]))

  for (const serverTask of data.tasks) {
    const localTask = localMap.get(serverTask.id)
    if (!localTask || serverTask.updatedAt > localTask.updatedAt) {
      localMap.set(serverTask.id, serverTask)
    }
  }

  saveTasks([...localMap.values()])
  setSyncState({ lastSyncAt: data.syncedAt, deviceId: syncState.deviceId })
}
```

**Sync triggers:**
1. On app init (if sync enabled)
2. After any task mutation (debounced 2s)
3. On `visibilitychange` when tab becomes visible
4. Manual "Sync now" button in settings

## Deployment Options

### Bare metal / VPS / Raspberry Pi

```bash
git clone https://github.com/lucian-labs/fmn-sync
cd fmn-sync
npm install --production
FMN_API_KEY=your-secret-key FMN_PORT=3847 node server.js
```

Put behind nginx/caddy for HTTPS. SQLite file lives at `./data/fmn.db`.

### Docker

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
VOLUME /data
ENV FMN_DB_PATH=/data/fmn.db
EXPOSE 3847
CMD ["node", "server.js"]
```

### Docker Compose (with Caddy for auto-HTTPS)

```yaml
services:
  fmn-sync:
    build: .
    environment:
      FMN_API_KEY: ${FMN_API_KEY}
      FMN_DB_PATH: /data/fmn.db
    volumes:
      - fmn-data:/data
    expose:
      - "3847"

  caddy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
    depends_on:
      - fmn-sync

volumes:
  fmn-data:
  caddy-data:
```

```
# Caddyfile
sync.yourdomain.com {
  reverse_proxy fmn-sync:3847
}
```

### Raspberry Pi specifics

- Use `better-sqlite3` (compiles native on ARM)
- SQLite is perfect for Pi — no Postgres/Mongo overhead
- Expose via Tailscale or Cloudflare Tunnel for HTTPS without port forwarding
- Back up: `cp /data/fmn.db /mnt/usb/fmn-backup-$(date +%F).db`

## File Structure

```
fmn-sync/
  server.js          # Express app (~150 lines)
  db.js              # SQLite wrapper
  merge.js           # Conflict resolution logic
  package.json
  Dockerfile
  docker-compose.yml
  Caddyfile
  .env.example
```

## Security

- API key auth only (no user accounts for v1)
- HTTPS required in production (Caddy auto-cert or bring your own)
- Rate limiting: 100 req/min per API key
- SQLite WAL mode for concurrent reads
- No PII beyond what the user puts in task titles

## Future (v2)

- **Multi-user:** API key → user mapping, isolated task sets
- **WebSocket push:** Real-time sync instead of polling
- **E2E encryption:** Encrypt task JSON client-side before sync, server stores ciphertext
- **Shared lists:** Multiple users sync to the same task set
- **Webhooks:** POST to external URL on task events (integrations)
- **S3 backup:** Periodic SQLite dump to S3/Spaces
