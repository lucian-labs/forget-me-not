export type TaskStatus = 'open' | 'in_progress' | 'blocked' | 'done' | 'cancelled' | 'archived'
export type TaskPriority = 'low' | 'normal' | 'high' | 'critical'
export type ActionType = 'reset' | 'complete' | 'note' | 'lapsed'

export interface FollowUp {
  title: string
  cadenceSeconds: number
  domain?: string
}

export interface ActionLogEntry {
  note: string
  at: string
  action: ActionType
}

export interface ReminderInstance {
  startedAt: string
  actualCadenceSeconds: number
  snoozed: boolean
}

export interface Task {
  id: string
  title: string
  description: string
  domain: string
  tags: string[]
  status: TaskStatus
  priority: TaskPriority

  createdAt: string
  updatedAt: string
  dueDate: string | null
  startedAt: string | null
  completedAt: string | null
  estimatedHours: number | null

  recurring: boolean
  baseCadenceSeconds: number | null
  cadenceMore: number | null
  cadenceLess: number | null
  instance: ReminderInstance | null

  followUps: FollowUp[]
  parentTaskId: string | null

  prompts: string[]

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

export type View = 'panel' | 'detail' | 'settings' | 'create' | 'share' | 'taskyeet'
