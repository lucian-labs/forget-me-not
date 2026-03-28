export type TaskStatus = 'open' | 'in_progress' | 'blocked' | 'done' | 'cancelled' | 'archived'
export type TaskPriority = 'low' | 'normal' | 'high' | 'critical'
export type ActionType = 'reset' | 'complete' | 'note'

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
  cadenceSeconds: number | null
  lastResetAt: string | null

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
  fontFamily: string
  spacing: 'compact' | 'normal' | 'relaxed'
  animation: AnimStyle
  sound: ThemeSoundDefaults
}

export interface Settings {
  soundEnabled: boolean
  soundPreset: number
  soundBpm: number
  soundVolume: number
  soundMode: number

  domains: string[]

  themePreset: string
  customColors: Partial<ThemeColors>
  customBorderRadius: number | null
  customFontSize: number | null
  customSpacing: string | null
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

export type View = 'panel' | 'detail' | 'settings' | 'create'
