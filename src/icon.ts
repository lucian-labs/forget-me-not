import { getSettings } from './store'
import { resolveTheme } from './themes'

function getInitials(name: string): string {
  const words = (name || 'forget me not').trim().split(/\s+/)
  if (words.length === 1) return words[0][0].toUpperCase()
  return words.slice(0, 3).map((w) => w[0]).join('').toUpperCase()
}

export function generateIconSvg(size: number = 512): string {
  const settings = getSettings()
  const resolved = resolveTheme(settings)
  const c = resolved.colors
  const initials = getInitials(settings.appName)
  const r = Math.min(resolved.borderRadius * 4, 64)
  const headerFont = resolved.headerFont
  const fontSize = initials.length === 1 ? size * 0.5 : initials.length === 2 ? size * 0.4 : size * 0.32

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}">
  <rect width="${size}" height="${size}" rx="${r}" fill="${c.bg}"/>
  <rect x="16" y="16" width="${size - 32}" height="${size - 32}" rx="${Math.max(r - 8, 0)}" fill="${c.surface}" stroke="${c.border}" stroke-width="2"/>
  <text x="${size / 2}" y="${size / 2}" text-anchor="middle" dominant-baseline="central" fill="${c.accent}" font-family="'${headerFont}', sans-serif" font-size="${fontSize}" font-weight="700">${initials}</text>
</svg>`
}

export function generateIconDataUri(size: number = 512): string {
  const svg = generateIconSvg(size)
  return `data:image/svg+xml,${encodeURIComponent(svg)}`
}

export function applyIcon(): void {
  const uri = generateIconDataUri(64)

  // Update favicon (data: SVG is fine for tab favicon)
  let favicon = document.querySelector('link[rel="icon"]') as HTMLLinkElement | null
  if (!favicon) {
    favicon = document.createElement('link')
    favicon.rel = 'icon'
    document.head.appendChild(favicon)
  }
  favicon.type = 'image/svg+xml'
  favicon.href = uri

  // NOTE: do NOT override <link rel="manifest"> or <link rel="apple-touch-icon">.
  // Chrome's installability check rejects blob: manifest URLs and requires
  // raster PNG icons — both are served statically from /manifest.json,
  // /icon-192.png, /icon-512.png. Overriding here breaks the install prompt.
}

export function renderHeaderIcon(): HTMLElement {
  const svg = generateIconSvg(32)
  const wrapper = document.createElement('div')
  wrapper.style.cssText = 'width:28px;height:28px;flex-shrink:0;'
  wrapper.innerHTML = svg
  const svgEl = wrapper.querySelector('svg')
  if (svgEl) {
    svgEl.style.width = '28px'
    svgEl.style.height = '28px'
    svgEl.style.borderRadius = '4px'
  }
  return wrapper
}
