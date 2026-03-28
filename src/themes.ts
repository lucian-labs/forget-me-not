import type { ThemeStyle, ThemeColors, Settings } from './types'

export const THEMES: ThemeStyle[] = [
  {
    name: 'midnight',
    label: 'Midnight',
    colors: {
      bg: '#0a0a0a', surface: '#141414', border: '#2a2a2a',
      text: '#e0e0e0', dim: '#666', accent: '#60a5fa',
      green: '#4ade80', orange: '#fb923c', red: '#ef4444', cyan: '#22d3ee',
    },
    borderRadius: 6, fontSize: 14,
    fontFamily: "'SF Mono', 'Fira Code', 'Cascadia Code', monospace",
    spacing: 'normal',
  },
  {
    name: 'sunrise',
    label: 'Sunrise',
    colors: {
      bg: '#fdf6ee', surface: '#ffffff', border: '#e8ddd0',
      text: '#3d2e1f', dim: '#a08b72', accent: '#d97706',
      green: '#65a30d', orange: '#ea580c', red: '#dc2626', cyan: '#0891b2',
    },
    borderRadius: 12, fontSize: 15,
    fontFamily: "'Georgia', 'Times New Roman', serif",
    spacing: 'relaxed',
  },
  {
    name: 'selva',
    label: 'Selva',
    colors: {
      bg: '#0f1a14', surface: '#162118', border: '#2d4a35',
      text: '#c8e6cf', dim: '#5e8a68', accent: '#34d399',
      green: '#4ade80', orange: '#fbbf24', red: '#f87171', cyan: '#67e8f9',
    },
    borderRadius: 8, fontSize: 14,
    fontFamily: "'Trebuchet MS', 'Gill Sans', sans-serif",
    spacing: 'normal',
  },
  {
    name: 'kente',
    label: 'Kente',
    colors: {
      bg: '#1a1207', surface: '#2a1f10', border: '#4a3520',
      text: '#f5e6c8', dim: '#a08660', accent: '#f59e0b',
      green: '#84cc16', orange: '#f97316', red: '#ef4444', cyan: '#06b6d4',
    },
    borderRadius: 4, fontSize: 14,
    fontFamily: "'Helvetica Neue', 'Arial', sans-serif",
    spacing: 'compact',
  },
  {
    name: 'neon',
    label: 'Neon',
    colors: {
      bg: '#0d0015', surface: '#150022', border: '#2e0050',
      text: '#e0d0f0', dim: '#7a5ea0', accent: '#c084fc',
      green: '#a3e635', orange: '#fb923c', red: '#f43f5e', cyan: '#22d3ee',
    },
    borderRadius: 10, fontSize: 14,
    fontFamily: "'SF Mono', 'Fira Code', monospace",
    spacing: 'normal',
  },
  {
    name: 'cloud',
    label: 'Cloud',
    colors: {
      bg: '#f0f4f8', surface: '#ffffff', border: '#d0dbe6',
      text: '#2d3748', dim: '#8896a6', accent: '#4299e1',
      green: '#48bb78', orange: '#ed8936', red: '#fc8181', cyan: '#38b2ac',
    },
    borderRadius: 14, fontSize: 15,
    fontFamily: "'Avenir', 'Segoe UI', sans-serif",
    spacing: 'relaxed',
  },
]

export function getTheme(name: string): ThemeStyle {
  return THEMES.find((t) => t.name === name) ?? THEMES[0]
}

export function resolveTheme(settings: Settings): {
  colors: ThemeColors
  borderRadius: number
  fontSize: number
  fontFamily: string
  spacing: string
} {
  const base = getTheme(settings.themePreset)
  return {
    colors: { ...base.colors, ...settings.customColors },
    borderRadius: settings.customBorderRadius ?? base.borderRadius,
    fontSize: settings.customFontSize ?? base.fontSize,
    fontFamily: base.fontFamily,
    spacing: settings.customSpacing ?? base.spacing,
  }
}

export function applyTheme(settings: Settings): void {
  const resolved = resolveTheme(settings)
  const root = document.documentElement
  const c = resolved.colors

  root.style.setProperty('--bg', c.bg)
  root.style.setProperty('--surface', c.surface)
  root.style.setProperty('--border', c.border)
  root.style.setProperty('--text', c.text)
  root.style.setProperty('--dim', c.dim)
  root.style.setProperty('--accent', c.accent)
  root.style.setProperty('--green', c.green)
  root.style.setProperty('--orange', c.orange)
  root.style.setProperty('--red', c.red)
  root.style.setProperty('--cyan', c.cyan)
  root.style.setProperty('--radius', `${resolved.borderRadius}px`)
  root.style.setProperty('--font-size', `${resolved.fontSize}px`)
  root.style.setProperty('--font', resolved.fontFamily)

  const spacingMap = { compact: '8px', normal: '12px', relaxed: '16px' }
  root.style.setProperty('--spacing', spacingMap[resolved.spacing as keyof typeof spacingMap] ?? '12px')

  // Update meta theme-color
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', c.bg)
}
