import { exportAll, importAll } from './store'
import { el } from './utils'
import { navigate } from './app'

let qrLibLoaded = false

function loadQRLib(): Promise<void> {
  if (qrLibLoaded) return Promise.resolve()
  return new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = 'https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js'
    s.onload = () => { qrLibLoaded = true; resolve() }
    s.onerror = () => reject(new Error('Failed to load QR library'))
    document.head.appendChild(s)
  })
}

async function compress(data: string): Promise<string> {
  if ('CompressionStream' in window) {
    const stream = new Blob([data]).stream().pipeThrough(new CompressionStream('deflate'))
    const blob = await new Response(stream).blob()
    const buffer = await blob.arrayBuffer()
    const bytes = new Uint8Array(buffer)
    let binary = ''
    for (const byte of bytes) binary += String.fromCharCode(byte)
    return btoa(binary)
  }
  // Fallback: raw base64
  return btoa(unescape(encodeURIComponent(data)))
}

async function decompress(b64: string): Promise<string> {
  try {
    if ('DecompressionStream' in window) {
      const binary = atob(b64)
      const bytes = new Uint8Array(binary.length)
      for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
      const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'))
      return await new Response(stream).text()
    }
  } catch {
    // Fall through to raw decode
  }
  return decodeURIComponent(escape(atob(b64)))
}

export async function showTransferQR(container: HTMLElement): Promise<void> {
  const json = exportAll()
  const encoded = await compress(json)
  const url = `${location.origin}${location.pathname}#import=${encoded}`

  // Check if URL is too long for a QR code (~4KB practical limit)
  if (url.length > 4000) {
    const overlay = createOverlay()
    overlay.appendChild(el('div', { style: 'font-size:16px;font-weight:600;color:var(--accent);margin-bottom:12px;' }, 'Too much data for QR'))
    overlay.appendChild(el('div', { style: 'font-size:13px;color:var(--dim);margin-bottom:16px;' },
      `Your data is ${Math.round(url.length / 1024)}KB — QR codes max out around 4KB. Use Export JSON instead, or transfer fewer tasks.`))
    overlay.appendChild(createCloseBtn(overlay))
    container.appendChild(overlay)
    return
  }

  try {
    await loadQRLib()
  } catch {
    alert('Could not load QR code library.')
    return
  }

  const qr = (window as any).qrcode(0, 'L')
  qr.addData(url)
  qr.make()

  const overlay = createOverlay()
  overlay.appendChild(el('div', { style: 'font-size:16px;font-weight:600;color:var(--accent);margin-bottom:12px;' }, 'Scan to transfer'))
  overlay.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);margin-bottom:12px;' },
    'Scan this QR code on your other device to import all tasks and settings.'))

  const qrContainer = el('div', { style: 'display:flex;justify-content:center;margin-bottom:16px;' })
  const qrImg = document.createElement('div')
  qrImg.innerHTML = qr.createSvgTag({ cellSize: 4, margin: 4, scalable: true })
  const svg = qrImg.querySelector('svg')
  if (svg) {
    svg.style.width = '240px'
    svg.style.height = '240px'
    svg.style.borderRadius = '8px'
  }
  qrContainer.appendChild(qrImg)
  overlay.appendChild(qrContainer)

  // Also offer copy link
  const copyBtn = el('button', { className: 'btn-ghost btn-sm' }, 'Copy link instead') as HTMLButtonElement
  copyBtn.onclick = () => {
    navigator.clipboard.writeText(url).then(() => {
      copyBtn.textContent = 'Copied!'
      setTimeout(() => { copyBtn.textContent = 'Copy link instead' }, 1500)
    })
  }
  overlay.appendChild(el('div', { style: 'text-align:center;margin-bottom:12px;' }, copyBtn))

  overlay.appendChild(createCloseBtn(overlay))
  container.appendChild(overlay)
}

export async function checkImportFromUrl(): Promise<boolean> {
  const hash = location.hash
  if (!hash.startsWith('#import=')) return false

  const encoded = hash.slice(8)
  try {
    const json = await decompress(encoded)
    const result = importAll(json)
    // Clean the URL
    history.replaceState(null, '', location.pathname)
    alert(`Imported ${result.tasks} tasks from another device.`)
    navigate('panel')
    return true
  } catch {
    alert('Could not import data — the link may be corrupted.')
    return false
  }
}

function createOverlay(): HTMLElement {
  const overlay = el('div', {
    style: 'position:fixed;inset:0;background:var(--bg);z-index:100;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;',
  })
  return overlay
}

function createCloseBtn(overlay: HTMLElement): HTMLElement {
  const btn = el('button', { className: 'btn-ghost' }, 'Close') as HTMLButtonElement
  btn.onclick = () => overlay.remove()
  return btn
}
