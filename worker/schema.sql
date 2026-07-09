-- One row per device (browser) that has granted push permission.
CREATE TABLE IF NOT EXISTS subscriptions (
  device_id  TEXT PRIMARY KEY,   -- stable per-browser UUID (fmn-device-id)
  endpoint   TEXT NOT NULL,      -- push service endpoint
  p256dh     TEXT NOT NULL,      -- subscription public key
  auth       TEXT NOT NULL,      -- subscription auth secret
  updated_at TEXT NOT NULL
);

-- One row per (device, task): when that task next tips overdue, and whether
-- we've already pushed for this cycle. The client re-uploads its full active
-- set whenever tasks change, so this table mirrors the browser's schedule.
CREATE TABLE IF NOT EXISTS schedules (
  device_id TEXT NOT NULL,
  task_id   TEXT NOT NULL,
  title     TEXT NOT NULL,
  next_due  INTEGER NOT NULL,          -- epoch milliseconds
  notified  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_id, task_id)
);

CREATE INDEX IF NOT EXISTS idx_sched_due ON schedules(notified, next_due);
