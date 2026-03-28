import type { AnimStyle } from './types'
import { getSettings } from './store'
import { getTheme } from './themes'

function getAnimStyle(): AnimStyle {
  const settings = getSettings()
  return getTheme(settings.themePreset, settings).animation
}

export function animateOut(element: HTMLElement): Promise<void> {
  const style = getAnimStyle()
  const cls = `fmn-anim-${style}`

  return new Promise((resolve) => {
    // Capture height for smooth collapse
    const height = element.offsetHeight
    element.style.maxHeight = `${height}px`

    element.classList.add(cls)

    const collapse = () => {
      element.classList.add('fmn-collapsing')
      element.addEventListener('transitionend', () => resolve(), { once: true })
      // Safety timeout for collapse
      setTimeout(resolve, 400)
    }

    element.addEventListener('animationend', collapse, { once: true })
    // Safety timeout for animation
    setTimeout(collapse, 800)
  })
}

export function animateIn(element: HTMLElement): void {
  const style = getAnimStyle()
  element.classList.add(`fmn-anim-enter-${style}`)
  element.addEventListener('animationend', () => {
    element.classList.remove(`fmn-anim-enter-${style}`)
  }, { once: true })
}
