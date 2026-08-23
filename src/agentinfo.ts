// The "get your ai to talk to me" affordance. Most people have no idea an app
// can be driven by their assistant, so this says it in plain language and hands
// them something to paste — rather than documenting an API at them.
//
// Two doors out of that modal: the technical details (llms.txt) for someone who
// wants the API, and the "why" for someone who wants the argument.

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

/**
 * `?model=ai` — a hotlink target for blog posts and docs: someone lands on the
 * app with the agent explainer already open, instead of having to find the small
 * link under the header. Also accepts agent/llm/agentic, since whoever writes the
 * link won't remember the exact word.
 */
export function checkAgentModalParam(params: URLSearchParams): boolean {
  const v = (params.get('model') || '').trim().toLowerCase()
  if (!['ai', 'agent', 'agents', 'agentic', 'llm'].includes(v)) return false
  showAgentModal()
  // Tidy the URL once the link has done its job (same as ?seeded).
  history.replaceState(null, '', location.pathname)
  return true
}

/** Backdrop + panel, dismissed by Escape or a click outside. Returns the box to fill. */
function modalShell(): { overlay: HTMLElement; box: HTMLElement; close: () => void } {
  const overlay = el('div', { className: 'fmn-modal-backdrop' })
  const box = el('div', { className: 'fmn-modal' })
  const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') close() }
  function close(): void {
    overlay.remove()
    document.removeEventListener('keydown', onKey)
  }
  overlay.onclick = (e) => { if (e.target === overlay) close() }
  document.addEventListener('keydown', onKey)
  overlay.appendChild(box)
  return { overlay, box, close }
}

function closeButton(label: string, onClick: () => void): HTMLElement {
  const b = el('button', { className: 'btn-ghost', style: 'width:100%;padding:10px;margin-top:12px;' }, label) as HTMLButtonElement
  b.onclick = onClick
  return b
}

export function showAgentModal(): void {
  const { overlay, box, close } = modalShell()

  box.appendChild(el('div', { className: 'fmn-modal-title' }, 'Get your AI to talk to me'))

  box.appendChild(el('p', { className: 'fmn-modal-text' },
    'This app is built to be driven by an AI assistant. If yours can open a web page ' +
    'and run a little code, it can add your reminders, change how often they repeat, ' +
    'and set the whole list up for you — no clicking required.'))

  box.appendChild(el('div', { className: 'fmn-modal-label' }, 'Paste this to your AI'))
  box.appendChild(el('div', { className: 'fmn-modal-code' }, PASTE_PROMPT))

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

  const links = el('div', { className: 'fmn-modal-links' })
  const why = el('button', { className: 'fmn-modal-more' }, 'why this exists →') as HTMLButtonElement
  why.onclick = () => { close(); showWhyModal() }
  links.appendChild(why)
  links.appendChild(el('a', {
    href: '/llms.txt', target: '_blank', rel: 'noopener', className: 'fmn-modal-more',
  }, 'the technical details →'))
  box.appendChild(links)

  box.appendChild(closeButton('Close', close))
  document.body.appendChild(overlay)
}

export function showWhyModal(): void {
  const { overlay, box, close } = modalShell()

  box.appendChild(el('div', { className: 'fmn-modal-title' }, 'Why this exists'))

  const paragraphs = [
    'Putting AI inside a product is the easy half. The harder half — the one that ' +
    'actually matters — is making the product something a user’s own AI can connect to.',

    'The miss I keep seeing: builders assume they understand the user’s mind better ' +
    'than the user does. So they encode one workflow, their own, and everything ' +
    'outside it turns into friction.',

    'If an agent can drive your product, the user no longer has to adopt your workflow. ' +
    'They can meet it halfway and shape it around how they actually think.',

    'The counterintuitive part: being less prescriptive makes a product more useful, ' +
    'not less. A tool that assumes less about any one person is easier for an ' +
    'AI-enabled user to bend into exactly what they need — which makes it stickier, ' +
    'and much harder to replace with the custom workflow they’d otherwise just build ' +
    'themselves.',

    'So this app doesn’t try to know how you work. It exposes everything it can do, ' +
    'and lets your agent handle the rest.',
  ]
  for (const text of paragraphs) {
    box.appendChild(el('p', { className: 'fmn-modal-text' }, text))
  }

  const links = el('div', { className: 'fmn-modal-links' })
  const back = el('button', { className: 'fmn-modal-more' }, '← how to do it') as HTMLButtonElement
  back.onclick = () => { close(); showAgentModal() }
  links.appendChild(back)
  links.appendChild(el('a', {
    href: '/llms.txt', target: '_blank', rel: 'noopener', className: 'fmn-modal-more',
  }, 'the technical details →'))
  box.appendChild(links)

  box.appendChild(closeButton('Close', close))
  document.body.appendChild(overlay)
}
