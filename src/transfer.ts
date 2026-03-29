import { exportAll, importAll } from './store'
import { el } from './utils'
import { navigate } from './app'

let qrLib: any = null

async function loadQRLib(): Promise<any> {
  if (qrLib) return qrLib
  return new Promise((resolve, reject) => {
    const s = document.createElement('script')
    s.src = 'https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js'
    s.onload = () => { qrLib = (window as any).qrcode; resolve(qrLib) }
    s.onerror = () => reject(new Error('QR library failed'))
    document.head.appendChild(s)
  })
}

async function compress(data: string): Promise<string> {
  try {
    if ('CompressionStream' in window) {
      const stream = new Blob([data]).stream().pipeThrough(new CompressionStream('deflate'))
      const blob = await new Response(stream).blob()
      const buffer = await blob.arrayBuffer()
      const bytes = new Uint8Array(buffer)
      let binary = ''
      for (const byte of bytes) binary += String.fromCharCode(byte)
      return 'z:' + btoa(binary) // z: prefix indicates compressed
    }
  } catch { /* fall through */ }
  return 'r:' + btoa(unescape(encodeURIComponent(data))) // r: prefix = raw
}

async function decompress(encoded: string): Promise<string> {
  if (encoded.startsWith('z:')) {
    const b64 = encoded.slice(2)
    const binary = atob(b64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate'))
    return await new Response(stream).text()
  }
  if (encoded.startsWith('r:')) {
    return decodeURIComponent(escape(atob(encoded.slice(2))))
  }
  // Legacy: try raw base64
  return decodeURIComponent(escape(atob(encoded)))
}

// --- SEND ---

export async function showSend(container: HTMLElement): Promise<void> {
  const overlay = createOverlay()
  overlay.appendChild(el('div', { style: 'font-size:18px;font-weight:600;color:var(--accent);margin-bottom:16px;' }, 'Send to device'))

  const json = exportAll()
  const encoded = await compress(json)
  const url = `${location.origin}${location.pathname}#import=${encoded}`

  if (url.length > 4000) {
    // Too big for QR — offer copy only
    overlay.appendChild(el('div', { style: 'font-size:13px;color:var(--dim);margin-bottom:12px;' },
      `Data is ${Math.round(encoded.length / 1024)}KB — too large for QR. Use the link below.`))
  } else {
    // Generate QR
    try {
      const qrcode = await loadQRLib()
      const qr = qrcode(0, 'L')
      qr.addData(url)
      qr.make()

      const qrWrap = el('div', { style: 'display:flex;justify-content:center;margin-bottom:16px;background:#fff;padding:12px;border-radius:8px;' })
      const qrDiv = document.createElement('div')
      qrDiv.innerHTML = qr.createSvgTag({ cellSize: 5, margin: 2, scalable: true })
      const svg = qrDiv.querySelector('svg')
      if (svg) { svg.style.width = '220px'; svg.style.height = '220px' }
      qrWrap.appendChild(qrDiv)
      overlay.appendChild(qrWrap)

      overlay.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);text-align:center;margin-bottom:12px;' },
        'Open camera on your other device and scan this code.'))
    } catch {
      overlay.appendChild(el('div', { style: 'font-size:13px;color:var(--red);margin-bottom:12px;' }, 'Could not generate QR code.'))
    }
  }

  // Copy link button
  const copyBtn = el('button', { className: 'btn-ghost' }, 'Copy transfer link') as HTMLButtonElement
  copyBtn.onclick = () => {
    navigator.clipboard.writeText(url).then(() => {
      copyBtn.textContent = 'Copied!'
      setTimeout(() => { copyBtn.textContent = 'Copy transfer link' }, 2000)
    })
  }
  overlay.appendChild(el('div', { style: 'text-align:center;margin-bottom:16px;' }, copyBtn))

  overlay.appendChild(createCloseBtn(overlay))
  container.appendChild(overlay)
}

// --- RECEIVE ---

export async function showReceive(container: HTMLElement): Promise<void> {
  const overlay = createOverlay()
  overlay.appendChild(el('div', { style: 'font-size:18px;font-weight:600;color:var(--accent);margin-bottom:16px;' }, 'Receive from device'))

  // Camera scanner (if BarcodeDetector available)
  if ('BarcodeDetector' in window) {
    const scanBtn = el('button', { className: 'btn-accent', style: 'margin-bottom:16px;' }, 'Scan QR with camera') as HTMLButtonElement
    scanBtn.onclick = () => startCameraScanner(overlay)
    overlay.appendChild(scanBtn)
  }

  // Paste link/JSON
  overlay.appendChild(el('div', { style: 'font-size:12px;color:var(--dim);margin-bottom:6px;' }, 'Or paste a transfer link or JSON export:'))
  const textarea = el('textarea', { placeholder: 'Paste link or JSON here...', style: 'width:100%;max-width:400px;min-height:80px;margin-bottom:12px;' }) as HTMLTextAreaElement

  const importBtn = el('button', { className: 'btn-accent' }, 'Import') as HTMLButtonElement
  importBtn.onclick = async () => {
    const val = textarea.value.trim()
    if (!val) return

    try {
      // Try as transfer link
      if (val.includes('#import=')) {
        const encoded = val.split('#import=')[1]
        const json = await decompress(encoded)
        const result = importAll(json)
        overlay.remove()
        alert(`Imported ${result.tasks} tasks.`)
        navigate('panel')
        return
      }

      // Try as raw JSON
      const result = importAll(val)
      overlay.remove()
      alert(`Imported ${result.tasks} tasks.`)
      navigate('panel')
    } catch {
      textarea.style.borderColor = 'var(--red)'
      importBtn.textContent = 'Invalid data'
      setTimeout(() => { importBtn.textContent = 'Import'; textarea.style.borderColor = '' }, 2000)
    }
  }

  overlay.appendChild(textarea)
  overlay.appendChild(el('div', { style: 'text-align:center;margin-bottom:16px;' }, importBtn))
  overlay.appendChild(createCloseBtn(overlay))
  container.appendChild(overlay)
}

async function startCameraScanner(overlay: HTMLElement): Promise<void> {
  const video = el('video', { style: 'width:100%;max-width:400px;border-radius:8px;margin-bottom:12px;' }) as HTMLVideoElement
  video.setAttribute('playsinline', '')
  video.setAttribute('autoplay', '')

  // Insert before close button
  const closeBtn = overlay.querySelector('.btn-ghost')
  if (closeBtn) overlay.insertBefore(video, closeBtn)
  else overlay.appendChild(video)

  let stream: MediaStream | null = null
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
    video.srcObject = stream

    const detector = new (window as any).BarcodeDetector({ formats: ['qr_code'] })

    const scan = async () => {
      if (!video.srcObject) return
      try {
        const barcodes = await detector.detect(video)
        if (barcodes.length > 0) {
          const url = barcodes[0].rawValue as string
          if (url.includes('#import=')) {
            stream?.getTracks().forEach((t: MediaStreamTrack) => t.stop())
            video.remove()
            const encoded = url.split('#import=')[1]
            const json = await decompress(encoded)
            const result = importAll(json)
            overlay.remove()
            alert(`Imported ${result.tasks} tasks.`)
            navigate('panel')
            return
          }
        }
      } catch { /* keep scanning */ }
      requestAnimationFrame(scan)
    }
    requestAnimationFrame(scan)
  } catch {
    video.remove()
    alert('Could not access camera.')
  }

  // Cleanup on close
  const origClose = overlay.querySelector('.btn-ghost') as HTMLElement
  if (origClose) {
    const origHandler = origClose.onclick
    origClose.onclick = () => {
      stream?.getTracks().forEach((t: MediaStreamTrack) => t.stop())
      if (origHandler) (origHandler as () => void)()
    }
  }
}

// --- URL IMPORT CHECK ---

export async function checkImportFromUrl(): Promise<boolean> {
  const hash = location.hash
  if (!hash.startsWith('#import=')) return false

  const encoded = hash.slice(8)
  try {
    const json = await decompress(encoded)
    const result = importAll(json)
    history.replaceState(null, '', location.pathname)
    alert(`Imported ${result.tasks} tasks from another device.`)
    navigate('panel')
    return true
  } catch {
    alert('Could not import data — the link may be corrupted.')
    return false
  }
}

// --- UI helpers ---

function createOverlay(): HTMLElement {
  return el('div', {
    style: 'position:fixed;inset:0;background:var(--bg);z-index:100;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px;overflow-y:auto;',
  })
}

function createCloseBtn(overlay: HTMLElement): HTMLElement {
  const btn = el('button', { className: 'btn-ghost' }, 'Close') as HTMLButtonElement
  btn.onclick = () => {
    overlay.remove()
  }
  return btn
}
