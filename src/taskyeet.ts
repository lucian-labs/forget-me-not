import { getTasks, getTask, getUrgencyRatio, getSettings, resetTask } from './store'
import { resolveTheme, getTheme } from './themes'
import { formatCadence } from './utils'
import type { Task, ThemeColors } from './types'

// Three.js r149 — last version with IIFE global build
const CDN = 'https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js'

let frameId: number | null = null
let cleanupFns: (() => void)[] = []

function loadThree(): Promise<void> {
  if ((window as any).THREE) return Promise.resolve()
  return new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = CDN
    s.onload = () => resolve()
    s.onerror = () => reject(new Error('Failed to load Three.js'))
    document.head.appendChild(s)
  })
}

function destroy(): void {
  if (frameId !== null) {
    cancelAnimationFrame(frameId)
    frameId = null
  }
  cleanupFns.forEach((fn) => fn())
  cleanupFns = []
}

// Sound — lazy-init its own YamaBruh instance so it works even if
// the YamaBruh CDN script hasn't finished loading when renderVibe starts.
// Re-tries on each call until the class appears on window.
function createSoundPlayer(): (id: string) => void {
  let player: any = null
  let dead = false

  function ensure(): boolean {
    if (player) return true
    if (dead) return false
    const YBN = (window as any).YamaBruhNotify
    if (!YBN) return false
    try {
      const raw = localStorage.getItem('fmn-settings')
      const s = raw ? JSON.parse(raw) : {}
      if (s.soundEnabled === false) { dead = true; return false }
      player = new YBN({
        seed: 'VIBE-MODE-420',
        preset: s.soundPreset ?? 88,
        bpm: Math.min((s.soundBpm ?? 160) + 40, 220),
        volume: Math.min((s.soundVolume ?? 0.4) + 0.1, 1),
        mode: s.soundMode ?? 1,
      })
      return true
    } catch {
      dead = true
      return false
    }
  }

  return (id: string) => {
    if (ensure()) player.play(id)
  }
}

const WISDOM = [
  'WAGMI', 'TO THE MOON', 'DIAMOND HANDS', 'HODL',
  'BULLISH', 'NFA', 'PRODUCTIVITY YIELD: 420%',
  'DECENTRALIZED TASKS', 'PROOF OF WORK', 'TASK YIELD: \u221E',
  'WEB3 TODO', 'MINT YOUR TODOS', 'GM', 'LFG',
  'PROBABLY NOTHING', 'FEW UNDERSTAND', 'SER',
]

function createCardTexture(T: any, task: Task, urgency: number, colors: ThemeColors, hFont: string, bFont: string): any {
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 256
  const ctx = canvas.getContext('2d')!

  // Card bg from theme surface with transparency
  ctx.fillStyle = colors.surface + 'a0'
  ctx.fillRect(0, 0, 512, 256)

  const urgColor = urgency >= 0.95 ? colors.red : urgency >= 0.75 ? colors.orange : colors.green
  ctx.shadowColor = urgColor
  ctx.shadowBlur = 12
  ctx.strokeStyle = urgColor
  ctx.lineWidth = 3
  ctx.strokeRect(4, 4, 504, 248)
  ctx.shadowBlur = 0

  const pColors: Record<string, string> = { critical: colors.red, high: colors.orange, normal: colors.accent, low: colors.dim }
  ctx.fillStyle = pColors[task.priority] ?? colors.accent
  ctx.font = `bold 16px '${bFont}', monospace`
  ctx.fillText(task.priority.toUpperCase(), 16, 30)

  ctx.fillStyle = colors.dim
  ctx.font = `14px '${bFont}', monospace`
  ctx.textAlign = 'right'
  ctx.fillText(task.status.replace('_', ' ').toUpperCase(), 496, 30)
  ctx.textAlign = 'left'

  // Title uses header font
  ctx.fillStyle = colors.text
  ctx.font = `bold 26px '${hFont}', sans-serif`
  const words = task.title.split(' ')
  let line = ''
  let y = 75
  for (const w of words) {
    const test = line + w + ' '
    if (ctx.measureText(test).width > 470 && line) {
      ctx.fillText(line.trim(), 16, y)
      line = w + ' '
      y += 34
      if (y > 180) break
    } else {
      line = test
    }
  }
  if (y <= 180) ctx.fillText(line.trim(), 16, y)

  if (task.domain) {
    ctx.fillStyle = colors.cyan
    ctx.font = `14px '${bFont}', monospace`
    ctx.fillText(`#${task.domain}`, 16, 230)
  }

  ctx.fillStyle = urgColor
  ctx.fillRect(0, 250, 512 * Math.min(urgency, 1), 6)

  return new T.CanvasTexture(canvas)
}

function createLensFlare(T: any, accentColor?: string): any {
  const ac = accentColor || '#00ffcc'
  // Parse hex to rgb for gradient
  const hr = parseInt(ac.slice(1, 3), 16), hg = parseInt(ac.slice(3, 5), 16), hb = parseInt(ac.slice(5, 7), 16)
  const c = document.createElement('canvas')
  c.width = 128
  c.height = 128
  const ctx = c.getContext('2d')!
  const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64)
  g.addColorStop(0, `rgba(${hr},${hg},${hb},0.6)`)
  g.addColorStop(0.2, `rgba(${hr},${hg},${hb},0.2)`)
  g.addColorStop(0.5, `rgba(${hr},${hg},${hb},0.05)`)
  g.addColorStop(1, 'rgba(0,0,0,0)')
  ctx.fillStyle = g
  ctx.fillRect(0, 0, 128, 128)
  const mat = new T.SpriteMaterial({ map: new T.CanvasTexture(c), transparent: true, blending: T.AdditiveBlending })
  const sprite = new T.Sprite(mat)
  sprite.scale.set(6, 6, 1)
  return sprite
}

// --- Particle system ---
interface Particle {
  mesh: any
  vx: number; vy: number; vz: number
  life: number
  maxLife: number
}

const particles: Particle[] = []

function spawnExplosion(T: any, scene: any, pos: any, count: number): void {
  for (let i = 0; i < count; i++) {
    const geo = new T.SphereGeometry(0.05 + Math.random() * 0.07, 4, 4)
    const mat = new T.MeshBasicMaterial({
      color: new T.Color().setHSL(Math.random(), 1, 0.6),
      transparent: true,
      opacity: 1,
    })
    const mesh = new T.Mesh(geo, mat)
    mesh.position.set(pos.x, pos.y, pos.z)
    scene.add(mesh)
    particles.push({
      mesh,
      vx: (Math.random() - 0.5) * 12,
      vy: (Math.random() - 0.5) * 12,
      vz: (Math.random() - 0.5) * 12,
      life: 1.0 + Math.random() * 0.8,
      maxLife: 1.8,
    })
  }
}

function updateParticles(scene: any, dt: number): void {
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i]
    p.life -= dt
    if (p.life <= 0) {
      scene.remove(p.mesh)
      p.mesh.geometry.dispose()
      p.mesh.material.dispose()
      particles.splice(i, 1)
      continue
    }
    p.mesh.position.x += p.vx * dt
    p.mesh.position.y += p.vy * dt
    p.mesh.position.z += p.vz * dt
    p.vx *= 0.96
    p.vy *= 0.96
    p.vz *= 0.96
    p.vy -= 3 * dt
    const r = p.life / p.maxLife
    p.mesh.material.opacity = r
    p.mesh.scale.setScalar(r)
  }
}

function shakeScreen(el: HTMLElement, intensity: number, duration: number): void {
  const start = performance.now()
  const tick = () => {
    const t = performance.now() - start
    if (t > duration) { el.style.transform = ''; return }
    const d = 1 - t / duration
    el.style.transform = `translate(${(Math.random() - 0.5) * intensity * d}px, ${(Math.random() - 0.5) * intensity * d}px)`
    requestAnimationFrame(tick)
  }
  tick()
}

// =====================
// MAIN RENDER
// =====================

export async function renderVibe(container: HTMLElement): Promise<void> {
  destroy()

  // Hide footer
  const footer = document.querySelector('.fmn-footer') as HTMLElement | null
  if (footer) footer.style.display = 'none'
  cleanupFns.push(() => { if (footer) footer.style.display = '' })

  container.innerHTML = `
    <div style="display:flex;flex-direction:column;align-items:center;justify-content:center;
      height:100vh;background:#000011;font-family:monospace;color:#00ffcc;">
      <div style="font-size:48px;text-shadow:0 0 40px #00ffcc;margin-bottom:16px;">\u2726</div>
      <div style="font-size:20px;text-shadow:0 0 20px #00ffcc;">LOADING THE VIBES...</div>
    </div>`

  try {
    await loadThree()
  } catch {
    container.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:center;
        height:100vh;background:#000011;font-family:monospace;color:#ff0040;">
        VIBES FAILED TO LOAD. YOUR ENERGY IS INSUFFICIENT.
      </div>`
    return
  }

  const T = (window as any).THREE
  const tasks = getTasks().filter((t) => t.status !== 'archived' && t.status !== 'cancelled' && t.status !== 'done')
  document.title = '\u2726 TASK YEET \u2726'
  cleanupFns.push(() => { document.title = getSettings().appName || 'forget me not' })
  const playSound = createSoundPlayer()

  // Resolve current theme
  const settings = getSettings()
  const theme = resolveTheme(settings)
  const themeBase = getTheme(settings.themePreset, settings)
  const tc = theme.colors
  const headerFont = theme.headerFont || 'monospace'
  const bodyFont = theme.bodyFont || 'monospace'

  // Parse theme bg to a Three.js-friendly hex
  function cssToHex(css: string): number {
    const c = css.replace('#', '')
    return parseInt(c.length === 3 ? c.split('').map((x) => x + x).join('') : c, 16)
  }
  const bgHex = cssToHex(tc.bg)
  const accentHex = cssToHex(tc.accent)
  const cyanHex = cssToHex(tc.cyan)
  const greenHex = cssToHex(tc.green)
  const orangeHex = cssToHex(tc.orange)
  const redHex = cssToHex(tc.red)

  container.innerHTML = ''

  // --- Wrapper ---
  const wrap = document.createElement('div')
  wrap.style.cssText = `width:100%;height:100vh;position:relative;overflow:hidden;background:${tc.bg};`
  container.appendChild(wrap)

  // --- Three.js ---
  const scene = new T.Scene()
  scene.fog = new T.FogExp2(bgHex, 0.012)
  scene.background = new T.Color(bgHex)

  const camera = new T.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 500)
  camera.position.set(0, 30, 60) // start far for entry sweep

  const renderer = new T.WebGLRenderer({ antialias: true })
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.toneMapping = T.ACESFilmicToneMapping
  renderer.toneMappingExposure = 1.5
  renderer.domElement.style.display = 'block'
  wrap.appendChild(renderer.domElement)

  // CSS overlays for glow / vignette / scanlines
  const layers = [
    `position:absolute;inset:0;pointer-events:none;z-index:1;
     background:radial-gradient(ellipse at 50% 40%,${tc.accent}08 0%,transparent 60%);
     mix-blend-mode:screen;`,
    `position:absolute;inset:0;pointer-events:none;z-index:2;
     background:radial-gradient(ellipse at center,transparent 40%,${tc.bg}cc 100%);`,
    `position:absolute;inset:0;pointer-events:none;z-index:3;opacity:0.04;
     background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,0.3) 2px,rgba(0,0,0,0.3) 4px);`,
  ]
  layers.forEach((css) => {
    const d = document.createElement('div')
    d.style.cssText = css
    wrap.appendChild(d)
  })

  // Vibe CSS
  const style = document.createElement('style')
  style.textContent = `
    @keyframes vibeGrad{0%{background-position:0% 50%}100%{background-position:200% 50%}}
    @keyframes vibePulse{0%,100%{text-shadow:0 0 20px #00ffcc,0 0 40px #00ffcc}50%{text-shadow:0 0 40px #00ffcc,0 0 80px #ff00ff}}
    .vibe-tip{position:absolute;pointer-events:none;z-index:20;display:none;
      background:${tc.surface}ee;border:1px solid ${tc.accent};color:${tc.text};
      font:13px '${bodyFont}',monospace;padding:12px 16px;border-radius:4px;
      backdrop-filter:blur(10px);box-shadow:0 0 20px ${tc.accent}50;max-width:280px;}
    #vibe-exit:hover{background:${tc.accent}33!important;border-color:${tc.accent}!important;}
  `
  document.head.appendChild(style)
  cleanupFns.push(() => style.remove())

  // HUD
  const hud = document.createElement('div')
  hud.style.cssText = `position:absolute;inset:0;pointer-events:none;z-index:10;font-family:'${bodyFont}',monospace;color:${tc.text};`
  hud.innerHTML = `
    <div style="padding:20px;display:flex;justify-content:space-between;align-items:flex-start;">
      <div>
        <div style="font-size:42px;font-weight:bold;font-family:'${headerFont}',sans-serif;
          background:linear-gradient(90deg,${tc.accent},${tc.cyan},${tc.orange},${tc.accent});
          -webkit-background-clip:text;-webkit-text-fill-color:transparent;
          background-size:200%;animation:vibeGrad 3s linear infinite;">
          \u2726 TASK YEET \u2726
        </div>
        <div style="font-size:11px;opacity:0.35;margin-top:4px;">powered by web3 productivity protocol\u2122</div>
      </div>
      <div style="text-align:right;">
        <div style="font-size:10px;opacity:0.4;">TASK PORTFOLIO VALUE</div>
        <div style="font-size:28px;font-weight:bold;color:${tc.green};">${tasks.length} TASKS</div>
        <div style="font-size:13px;color:${tc.green};">\u25B2 ${(Math.random() * 900 + 100).toFixed(1)}% (24h)</div>
        <div style="font-size:10px;opacity:0.25;margin-top:2px;">TVL: $${(Math.random() * 99 + 1).toFixed(2)}B</div>
      </div>
    </div>
    <div style="position:absolute;bottom:20px;left:20px;pointer-events:auto;">
      <button id="vibe-exit" style="background:${tc.accent}14;border:1px solid ${tc.accent}60;
        color:${tc.accent};padding:10px 20px;font:14px '${bodyFont}',monospace;cursor:pointer;
        backdrop-filter:blur(10px);border-radius:4px;transition:all .2s;">
        \u2190 BACK TO REALITY</button>
    </div>
    <div style="position:absolute;bottom:20px;right:20px;font-size:9px;opacity:0.12;color:${tc.dim};">
      NOT FINANCIAL ADVICE \u00B7 DYOR \u00B7 NFA \u00B7 PAST PERFORMANCE \u2260 FUTURE RESULTS
    </div>
    <div id="vibe-combo" style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
      font-size:80px;font-weight:bold;opacity:0;transition:opacity .3s;
      text-shadow:0 0 40px ${tc.accent},0 0 80px ${tc.accent};color:${tc.accent};pointer-events:none;"></div>`
  wrap.appendChild(hud)

  const tooltip = document.createElement('div')
  tooltip.className = 'vibe-tip'
  wrap.appendChild(tooltip)

  // === LIGHTS ===
  scene.add(new T.AmbientLight(bgHex, 0.5))
  const ptLights = [
    new T.PointLight(accentHex, 2, 60),
    new T.PointLight(cyanHex, 1.5, 60),
    new T.PointLight(orangeHex, 1, 60),
    new T.PointLight(greenHex, 1.2, 60),
  ]
  ptLights[0].position.set(10, 5, 10)
  ptLights[1].position.set(-10, 3, -10)
  ptLights[2].position.set(0, -5, 5)
  ptLights[3].position.set(5, 8, -5)
  ptLights.forEach((l) => scene.add(l))

  // === NEON GRID ===
  const grid = new T.GridHelper(120, 100, accentHex, cssToHex(tc.border))
  grid.position.y = -6
  const gMats = Array.isArray(grid.material) ? grid.material : [grid.material]
  gMats.forEach((m: any) => { m.opacity = 0.3; m.transparent = true })
  scene.add(grid)

  // === STARFIELD — big colorful tracer stars ===
  const starN = 6000
  const starGeo = new T.BufferGeometry()
  const starPos = new Float32Array(starN * 3)
  const starColors = new Float32Array(starN * 3)
  const starVel: number[] = []
  const starHues = [
    [0.5, 1, 1],     // cyan
    [0.83, 1, 0.8],  // magenta
    [0.15, 1, 1],    // yellow
    [0.6, 0.6, 1],   // blue-white
    [0, 0, 1],       // pure white
    [0.95, 1, 0.9],  // pink
    [0.3, 1, 0.9],   // green
  ]
  for (let i = 0; i < starN; i++) {
    starPos[i * 3] = (Math.random() - 0.5) * 400
    starPos[i * 3 + 1] = (Math.random() - 0.5) * 400
    starPos[i * 3 + 2] = (Math.random() - 0.5) * 400
    const hue = starHues[Math.floor(Math.random() * starHues.length)]
    const c = new T.Color().setHSL(hue[0], hue[1], hue[2])
    starColors[i * 3] = c.r
    starColors[i * 3 + 1] = c.g
    starColors[i * 3 + 2] = c.b
    // Velocity for tracer effect (streaming toward camera)
    starVel.push(0, 0, (Math.random() * 0.8 + 0.2))
  }
  starGeo.setAttribute('position', new T.BufferAttribute(starPos, 3))
  starGeo.setAttribute('color', new T.BufferAttribute(starColors, 3))
  const starPts = new T.Points(starGeo, new T.PointsMaterial({
    size: 0.4,
    transparent: true,
    opacity: 0.85,
    vertexColors: true,
    sizeAttenuation: true,
  }))
  scene.add(starPts)

  // === NEBULAE — volumetric color blobs ===
  const nebulaColors = [0x00ffcc, 0xff00ff, 0x4400ff, 0xff4400, 0x00aaff, 0xff0066]
  for (let i = 0; i < 8; i++) {
    const c = document.createElement('canvas')
    c.width = 256; c.height = 256
    const ctx = c.getContext('2d')!
    const color = nebulaColors[i % nebulaColors.length]
    const r = (color >> 16) & 255, g = (color >> 8) & 255, b = color & 255
    const grad = ctx.createRadialGradient(128, 128, 0, 128, 128, 128)
    grad.addColorStop(0, `rgba(${r},${g},${b},0.15)`)
    grad.addColorStop(0.3, `rgba(${r},${g},${b},0.07)`)
    grad.addColorStop(0.6, `rgba(${r},${g},${b},0.02)`)
    grad.addColorStop(1, 'rgba(0,0,0,0)')
    ctx.fillStyle = grad
    ctx.fillRect(0, 0, 256, 256)
    const sp = new T.Sprite(new T.SpriteMaterial({
      map: new T.CanvasTexture(c),
      transparent: true,
      blending: T.AdditiveBlending,
      depthWrite: false,
    }))
    const scale = 30 + Math.random() * 60
    sp.scale.set(scale, scale, 1)
    sp.position.set(
      (Math.random() - 0.5) * 150,
      (Math.random() - 0.5) * 100,
      (Math.random() - 0.5) * 150 - 40,
    )
    scene.add(sp)
  }

  // === DUST — colorful cyberpunk particles ===
  const dustN = 600
  const dustArr = new Float32Array(dustN * 3)
  const dustCol = new Float32Array(dustN * 3)
  const dustVel: number[] = []
  for (let i = 0; i < dustN; i++) {
    dustArr[i * 3] = (Math.random() - 0.5) * 40
    dustArr[i * 3 + 1] = (Math.random() - 0.5) * 20
    dustArr[i * 3 + 2] = (Math.random() - 0.5) * 40
    dustVel.push((Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.02, (Math.random() - 0.5) * 0.02)
    const dc = new T.Color().setHSL(Math.random(), 0.8, 0.6)
    dustCol[i * 3] = dc.r; dustCol[i * 3 + 1] = dc.g; dustCol[i * 3 + 2] = dc.b
  }
  const dustGeo = new T.BufferGeometry()
  dustGeo.setAttribute('position', new T.BufferAttribute(dustArr, 3))
  dustGeo.setAttribute('color', new T.BufferAttribute(dustCol, 3))
  const dustPts = new T.Points(dustGeo, new T.PointsMaterial({
    size: 0.08,
    transparent: true,
    opacity: 0.6,
    vertexColors: true,
    sizeAttenuation: true,
  }))
  scene.add(dustPts)

  // === LENS FLARE ===
  const flare = createLensFlare(T, tc.accent)
  scene.add(flare)

  // === LOW-POLY PLANETS WITH WISDOM LABELS ===
  interface CelestialBody { group: any; label: any; speed: number; orbitR: number; orbitOff: number }
  const celestials: CelestialBody[] = []
  const bodyColors = [accentHex, cyanHex, orangeHex, greenHex, redHex, 0x8844ff, 0xff66aa, 0x44aaff]

  for (let i = 0; i < 10; i++) {
    const group = new T.Group()
    const bodySize = 0.8 + Math.random() * 2.5
    const detail = Math.floor(Math.random() * 2) + 1 // low-poly: 1 or 2 subdivisions
    const isMoon = i > 5
    const geo = isMoon
      ? new T.IcosahedronGeometry(bodySize, detail)
      : new T.DodecahedronGeometry(bodySize, detail)
    const mat = new T.MeshStandardMaterial({
      color: bodyColors[i % bodyColors.length],
      flatShading: true,
      metalness: 0.2,
      roughness: 0.6,
    })
    // Distort vertices for organic look
    const posAttr = geo.attributes.position
    for (let v = 0; v < posAttr.count; v++) {
      const x = posAttr.getX(v), y = posAttr.getY(v), z = posAttr.getZ(v)
      const noise = 1 + (Math.random() - 0.5) * 0.3
      posAttr.setXYZ(v, x * noise, y * noise, z * noise)
    }
    geo.computeVertexNormals()
    const body = new T.Mesh(geo, mat)
    group.add(body)

    // Optional ring for some planets
    if (!isMoon && Math.random() > 0.5) {
      const ringGeo = new T.RingGeometry(bodySize * 1.4, bodySize * 1.9, 24)
      const ringMat = new T.MeshBasicMaterial({ color: bodyColors[i % bodyColors.length], transparent: true, opacity: 0.2, side: T.DoubleSide })
      const ring = new T.Mesh(ringGeo, ringMat)
      ring.rotation.x = Math.PI / 2 + (Math.random() - 0.5) * 0.5
      group.add(ring)
    }

    // Bright label sprite
    const labelCanvas = document.createElement('canvas')
    labelCanvas.width = 1024; labelCanvas.height = 128
    const lx = labelCanvas.getContext('2d')!
    lx.fillStyle = tc.text
    lx.font = `bold 64px '${headerFont}', sans-serif`
    lx.textAlign = 'center'
    lx.textBaseline = 'middle'
    lx.fillText(WISDOM[i % WISDOM.length], 512, 64)
    const labelTex = new T.CanvasTexture(labelCanvas)
    const label = new T.Sprite(new T.SpriteMaterial({ map: labelTex, transparent: true, opacity: 0.85 }))
    label.scale.set(16, 2, 1)
    label.position.y = bodySize + 2.5
    group.add(label)

    const orbitR = 25 + Math.random() * 50
    const orbitOff = Math.random() * Math.PI * 2
    const py = (Math.random() - 0.5) * 30
    group.position.set(Math.cos(orbitOff) * orbitR, py, Math.sin(orbitOff) * orbitR)
    scene.add(group)
    celestials.push({ group, label, speed: 0.01 + Math.random() * 0.03, orbitR, orbitOff })
  }

  // === TASK CARDS ===
  interface CardInfo {
    mesh: any
    wire: any
    task: Task
    urgency: number
    ox: number; oy: number; oz: number
    targetY: number
    baseScale: number
    targetScale: number
    idx: number
    hovered: boolean
    sinking: boolean
  }

  const cards: CardInfo[] = []
  const phi = Math.PI * (3 - Math.sqrt(5))

  tasks.forEach((task, i) => {
    const urg = getUrgencyRatio(task)
    const tex = createCardTexture(T, task, urg, tc, headerFont, bodyFont)

    const glassMat = new T.MeshPhysicalMaterial({
      color: 0xffffff,
      metalness: 0.05,
      roughness: 0.08,
      transmission: 0.88,
      thickness: 0.4,
      transparent: true,
      side: T.DoubleSide,
    })
    const textMat = new T.MeshBasicMaterial({ map: tex, transparent: true, side: T.FrontSide, depthWrite: false })

    // Scale card size by urgency: more urgent = bigger
    const baseScale = 0.6 + Math.min(urg, 1.5) * 0.7
    const geo = new T.BoxGeometry(4, 2, 0.08)
    const mesh = new T.Mesh(geo, [glassMat, glassMat, glassMat, glassMat, textMat, glassMat])

    // Wireframe glow — theme urgency colors
    const wColor = urg >= 0.95 ? redHex : urg >= 0.75 ? orangeHex : greenHex
    const wireGeo = new T.BoxGeometry(4.15, 2.1, 0.12)
    const wireMat = new T.MeshBasicMaterial({ color: wColor, wireframe: true, transparent: true, opacity: 0.25 })
    const wire = new T.Mesh(wireGeo, wireMat)
    mesh.add(wire)

    // Spiral XZ, urgency-driven Y: more urgent = higher
    const angle = i * phi
    const r = 3 + Math.sqrt(i + 1) * 2.2
    const x = r * Math.cos(angle)
    const z = r * Math.sin(angle)
    const y = -4 + Math.min(urg, 1.5) * 8 // range: -4 (fresh) to +8 (overdue)

    mesh.position.set(x, y, z)
    mesh.scale.setScalar(baseScale)
    mesh.userData = { taskId: task.id, idx: i }
    scene.add(mesh)

    cards.push({ mesh, wire, task, urgency: urg, ox: x, oy: y, oz: z, targetY: y, baseScale, targetScale: baseScale, idx: i, hovered: false, sinking: false })
  })

  // === RAYCASTER & EVENTS ===
  const ray = new T.Raycaster()
  const mVec = new T.Vector2(9999, 9999)
  let hCard: CardInfo | null = null
  let combo = 0
  let comboTimer: ReturnType<typeof setTimeout> | null = null

  function onMove(e: MouseEvent): void {
    mVec.x = (e.clientX / window.innerWidth) * 2 - 1
    mVec.y = -(e.clientY / window.innerHeight) * 2 + 1
    ray.setFromCamera(mVec, camera)
    const hits = ray.intersectObjects(cards.map((c) => c.mesh))

    if (hits.length > 0) {
      const card = cards.find((c) => c.mesh === hits[0].object || c.mesh === hits[0].object.parent)
      if (card && card !== hCard) {
        if (hCard) hCard.hovered = false
        card.hovered = true
        hCard = card
        renderer.domElement.style.cursor = 'pointer'
        playSound('hover-' + card.idx)
        tooltip.style.display = 'block'
        const cadenceStr = card.task.cadenceSeconds ? `every ${formatCadence(card.task.cadenceSeconds)}` : ''
        const urgRaw = card.urgency
        const urgPct = Math.round(Math.min(urgRaw, 1) * 100)
        const urgColor = urgRaw >= 0.95 ? tc.red : urgRaw >= 0.75 ? tc.orange : tc.green
        const urgLabel = urgRaw >= 1 ? 'OVERDUE' : `${urgPct}%`
        tooltip.innerHTML = `<div style="font-weight:bold;margin-bottom:6px;">${card.task.title}</div>
          <div style="font-size:11px;opacity:0.6;">${card.task.priority.toUpperCase()} \u00B7 ${card.task.status.replace('_', ' ').toUpperCase()}${card.task.domain ? ' \u00B7 #' + card.task.domain : ''}</div>
          ${cadenceStr ? `<div style="font-size:12px;margin-top:4px;color:${tc.cyan};">${cadenceStr}</div>` : ''}
          <div style="margin-top:6px;height:4px;background:${tc.border};border-radius:2px;overflow:hidden;">
            <div style="width:${Math.min(urgPct, 100)}%;height:100%;background:${urgColor};"></div>
          </div>
          <div style="font-size:10px;margin-top:4px;color:${urgColor};">${urgLabel}</div>
          <div style="margin-top:4px;font-size:10px;opacity:0.3;">CLICK TO YEET</div>`
      }
      tooltip.style.left = e.clientX + 16 + 'px'
      tooltip.style.top = e.clientY + 16 + 'px'
    } else {
      if (hCard) { hCard.hovered = false; hCard = null }
      renderer.domElement.style.cursor = 'default'
      tooltip.style.display = 'none'
    }
  }

  // Refresh a card's visuals after its task data changes
  function refreshCard(card: CardInfo): void {
    const updated = getTask(card.task.id)
    if (!updated) return
    card.task = updated
    card.urgency = getUrgencyRatio(updated)

    // Rebuild texture
    const newTex = createCardTexture(T, updated, card.urgency, tc, headerFont, bodyFont)
    const mats = card.mesh.material as any[]
    mats[4].map.dispose()
    mats[4].map = newTex
    mats[4].needsUpdate = true

    // Update wireframe color
    const wColor = card.urgency >= 0.95 ? redHex : card.urgency >= 0.75 ? orangeHex : greenHex
    card.wire.material.color.setHex(wColor)

    // New urgency-driven Y and scale
    const newY = -4 + Math.min(card.urgency, 1.5) * 8
    const newScale = 0.6 + Math.min(card.urgency, 1.5) * 0.7
    card.targetY = newY
    card.oy = newY
    card.baseScale = newScale
    card.targetScale = newScale
    card.sinking = false
  }

  function onClickCanvas(): void {
    if (!hCard) return
    const card = hCard

    // Actually reset the task
    resetTask(card.task.id, 'reset from vibe mode')

    spawnExplosion(T, scene, card.mesh.position, 80)
    shakeScreen(wrap, 30, 700)

    // Fireworks
    setTimeout(() => {
      const p = card.mesh.position
      spawnExplosion(T, scene, { x: p.x + 3, y: p.y + 4, z: p.z }, 40)
      playSound('FIREWORK-A-' + card.idx)
    }, 250)
    setTimeout(() => {
      const p = card.mesh.position
      spawnExplosion(T, scene, { x: p.x - 2, y: p.y + 6, z: p.z + 2 }, 40)
      playSound('FIREWORK-B-' + card.idx)
    }, 500)
    setTimeout(() => {
      const p = card.mesh.position
      spawnExplosion(T, scene, { x: p.x + 1, y: p.y + 8, z: p.z - 3 }, 50)
      playSound('FIREWORK-C-' + card.idx)
    }, 750)

    // Flash overlay
    const flash = document.createElement('div')
    flash.style.cssText = 'position:absolute;inset:0;background:white;opacity:0.4;z-index:5;pointer-events:none;transition:opacity 0.4s;'
    wrap.appendChild(flash)
    requestAnimationFrame(() => { flash.style.opacity = '0' })
    setTimeout(() => flash.remove(), 500)

    playSound('BOOM-' + card.task.id)
    setTimeout(() => playSound('POW-' + card.idx), 100)
    setTimeout(() => playSound('BAM-' + card.idx + 'x'), 200)

    // Send it to the bottom first, then refresh after animation
    card.sinking = true
    card.targetY = -8
    card.targetScale = 0.3

    // After sink animation, refresh card with new data and float it back up
    setTimeout(() => refreshCard(card), 1500)

    combo++
    if (comboTimer) clearTimeout(comboTimer)
    comboTimer = setTimeout(() => { combo = 0 }, 2000)
    const comboEl = document.getElementById('vibe-combo')
    if (comboEl && combo > 1) {
      comboEl.textContent = `${combo}x COMBO`
      comboEl.style.opacity = '1'
      setTimeout(() => { if (comboEl) comboEl.style.opacity = '0' }, 800)
    }
  }

  renderer.domElement.addEventListener('mousemove', onMove)
  renderer.domElement.addEventListener('click', onClickCanvas)
  cleanupFns.push(() => {
    renderer.domElement.removeEventListener('mousemove', onMove)
    renderer.domElement.removeEventListener('click', onClickCanvas)
  })

  document.getElementById('vibe-exit')?.addEventListener('click', () => {
    destroy()
    history.pushState(null, '', '/')
    window.dispatchEvent(new PopStateEvent('popstate'))
  })

  function onResize(): void {
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix()
    renderer.setSize(window.innerWidth, window.innerHeight)
  }
  window.addEventListener('resize', onResize)
  cleanupFns.push(() => window.removeEventListener('resize', onResize))
  cleanupFns.push(() => { renderer.dispose(); particles.length = 0 })

  // === ANIMATION LOOP ===
  const clock = new T.Clock()
  let camAngle = 0
  let entryDone = false

  function animate(): void {
    if (!wrap.isConnected) { destroy(); return }
    frameId = requestAnimationFrame(animate)

    const dt = Math.min(clock.getDelta(), 0.05)
    const time = clock.getElapsedTime()

    // Camera entry sweep
    if (!entryDone) {
      camera.position.x += (0 - camera.position.x) * dt * 1.2
      camera.position.y += (8 - camera.position.y) * dt * 1.2
      camera.position.z += (28 - camera.position.z) * dt * 1.2
      if (Math.abs(camera.position.z - 28) < 0.5) entryDone = true
    } else {
      camAngle += dt * 0.06
      camera.position.x = Math.sin(camAngle) * 28
      camera.position.z = Math.cos(camAngle) * 28
      camera.position.y = 8 + Math.sin(time * 0.2) * 2
    }
    camera.lookAt(0, 0, 0)

    // Orbit lights
    ptLights[0].position.set(Math.sin(time * 0.4) * 14, 6, Math.cos(time * 0.4) * 14)
    ptLights[1].position.set(Math.sin(time * 0.3 + 2) * 12, 4, Math.cos(time * 0.3 + 2) * 12)
    ptLights[2].position.set(Math.sin(time * 0.6 + 4) * 10, -3, Math.cos(time * 0.6 + 4) * 10)
    ptLights[3].position.set(Math.sin(time * 0.5 + 6) * 8, 7, Math.cos(time * 0.5 + 6) * 8)

    // Animate cards
    for (const card of cards) {
      // Lerp Y toward target (urgency position or sunk bottom)
      const bob = Math.sin(time * 0.7 + card.idx * 0.5) * 0.3
      const goalY = card.targetY + bob
      card.mesh.position.y += (goalY - card.mesh.position.y) * dt * 3

      // Lerp scale toward target (urgency base or shrunk)
      const hoverBoost = card.hovered ? 1.25 : 1
      const goalScale = card.targetScale * hoverBoost
      const curScale = card.mesh.scale.x
      card.mesh.scale.setScalar(curScale + (goalScale - curScale) * dt * 6)

      // Billboard: always face camera
      card.mesh.quaternion.copy(camera.quaternion)
    }

    // Mouse repulsion: nearby cards push away from hovered card
    if (hCard) {
      const hx = hCard.mesh.position.x
      const hz = hCard.mesh.position.z
      for (const card of cards) {
        if (card === hCard) continue
        const dx = card.mesh.position.x - hx
        const dz = card.mesh.position.z - hz
        const dist = Math.sqrt(dx * dx + dz * dz)
        if (dist < 6 && dist > 0) {
          const push = ((6 - dist) / 6) * 0.4
          card.mesh.position.x = card.ox + (dx / dist) * push
          card.mesh.position.z = card.oz + (dz / dist) * push
        }
      }
    }

    // Dust
    const dArr = dustPts.geometry.attributes.position.array as Float32Array
    for (let i = 0; i < dustN; i++) {
      dArr[i * 3] += dustVel[i * 3]
      dArr[i * 3 + 1] += dustVel[i * 3 + 1]
      dArr[i * 3 + 2] += dustVel[i * 3 + 2]
      for (let j = 0; j < 3; j++) {
        if (dArr[i * 3 + j] > 20) dArr[i * 3 + j] = -20
        if (dArr[i * 3 + j] < -20) dArr[i * 3 + j] = 20
      }
    }
    dustPts.geometry.attributes.position.needsUpdate = true

    // Star tracers — stream toward camera
    const sArr = starPts.geometry.attributes.position.array as Float32Array
    for (let i = 0; i < starN; i++) {
      sArr[i * 3 + 2] += starVel[i * 3 + 2] * dt * 40
      if (sArr[i * 3 + 2] > 200) {
        sArr[i * 3] = (Math.random() - 0.5) * 400
        sArr[i * 3 + 1] = (Math.random() - 0.5) * 400
        sArr[i * 3 + 2] = -200
      }
    }
    starPts.geometry.attributes.position.needsUpdate = true

    // Orbit celestial bodies & spin them
    for (const cb of celestials) {
      cb.orbitOff += cb.speed * dt
      cb.group.position.x = Math.cos(cb.orbitOff) * cb.orbitR
      cb.group.position.z = Math.sin(cb.orbitOff) * cb.orbitR
      cb.group.children[0].rotation.y += dt * 0.3
      cb.group.children[0].rotation.x += dt * 0.1
      // Labels always face camera
      cb.label.quaternion.copy(camera.quaternion)
    }

    // Grid pulse
    gMats.forEach((m: any) => { m.opacity = 0.15 + Math.sin(time * 1.5) * 0.1 })

    // Flare tracks first light
    flare.position.copy(ptLights[0].position)

    updateParticles(scene, dt)

    renderer.render(scene, camera)
  }

  // Entry sound burst
  playSound('VIBE-INIT-' + Date.now())
  setTimeout(() => playSound('VIBE-DROP'), 300)
  setTimeout(() => playSound('VIBE-BASS'), 600)

  animate()

  // Empty state
  if (tasks.length === 0) {
    const empty = document.createElement('div')
    empty.style.cssText = `position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);z-index:15;
      text-align:center;font-family:monospace;color:#00ffcc;pointer-events:none;`
    empty.innerHTML = `
      <div style="font-size:64px;margin-bottom:16px;">\uD83D\uDCED</div>
      <div style="font-size:24px;text-shadow:0 0 20px #00ffcc;">NO TASKS IN YOUR PORTFOLIO</div>
      <div style="font-size:14px;opacity:0.5;margin-top:8px;">bullish on procrastination</div>`
    wrap.appendChild(empty)
  }
}
