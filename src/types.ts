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

export interface Settings {
  soundEnabled: boolean
  soundPreset: number
  soundBpm: number
  soundVolume: number
  soundMode: number

  domains: string[]

  theme: 'dark' | 'light'
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
