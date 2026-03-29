import type { ThemeStyle, ThemeColors, Settings } from './types'

export const THEMES: ThemeStyle[] = [
  {
    name: 'midnight', label: 'Midnight',
    colors: { bg: '#0a0a0a', surface: '#141414', border: '#2a2a2a', text: '#e0e0e0', dim: '#666', accent: '#60a5fa', green: '#4ade80', orange: '#fb923c', red: '#ef4444', cyan: '#22d3ee' },
    borderRadius: 6, fontSize: 14, headerFont: 'Fira Code', bodyFont: 'Fira Code', fontFamily: "'SF Mono', 'Fira Code', monospace", spacing: 'normal',
    animation: 'fade', sound: { preset: 88, bpm: 160, volume: 0.4, mode: 1 },
  },
  {
    name: 'sunrise', label: 'Sunrise',
    colors: { bg: '#fdf6ee', surface: '#ffffff', border: '#e8ddd0', text: '#3d2e1f', dim: '#a08b72', accent: '#d97706', green: '#65a30d', orange: '#ea580c', red: '#dc2626', cyan: '#0891b2' },
    borderRadius: 12, fontSize: 15, headerFont: 'Playfair Display', bodyFont: 'Lora', fontFamily: "'Georgia', serif", spacing: 'relaxed',
    animation: 'float', sound: { preset: 91, bpm: 120, volume: 0.3, mode: 3 },
  },
  {
    name: 'selva', label: 'Selva',
    colors: { bg: '#0f1a14', surface: '#162118', border: '#2d4a35', text: '#c8e6cf', dim: '#5e8a68', accent: '#34d399', green: '#4ade80', orange: '#fbbf24', red: '#f87171', cyan: '#67e8f9' },
    borderRadius: 8, fontSize: 14, headerFont: 'Josefin Sans', bodyFont: 'Nunito', fontFamily: "'Trebuchet MS', sans-serif", spacing: 'normal',
    animation: 'grow', sound: { preset: 77, bpm: 100, volume: 0.35, mode: 5 },
  },
  {
    name: 'kente', label: 'Kente',
    colors: { bg: '#1a1207', surface: '#2a1f10', border: '#4a3520', text: '#f5e6c8', dim: '#a08660', accent: '#f59e0b', green: '#84cc16', orange: '#f97316', red: '#ef4444', cyan: '#06b6d4' },
    borderRadius: 4, fontSize: 14, headerFont: 'Bebas Neue', bodyFont: 'Inter', fontFamily: "'Helvetica Neue', sans-serif", spacing: 'compact',
    animation: 'slide', sound: { preset: 93, bpm: 140, volume: 0.5, mode: 2 },
  },
  {
    name: 'neon', label: 'Neon',
    colors: { bg: '#0d0015', surface: '#150022', border: '#2e0050', text: '#e0d0f0', dim: '#7a5ea0', accent: '#c084fc', green: '#a3e635', orange: '#fb923c', red: '#f43f5e', cyan: '#22d3ee' },
    borderRadius: 10, fontSize: 14, headerFont: 'Orbitron', bodyFont: 'JetBrains Mono', fontFamily: "'SF Mono', monospace", spacing: 'normal',
    animation: 'glitch', sound: { preset: 67, bpm: 200, volume: 0.5, mode: 7 },
  },
  {
    name: 'cloud', label: 'Cloud',
    colors: { bg: '#f0f4f8', surface: '#ffffff', border: '#d0dbe6', text: '#2d3748', dim: '#8896a6', accent: '#4299e1', green: '#48bb78', orange: '#ed8936', red: '#fc8181', cyan: '#38b2ac' },
    borderRadius: 14, fontSize: 15, headerFont: 'Poppins', bodyFont: 'Poppins', fontFamily: "'Avenir', sans-serif", spacing: 'relaxed',
    animation: 'drift', sound: { preset: 59, bpm: 110, volume: 0.3, mode: 0 },
  },
  {
    name: 'terracotta', label: 'Terracotta',
    colors: { bg: '#1c1210', surface: '#271a16', border: '#3d2b24', text: '#e8d5ca', dim: '#967a6a', accent: '#c2704f', green: '#a3b18a', orange: '#dda15e', red: '#bc4749', cyan: '#89b0ae' },
    borderRadius: 8, fontSize: 15, headerFont: 'Cormorant Garamond', bodyFont: 'Source Serif 4', fontFamily: "'Palatino', serif", spacing: 'relaxed',
    animation: 'crumble', sound: { preset: 90, bpm: 100, volume: 0.35, mode: 4 },
  },
  {
    name: 'matcha', label: 'Matcha',
    colors: { bg: '#f4f7f0', surface: '#fafcf7', border: '#d4dcc8', text: '#2d3a25', dim: '#7d8a72', accent: '#6b8f4e', green: '#7cb342', orange: '#e0a030', red: '#c0503a', cyan: '#5d9b9b' },
    borderRadius: 16, fontSize: 15, headerFont: 'Quicksand', bodyFont: 'Quicksand', fontFamily: "'Optima', sans-serif", spacing: 'relaxed',
    animation: 'zen', sound: { preset: 17, bpm: 90, volume: 0.25, mode: 0 },
  },
  {
    name: 'vinyl', label: 'Vinyl',
    colors: { bg: '#121212', surface: '#1e1e1e', border: '#333333', text: '#d4d4d4', dim: '#737373', accent: '#e53e3e', green: '#68d391', orange: '#f6ad55', red: '#fc5c65', cyan: '#63b3ed' },
    borderRadius: 3, fontSize: 13, headerFont: 'Space Mono', bodyFont: 'IBM Plex Mono', fontFamily: "'Courier New', monospace", spacing: 'compact',
    animation: 'spin', sound: { preset: 0, bpm: 180, volume: 0.45, mode: 6 },
  },
  {
    name: 'oceano', label: 'Oc\u00e9ano',
    colors: { bg: '#0b1628', surface: '#0f2035', border: '#1a3554', text: '#c8ddf0', dim: '#5a7a9a', accent: '#38bdf8', green: '#34d399', orange: '#fbbf24', red: '#f87171', cyan: '#67e8f9' },
    borderRadius: 10, fontSize: 14, headerFont: 'Raleway', bodyFont: 'Open Sans', fontFamily: "'Gill Sans', sans-serif", spacing: 'normal',
    animation: 'wave', sound: { preset: 92, bpm: 130, volume: 0.35, mode: 3 },
  },
  {
    name: 'sakura', label: 'Sakura',
    colors: { bg: '#fef5f7', surface: '#ffffff', border: '#f0d4db', text: '#4a2c3a', dim: '#b08a98', accent: '#e8729a', green: '#7bc47f', orange: '#e8a87c', red: '#d94f6b', cyan: '#6cc0c0' },
    borderRadius: 18, fontSize: 15, headerFont: 'Kaisei Tokumin', bodyFont: 'Noto Sans JP', fontFamily: "'Georgia', serif", spacing: 'relaxed',
    animation: 'petals', sound: { preset: 30, bpm: 100, volume: 0.25, mode: 0 },
  },
]

export function getAllThemes(settings: Settings): ThemeStyle[] {
  return [...THEMES, ...(settings.userThemes ?? [])]
}

export function getTheme(name: string, settings?: Settings): ThemeStyle {
  const all = settings ? getAllThemes(settings) : THEMES
  return all.find((t) => t.name === name) ?? THEMES[0]
}

export function resolveTheme(settings: Settings): {
  colors: ThemeColors
  borderRadius: number
  fontSize: number
  headerFont: string
  bodyFont: string
  spacing: string
} {
  const base = getTheme(settings.themePreset, settings)
  return {
    colors: { ...base.colors, ...settings.customColors },
    borderRadius: settings.customBorderRadius ?? base.borderRadius,
    fontSize: settings.customFontSize ?? base.fontSize,
    headerFont: settings.customHeaderFont ?? base.headerFont,
    bodyFont: settings.customBodyFont ?? base.bodyFont,
    spacing: settings.customSpacing ?? base.spacing,
  }
}

const loadedFonts = new Set<string>()

function loadGoogleFont(font: string): void {
  if (!font || loadedFonts.has(font)) return
  loadedFonts.add(font)
  const link = document.createElement('link')
  link.rel = 'stylesheet'
  link.href = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(font)}:wght@400;600;700&display=swap`
  document.head.appendChild(link)
}

export function applyTheme(settings: Settings): void {
  const resolved = resolveTheme(settings)
  const root = document.documentElement
  const c = resolved.colors

  // Load Google Fonts
  loadGoogleFont(resolved.headerFont)
  loadGoogleFont(resolved.bodyFont)

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
  root.style.setProperty('--font-header', `'${resolved.headerFont}', sans-serif`)
  root.style.setProperty('--font-body', `'${resolved.bodyFont}', sans-serif`)
  root.style.setProperty('--font', `'${resolved.bodyFont}', sans-serif`)

  const spacingMap = { compact: '8px', normal: '12px', relaxed: '16px' }
  root.style.setProperty('--spacing', spacingMap[resolved.spacing as keyof typeof spacingMap] ?? '12px')

  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', c.bg)
}

// --- Theme import/export ---

export function exportTheme(settings: Settings): string {
  const theme = getTheme(settings.themePreset, settings)
  const resolved = resolveTheme(settings)
  const exported: ThemeStyle = {
    ...theme,
    colors: resolved.colors,
    borderRadius: resolved.borderRadius,
    fontSize: resolved.fontSize,
    headerFont: resolved.headerFont,
    bodyFont: resolved.bodyFont,
    spacing: resolved.spacing as 'compact' | 'normal' | 'relaxed',
  }
  return JSON.stringify(exported, null, 2)
}

export function themeToShareUrl(settings: Settings): string {
  const theme = getTheme(settings.themePreset, settings)
  // For built-in themes, share by name
  if (THEMES.some((t) => t.name === theme.name)) {
    return `${location.origin}/?theme=${theme.name}`
  }
  const json = exportTheme(settings)
  const encoded = btoa(unescape(encodeURIComponent(json)))
  return `${location.origin}/?theme=${encoded}`
}

export function importThemeJson(json: string, settings: Settings): ThemeStyle | null {
  try {
    const theme = JSON.parse(json) as ThemeStyle
    if (!theme.name || !theme.colors) return null
    // Ensure it doesn't clash with built-in names
    if (THEMES.some((t) => t.name === theme.name)) {
      theme.name = `${theme.name}-custom`
    }
    return theme
  } catch {
    return null
  }
}

// Global callback for script-tag loading (CORS-free)
;(window as any).FMN_THEME = null
;(window as any).fmnLoadTheme = (theme: ThemeStyle) => {
  ;(window as any).FMN_THEME = theme
  window.dispatchEvent(new CustomEvent('fmn-theme-loaded', { detail: theme }))
}
