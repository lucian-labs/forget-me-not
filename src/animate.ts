import type { AnimStyle } from './types'
import { getSettings } from './store'
import { getTheme } from './themes'

function getAnimStyle(): AnimStyle {
  const settings = getSettings()
  return getTheme(settings.themePreset).animation
}

export function animateOut(element: HTMLElement): Promise<void> {
  const style = getAnimStyle()
  const cls = `fmn-anim-${style}`

  return new Promise((resolve) => {
    element.classList.add(cls)
    element.addEventListener('animationend', () => resolve(), { once: true })
    setTimeout(resolve, 800)
  })
}

export function animateIn(element: HTMLElement): void {
  const style = getAnimStyle()
  element.classList.add(`fmn-anim-enter-${style}`)
  element.addEventListener('animationend', () => {
    element.classList.remove(`fmn-anim-enter-${style}`)
  }, { once: true })
}
