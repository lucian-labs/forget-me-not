// Duration parsing/formatting for the agent API. Deliberately dependency-free so
// it can be reasoned about (and tested) on its own.

/**
 * Agents think in words, not seconds. Accepts a number (seconds) or text like
 * "2h", "90 minutes", "every 3 days", "1h 30m", "hourly", "daily", "weekly".
 * Returns null when it can't be understood, so callers can say so plainly
 * instead of silently guessing a cadence.
 */
export function parseDuration(input: string | number | null | undefined): number | null {
  if (input === null || input === undefined) return null
  if (typeof input === 'number') return Number.isFinite(input) && input > 0 ? Math.round(input) : null

  const s = String(input).trim().toLowerCase()
  if (!s) return null

  const named: Record<string, number> = {
    minutely: 60, hourly: 3600, daily: 86400, weekly: 604800,
    fortnightly: 1209600, biweekly: 1209600, monthly: 2592000, yearly: 31536000,
  }
  if (named[s]) return named[s]

  const units: [RegExp, number][] = [
    [/^(seconds?|secs?|s)$/, 1],
    [/^(minutes?|mins?|m)$/, 60],
    [/^(hours?|hrs?|h)$/, 3600],
    [/^(days?|d)$/, 86400],
    [/^(weeks?|wks?|w)$/, 604800],
    [/^(months?|mo|mons?)$/, 2592000],
    [/^(years?|yrs?|y)$/, 31536000],
  ]

  // Sum every "<number><unit>" pair, so "1h 30m" and "every 2 hours" both work.
  let total = 0
  let matched = false
  const re = /(\d+(?:\.\d+)?)\s*([a-z]+)/g
  let m: RegExpExecArray | null
  while ((m = re.exec(s))) {
    const qty = parseFloat(m[1])
    const unitName = m[2]
    const unit = units.find(([rx]) => rx.test(unitName))
    if (!unit) continue
    total += qty * unit[1]
    matched = true
  }
  if (matched && total > 0) return Math.round(total)

  // No number anywhere: a bare unit means one of it — "every day", "each week".
  for (const word of s.split(/[^a-z]+/)) {
    const unit = units.find(([rx]) => rx.test(word))
    if (unit) return unit[1]
  }
  return null
}

/** Seconds -> "3 days", "90 minutes" — for showing a cadence back to an agent. */
export function humanize(seconds: number): string {
  const units: [number, string][] = [
    [604800, 'week'], [86400, 'day'], [3600, 'hour'], [60, 'minute'], [1, 'second'],
  ]
  for (const [size, name] of units) {
    if (seconds >= size) {
      const n = Math.round((seconds / size) * 10) / 10
      return `${n} ${name}${n === 1 ? '' : 's'}`
    }
  }
  return `${seconds} seconds`
}
