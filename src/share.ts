import { el } from './utils'
import { navigate } from './app'
import { appName } from './brand'
import { showSend, showReceive } from './transfer'

export function renderShare(container: HTMLElement): void {
  container.innerHTML = ''

  const headerTitle = el('h1', { className: 'fmn-header-title' }, appName())
  headerTitle.onclick = () => navigate('panel')
  container.appendChild(el('div', { className: 'fmn-header' }, headerTitle, el('div', { className: 'fmn-section', style: 'margin:0;' }, 'Share')))

  const card = el('div', { className: 'fmn-card' })

  card.appendChild(el('div', { style: 'font-size:14px;color:var(--text);margin-bottom:16px;' }, 'Transfer your tasks and settings between devices.'))

  // Send
  const sendBtn = el('button', { className: 'btn-accent', style: 'width:100%;margin-bottom:8px;padding:12px;font-size:14px;' }, 'Send to device') as HTMLButtonElement
  sendBtn.onclick = () => showSend(document.body)
  card.appendChild(sendBtn)
  card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);margin-bottom:16px;' }, 'AirDrop, QR code, or copy a transfer link.'))

  // Receive
  const recvBtn = el('button', { className: 'btn-ghost', style: 'width:100%;margin-bottom:8px;padding:12px;font-size:14px;' }, 'Receive from device') as HTMLButtonElement
  recvBtn.onclick = () => showReceive(document.body)
  card.appendChild(recvBtn)
  card.appendChild(el('div', { style: 'font-size:11px;color:var(--dim);' }, 'Scan a QR code or paste a transfer link.'))

  container.appendChild(card)
}
