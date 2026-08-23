export type TaskStatus = 'open' | 'in_progress' | 'blocked' | 'done' | 'cancelled' | 'archived'
export type TaskPriority = 'low' | 'normal' | 'high' | 'critical'
// 'snoozed' (zz) + 'restarted' (down-arrow) are telemetry-only — logged for
// cadence analysis but hidden from the visible history (see detail.ts).
export type ActionType = 'reset' | 'complete' | 'note' | 'lapsed' | 'snoozed' | 'restarted'

/** A step in a chain — "laundry" → "move to dryer" → "fold + put away". */
export interface FollowUp {
  title: string
  /** How long after activation this step comes due. */
  cadenceSeconds: number
  domain?: string
}

export interface ActionLogEntry {
  /** Free text. For `snoozed`/`restarted` this holds the urgency ratio at the
   *  moment the button was pressed, e.g. "@0.83" — the raw cadence-tuning signal. */
  note: string
  at: string
  action: ActionType
}

/** One running cycle of a loop. Replaced wholesale each time the loop resets. */
export interface ReminderInstance {
  /** When this cycle began. Urgency counts up from here. */
  startedAt: string
  /** This cycle's actual length — `baseCadenceSeconds` after randomisation, so it
   *  differs cycle to cycle. Always measure urgency against THIS, not the base. */
  actualCadenceSeconds: number
  /** Set by the zz button, which rewinds `startedAt` to 75% elapsed. */
  snoozed: boolean
}

/**
 * The one entity in the app. A Task is either a **loop** (`recurring: true` — it
 * comes due every so often, forever) or a **one-off** (`dueDate` set, done once).
 * Everything else hangs off that distinction.
 *
 * See docs/DATA_MODEL.md before adding a field — several places have to agree.
 */
export interface Task {
  id: string
  title: string
  /** Free text. Also flavours the generated icon and the AI nudges on iOS. */
  description: string
  /** The category ("home", "health"). Named `domain` for historical reasons; the
   *  UI and the agent API both call it "category". */
  domain: string
  tags: string[]
  /** Only open/in_progress/blocked show in the main panel; done/cancelled/archived are filtered out. */
  status: TaskStatus
  priority: TaskPriority

  createdAt: string
  updatedAt: string
  /** One-offs only: when it's due. Loops use `instance` instead. */
  dueDate: string | null
  startedAt: string | null
  completedAt: string | null
  estimatedHours: number | null

  recurring: boolean
  /** The nominal cadence you set — "every 2 hours". Null means no timer. */
  baseCadenceSeconds: number | null
  /** Randomisation spread, in seconds. Each new cycle picks a length from
   *  `base - cadenceLess … base + cadenceMore`, so a loop doesn't fire at exactly
   *  the same moment forever. Both null = always exactly `baseCadenceSeconds`. */
  cadenceMore: number | null
  cadenceLess: number | null
  /** The cycle currently running. Null for a loop that has never been started.
   *  Urgency is elapsed-since-`startedAt` over `actualCadenceSeconds`. */
  instance: ReminderInstance | null

  /** Steps that follow this one. On the web these are SPAWNED as new tasks when
   *  the task is checked off; on iOS they exist up front as dormant children.
   *  Same shape, different activation — don't assume one from the other. */
  followUps: FollowUp[]
  /** Set on a task that was spawned from another's `followUps`. */
  parentTaskId: string | null

  /** Small nudges shown on the card once it's overdue — one picked at random.
   *  Concrete and tiny works best: "sweep", "dust a shelf". */
  prompts: string[]

  /** Overrides the global sound seed so this task gets its own jingle. */
  soundSeed: string | null

  /** Append-only history. `reset`/`complete`/`lapsed` are the entries that count
   *  as cycles (they drive the streak strip and stats); `note` is a bare note;
   *  `snoozed`/`restarted` are telemetry and stay hidden from the visible list. */
  actionLog: ActionLogEntry[]
}

export interface ThemeColors {
  bg: string
  surface: string
  border: string
  text: string
  dim: string
  accent: string
  green: string
  orange: string
  red: string
  cyan: string
}

export type AnimStyle = 'fade' | 'float' | 'glitch' | 'drift' | 'crumble' | 'zen' | 'spin' | 'wave' | 'petals' | 'slide' | 'grow'

export interface ThemeSoundDefaults {
  preset: number
  bpm: number
  volume: number
  mode: number
}

export interface ThemeStyle {
  name: string
  label: string
  colors: ThemeColors
  borderRadius: number
  fontSize: number
  headerFont: string
  bodyFont: string
  fontFamily: string // legacy fallback
  spacing: 'compact' | 'normal' | 'relaxed'
  animation: AnimStyle
  sound: ThemeSoundDefaults
}

export interface Settings {
  soundEnabled: boolean
  soundSeed: string
  soundPreset: number
  soundBpm: number
  soundVolume: number
  soundMode: number

  appName: string
  domains: string[]

  themePreset: string
  customColors: Partial<ThemeColors>
  customBorderRadius: number | null
  customFontSize: number | null
  customHeaderFont: string | null
  customBodyFont: string | null
  customSpacing: string | null
  userThemes: ThemeStyle[]
  fullWidth: boolean
  panelCollapsed: boolean

  syncEndpoint: string
  syncApiKey: string
  syncEnabled: boolean
}

export interface SyncConfig {
  endpoint: string
  apiKey: string
  enabled: boolean
}

export type View = 'panel' | 'detail' | 'settings' | 'create' | 'share' | 'taskyeet' | 'loops' | 'admin'
