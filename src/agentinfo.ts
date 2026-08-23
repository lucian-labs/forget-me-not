// The "get your ai to talk to me" affordance. Most people have no idea an app
// can be driven by their assistant, so this says it in plain language and hands
// them something to paste — rather than documenting an API at them.

import { el } from './utils'

const PASTE_PROMPT =
  'Open https://tasks.lucianlabs.ca, run fmn.help() on the page to see what it can do, ' +
  'then help me set up my reminders.'

/** Small, dim, clickable line — sits under the header without competing with it. */
export function renderAgentLink(): HTMLElement {
  const link = el('button', {
    className: 'fmn-agent-link',
    'data-tip': 'this app can be driven by your AI',
  }, 'get your ai to talk to me') as HTMLButtonElement
  link.onclick = () => showAgentModal()
  return el('div', { style: 'display:flex;justify-content:flex-end;margin:-6px 0 10px;' }, link)
}

export function showAgentModal(): void {
  const overlay = el('div', { className: 'fmn-modal-backdrop' })
  const box = el('div', { className: 'fmn-modal' })

  box.appendChild(el('div', { className: 'fmn-modal-title' }, 'Get your AI to talk to me'))

  box.appendChild(el('p', { className: 'fmn-modal-text' },
    'This app is built to be driven by an AI assistant. If yours can open a web page ' +
    'and run a little code, it can add your reminders, change how often they repeat, ' +
    'and set the whole list up for you — no clicking required.'))

  box.appendChild(el('div', { className: 'fmn-modal-label' }, 'Paste this to your AI'))

  const snippet = el('div', { className: 'fmn-modal-code' }, PASTE_PROMPT)
  box.appendChild(snippet)

  const copyBtn = el('button', { className: 'btn-accent', style: 'width:100%;padding:10px;margin-top:8px;' }, 'Copy that') as HTMLButtonElement
  copyBtn.onclick = () => {
    navigator.clipboard.writeText(PASTE_PROMPT).then(() => {
      copyBtn.textContent = 'Copied!'
      setTimeout(() => { copyBtn.textContent = 'Copy that' }, 2000)
    })
  }
  box.appendChild(copyBtn)

  box.appendChild(el('p', { className: 'fmn-modal-note' },
    'Your assistant works with the tasks kept in this browser — it calls the app directly ' +
    'instead of clicking around. It can read your list, add to it, and change your setup.'))

  const more = el('a', {
    href: '/llms.txt', target: '_blank', rel: 'noopener', className: 'fmn-modal-more',
  }, 'the technical details →')
  box.appendChild(more)

  const close = el('button', { className: 'btn-ghost', style: 'width:100%;padding:10px;margin-top:12px;' }, 'Close') as HTMLButtonElement
  close.onclick = () => overlay.remove()
  box.appendChild(close)

  // Click-outside and Escape both dismiss — expected of anything modal.
  overlay.onclick = (e) => { if (e.target === overlay) overlay.remove() }
  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape') { overlay.remove(); document.removeEventListener('keydown', onKey) }
  }
  document.addEventListener('keydown', onKey)

  overlay.appendChild(box)
  document.body.appendChild(overlay)
}
