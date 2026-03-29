import { getTasks, getUrgencyRatio } from './store'
import type { Task } from './types'

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

// Sound — creates its own YamaBruh instance tuned for maximum chaos
function createSoundPlayer(): (id: string) => void {
  const YBN = (window as any).YamaBruhNotify
  if (!YBN) return () => {}
  try {
    const raw = localStorage.getItem('fmn-settings')
    const s = raw ? JSON.parse(raw) : {}
    if (s.soundEnabled === false) return () => {}
    const player = new YBN({
      seed: 'VIBE-MODE-420',
      preset: s.soundPreset ?? 88,
      bpm: Math.min((s.soundBpm ?? 160) + 40, 220),
      volume: Math.min((s.soundVolume ?? 0.4) + 0.1, 1),
      mode: s.soundMode ?? 1,
    })
    return (id: string) => player.play(id)
  } catch {
    return () => {}
  }
}

const WISDOM = [
  'WAGMI', 'TO THE MOON', 'DIAMOND HANDS', 'HODL',
  'BULLISH', 'NFA', 'PRODUCTIVITY YIELD: 420%',
  'DECENTRALIZED TASKS', 'PROOF OF WORK', 'TASK YIELD: \u221E',
  'WEB3 TODO', 'MINT YOUR TODOS', 'GM', 'LFG',
  'PROBABLY NOTHING', 'FEW UNDERSTAND', 'SER',
]

function createCardTexture(T: any, task: Task, urgency: number): any {
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 256
  const ctx = canvas.getContext('2d')!

  ctx.fillStyle = 'rgba(0, 10, 20, 0.6)'
  ctx.fillRect(0, 0, 512, 256)

  const color = urgency >= 0.95 ? '#ff0040' : urgency >= 0.75 ? '#ff8800' : '#00ffcc'
  ctx.shadowColor = color
  ctx.shadowBlur = 12
  ctx.strokeStyle = color
  ctx.lineWidth = 3
  ctx.strokeRect(4, 4, 504, 248)
  ctx.shadowBlur = 0

  const pColors: Record<string, string> = { critical: '#ff0040', high: '#ff8800', normal: '#00ffcc', low: '#555' }
  ctx.fillStyle = pColors[task.priority] ?? '#00ffcc'
  ctx.font = 'bold 16px monospace'
  ctx.fillText(task.priority.toUpperCase(), 16, 30)

  ctx.fillStyle = '#ffffff60'
  ctx.font = '14px monospace'
  ctx.textAlign = 'right'
  ctx.fillText(task.status.replace('_', ' ').toUpperCase(), 496, 30)
  ctx.textAlign = 'left'

  ctx.fillStyle = '#ffffff'
  ctx.font = 'bold 26px sans-serif'
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
    ctx.fillStyle = '#00ffcc80'
    ctx.font = '14px monospace'
    ctx.fillText(`#${task.domain}`, 16, 230)
  }

  ctx.fillStyle = color
  ctx.fillRect(0, 250, 512 * Math.min(urgency, 1), 6)

  return new T.CanvasTexture(canvas)
}

function createLensFlare(T: any): any {
  const c = document.createElement('canvas')
  c.width = 128
  c.height = 128
  const ctx = c.getContext('2d')!
  const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64)
  g.addColorStop(0, 'rgba(0,255,204,0.6)')
  g.addColorStop(0.2, 'rgba(0,255,204,0.2)')
  g.addColorStop(0.5, 'rgba(255,0,255,0.05)')
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
  const tasks = getTasks().filter((t) => t.status !== 'archived' && t.status !== 'cancelled')
  const playSound = createSoundPlayer()

  container.innerHTML = ''

  // --- Wrapper ---
  const wrap = document.createElement('div')
  wrap.style.cssText = 'width:100%;height:100vh;position:relative;overflow:hidden;background:#000011;'
  container.appendChild(wrap)

  // --- Three.js ---
  const scene = new T.Scene()
  scene.fog = new T.FogExp2(0x000011, 0.012)
  scene.background = new T.Color(0x000011)

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
     background:radial-gradient(ellipse at 50% 40%,rgba(0,255,204,0.03) 0%,transparent 60%);
     mix-blend-mode:screen;`,
    `position:absolute;inset:0;pointer-events:none;z-index:2;
     background:radial-gradient(ellipse at center,transparent 40%,rgba(0,0,10,0.7) 100%);`,
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
      background:rgba(0,0,20,0.92);border:1px solid #00ffcc;color:#00ffcc;
      font:13px monospace;padding:12px 16px;border-radius:4px;
      backdrop-filter:blur(10px);box-shadow:0 0 20px rgba(0,255,204,0.3);max-width:280px;}
    #vibe-exit:hover{background:rgba(0,255,204,0.2)!important;border-color:#00ffcc!important;}
  `
  document.head.appendChild(style)
  cleanupFns.push(() => style.remove())

  // HUD
  const hud = document.createElement('div')
  hud.style.cssText = 'position:absolute;inset:0;pointer-events:none;z-index:10;font-family:"Courier New",monospace;color:#00ffcc;'
  hud.innerHTML = `
    <div style="padding:20px;display:flex;justify-content:space-between;align-items:flex-start;">
      <div>
        <div style="font-size:42px;font-weight:bold;
          background:linear-gradient(90deg,#00ffcc,#ff00ff,#ffff00,#00ffcc);
          -webkit-background-clip:text;-webkit-text-fill-color:transparent;
          background-size:200%;animation:vibeGrad 3s linear infinite;">
          \u2726 VIBE MODE \u2726
        </div>
        <div style="font-size:11px;opacity:0.35;margin-top:4px;">powered by web3 productivity protocol\u2122</div>
      </div>
      <div style="text-align:right;">
        <div style="font-size:10px;opacity:0.4;">TASK PORTFOLIO VALUE</div>
        <div style="font-size:28px;font-weight:bold;color:#00ff88;">${tasks.length} TASKS</div>
        <div style="font-size:13px;color:#00ff88;">\u25B2 ${(Math.random() * 900 + 100).toFixed(1)}% (24h)</div>
        <div style="font-size:10px;opacity:0.25;margin-top:2px;">TVL: $${(Math.random() * 99 + 1).toFixed(2)}B</div>
      </div>
    </div>
    <div style="position:absolute;bottom:20px;left:20px;pointer-events:auto;">
      <button id="vibe-exit" style="background:rgba(0,255,204,0.08);border:1px solid #00ffcc40;
        color:#00ffcc;padding:10px 20px;font:14px monospace;cursor:pointer;
        backdrop-filter:blur(10px);border-radius:4px;transition:all .2s;">
        \u2190 BACK TO REALITY</button>
    </div>
    <div style="position:absolute;bottom:20px;right:20px;font-size:9px;opacity:0.12;">
      NOT FINANCIAL ADVICE \u00B7 DYOR \u00B7 NFA \u00B7 PAST PERFORMANCE \u2260 FUTURE RESULTS
    </div>
    <div id="vibe-combo" style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
      font-size:80px;font-weight:bold;opacity:0;transition:opacity .3s;
      text-shadow:0 0 40px #ff00ff,0 0 80px #ff00ff;color:#ff00ff;pointer-events:none;"></div>`
  wrap.appendChild(hud)

  const tooltip = document.createElement('div')
  tooltip.className = 'vibe-tip'
  wrap.appendChild(tooltip)

  // === LIGHTS ===
  scene.add(new T.AmbientLight(0x222244, 0.4))
  const ptLights = [
    new T.PointLight(0x00ffcc, 2, 60),
    new T.PointLight(0xff00ff, 1.5, 60),
    new T.PointLight(0xffff00, 1, 60),
    new T.PointLight(0x0088ff, 1.2, 60),
  ]
  ptLights[0].position.set(10, 5, 10)
  ptLights[1].position.set(-10, 3, -10)
  ptLights[2].position.set(0, -5, 5)
  ptLights[3].position.set(5, 8, -5)
  ptLights.forEach((l) => scene.add(l))

  // === NEON GRID ===
  const grid = new T.GridHelper(120, 100, 0x00ffcc, 0x001a33)
  grid.position.y = -6
  const gMats = Array.isArray(grid.material) ? grid.material : [grid.material]
  gMats.forEach((m: any) => { m.opacity = 0.3; m.transparent = true })
  scene.add(grid)

  // === STARFIELD ===
  const starGeo = new T.BufferGeometry()
  const starArr = new Float32Array(12000 * 3)
  for (let i = 0; i < starArr.length; i++) starArr[i] = (Math.random() - 0.5) * 400
  starGeo.setAttribute('position', new T.BufferAttribute(starArr, 3))
  const starPts = new T.Points(starGeo, new T.PointsMaterial({ color: 0xffffff, size: 0.12, transparent: true, opacity: 0.7 }))
  scene.add(starPts)

  // === DUST ===
  const dustN = 400
  const dustArr = new Float32Array(dustN * 3)
  const dustVel: number[] = []
  for (let i = 0; i < dustN; i++) {
    dustArr[i * 3] = (Math.random() - 0.5) * 40
    dustArr[i * 3 + 1] = (Math.random() - 0.5) * 20
    dustArr[i * 3 + 2] = (Math.random() - 0.5) * 40
    dustVel.push((Math.random() - 0.5) * 0.015, (Math.random() - 0.5) * 0.015, (Math.random() - 0.5) * 0.015)
  }
  const dustGeo = new T.BufferGeometry()
  dustGeo.setAttribute('position', new T.BufferAttribute(dustArr, 3))
  const dustPts = new T.Points(dustGeo, new T.PointsMaterial({ color: 0x00ffcc, size: 0.04, transparent: true, opacity: 0.4 }))
  scene.add(dustPts)

  // === LENS FLARE ===
  const flare = createLensFlare(T)
  scene.add(flare)

  // === WISDOM SPRITES ===
  const wisdoms: any[] = []
  for (let i = 0; i < 12; i++) {
    const c = document.createElement('canvas')
    c.width = 512; c.height = 64
    const cx = c.getContext('2d')!
    cx.fillStyle = `rgba(0,255,204,${0.06 + Math.random() * 0.1})`
    cx.font = 'bold 28px monospace'
    cx.textAlign = 'center'
    cx.fillText(WISDOM[i % WISDOM.length], 256, 42)
    const sp = new T.Sprite(new T.SpriteMaterial({ map: new T.CanvasTexture(c), transparent: true }))
    sp.scale.set(10, 1.2, 1)
    sp.position.set((Math.random() - 0.5) * 50, (Math.random() - 0.5) * 25, (Math.random() - 0.5) * 50)
    scene.add(sp)
    wisdoms.push(sp)
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
    const tex = createCardTexture(T, task, urg)

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

    // Wireframe glow
    const wColor = urg >= 0.95 ? 0xff0040 : urg >= 0.75 ? 0xff8800 : 0x00ffcc
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
        tooltip.innerHTML = `<div style="font-weight:bold;margin-bottom:6px;">${card.task.title}</div>
          <div style="font-size:11px;opacity:0.6;">${card.task.priority.toUpperCase()} \u00B7 ${card.task.status.replace('_', ' ').toUpperCase()}${card.task.domain ? ' \u00B7 #' + card.task.domain : ''}</div>
          <div style="margin-top:6px;font-size:10px;opacity:0.3;">CLICK TO YEET</div>`
      }
      tooltip.style.left = e.clientX + 16 + 'px'
      tooltip.style.top = e.clientY + 16 + 'px'
    } else {
      if (hCard) { hCard.hovered = false; hCard = null }
      renderer.domElement.style.cursor = 'default'
      tooltip.style.display = 'none'
    }
  }

  function onClickCanvas(): void {
    if (!hCard) return
    const card = hCard

    spawnExplosion(T, scene, card.mesh.position, 80)
    shakeScreen(wrap, 30, 700)

    // Fireworks: secondary bursts offset from the card
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

    // Send it to the bottom
    card.sinking = true
    card.targetY = -8
    card.targetScale = 0.3

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
      camera.position.y += (4 - camera.position.y) * dt * 1.2
      camera.position.z += (16 - camera.position.z) * dt * 1.2
      if (Math.abs(camera.position.z - 16) < 0.5) entryDone = true
    } else {
      camAngle += dt * 0.08
      camera.position.x = Math.sin(camAngle) * 16
      camera.position.z = Math.cos(camAngle) * 16
      camera.position.y = 4 + Math.sin(time * 0.2) * 1.5
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

    starPts.rotation.y += dt * 0.008

    // Wisdom float
    for (const sp of wisdoms) {
      sp.position.y += dt * 0.15
      if (sp.position.y > 18) {
        sp.position.y = -18
        sp.position.x = (Math.random() - 0.5) * 50
        sp.position.z = (Math.random() - 0.5) * 50
      }
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
