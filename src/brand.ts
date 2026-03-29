import { getSettings } from './store'

export function appName(): string {
  const settings = getSettings()
  return settings.appName || 'forget me not'
}
