const CSS = `
:root {
  --bg: #0a0a0a;
  --surface: #141414;
  --border: #2a2a2a;
  --text: #e0e0e0;
  --dim: #666;
  --accent: #60a5fa;
  --green: #4ade80;
  --orange: #fb923c;
  --red: #ef4444;
  --cyan: #22d3ee;
  --font: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  --radius: 6px;
  --font-size: 14px;
  --spacing: 12px;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body {
  height: 100%;
  background: var(--bg);
  color: var(--text);
  font-family: var(--font);
  font-size: var(--font-size);
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
}

#app {
  width: 100%;
  padding: 0 16px;
  display: flex;
  flex-direction: column;
  height: 100vh;
}

.fmn-content {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  min-height: 0;
  max-width: 900px;
  width: 100%;
  margin: 0 auto;
  scrollbar-width: thin;
  scrollbar-color: var(--border) transparent;
}

.fmn-content::-webkit-scrollbar {
  width: 4px;
}

.fmn-content::-webkit-scrollbar-track {
  background: transparent;
}

.fmn-content::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: 2px;
}

/* Header */

.fmn-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0 12px;
  border-bottom: 1px solid var(--border);
  margin-bottom: 12px;
  position: sticky;
  top: 0;
  background: var(--bg);
  z-index: 10;
}

.fmn-header h1, .fmn-header-title {
  font-size: 18px;
  font-weight: 600;
  font-family: var(--font-header);
  color: var(--accent);
  letter-spacing: -0.5px;
  cursor: pointer;
}

.fmn-section {
  font-family: var(--font-header);
}

.fmn-detail-title, .fmn-task-title {
  font-family: var(--font-body);
}

.fmn-header-title:hover {
  opacity: 0.8;
}

.fmn-header-actions {
  display: flex;
  gap: 8px;
}

/* Buttons */

button {
  font-family: var(--font);
  font-size: 13px;
  cursor: pointer;
  border: none;
  border-radius: calc(var(--radius) - 2px);
  padding: 6px 12px;
  transition: background 0.15s, opacity 0.15s;
}

button:active { opacity: 0.8; }

.btn-accent {
  background: var(--accent);
  color: #000;
  font-weight: 600;
}

.btn-accent:hover { opacity: 0.9; }

.btn-ghost {
  background: transparent;
  color: var(--dim);
  border: 1px solid var(--border);
}

.btn-ghost:hover {
  color: var(--text);
  border-color: var(--dim);
}

.btn-icon {
  background: transparent;
  color: var(--dim);
  padding: 4px 8px;
  font-size: 16px;
  line-height: 1;
}

.btn-icon:hover { color: var(--text); }

.btn-danger {
  background: transparent;
  color: var(--red);
  border: 1px solid var(--red);
}

.btn-danger:hover { background: rgba(239, 68, 68, 0.1); }

.btn-sm {
  padding: 3px 8px;
  font-size: 12px;
}

/* Cards */

.fmn-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: var(--spacing) 16px;
  margin-bottom: 8px;
  transition: border-color 0.15s;
  position: relative;
}

.fmn-card:hover {
  border-color: var(--dim);
}

/* Task item */

.fmn-task {
  position: relative;
}

.fmn-task-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.fmn-task-title {
  flex: 1;
  font-size: 14px;
  color: var(--text);
  cursor: pointer;
  text-decoration: none;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.fmn-task-title:hover {
  color: var(--accent);
}

.fmn-task-meta {
  font-size: 9px;
  color: var(--dim);
  margin-left: auto;
  white-space: nowrap;
}

.fmn-task-category {
  color: var(--cyan);
  font-size: 11px;
}

/* Progress bar */

.fmn-progress {
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  margin-top: 8px;
  overflow: hidden;
  transition: height 0.3s ease, margin-top 0.3s ease, opacity 0.3s ease;
}

.fmn-progress-hidden {
  height: 0;
  margin-top: 0;
  opacity: 0;
}

.fmn-progress-fill {
  height: 100%;
  border-radius: 2px;
  transition: width 1s linear;
}

/* Sort icon animations */

@keyframes sortFlip {
  0% { transform: rotateX(0deg) scale(1); }
  40% { transform: rotateX(90deg) scale(0.8); }
  60% { transform: rotateX(90deg) scale(0.8); }
  100% { transform: rotateX(0deg) scale(1); }
}

@keyframes sortBounce {
  0% { transform: translateY(0) rotate(0deg); }
  25% { transform: translateY(-6px) rotate(-15deg); }
  50% { transform: translateY(0) rotate(0deg); }
  75% { transform: translateY(-3px) rotate(10deg); }
  100% { transform: translateY(0) rotate(0deg); }
}

@keyframes sortSpin {
  0% { transform: rotate(0deg) scale(1); }
  50% { transform: rotate(180deg) scale(1.3); }
  100% { transform: rotate(360deg) scale(1); }
}

@keyframes sortPop {
  0% { transform: scale(1); opacity: 1; }
  30% { transform: scale(0) rotate(90deg); opacity: 0; }
  60% { transform: scale(0) rotate(-90deg); opacity: 0; }
  100% { transform: scale(1) rotate(0deg); opacity: 1; }
}

@keyframes sortWobble {
  0% { transform: rotate(0deg); }
  20% { transform: rotate(20deg); }
  40% { transform: rotate(-15deg); }
  60% { transform: rotate(10deg); }
  80% { transform: rotate(-5deg); }
  100% { transform: rotate(0deg); }
}

.fmn-sort-icon {
  display: inline-block;
  cursor: default;
}

.fmn-sort-icon.fmn-sort-animate {
  animation: var(--sort-anim) 0.5s ease;
}

/* Overdue flash */

@keyframes overdueFlash {
  0%, 100% { background: var(--surface); }
  50% { background: rgba(239, 68, 68, 0.08); }
}

.fmn-overdue {
  animation: overdueFlash 5s ease-in-out infinite;
}

/* Badges */

.fmn-badge {
  display: inline-block;
  font-size: 10px;
  font-weight: 600;
  padding: 1px 6px;
  border-radius: 3px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.fmn-badge-low { background: var(--border); color: var(--dim); }
.fmn-badge-normal { background: rgba(96, 165, 250, 0.15); color: var(--accent); }
.fmn-badge-high { background: rgba(251, 146, 60, 0.15); color: var(--orange); }
.fmn-badge-critical { background: rgba(239, 68, 68, 0.15); color: var(--red); }
.fmn-badge-recurring { background: rgba(34, 211, 238, 0.15); color: var(--cyan); }

/* Prompt display */

.fmn-prompt {
  font-size: 12px;
  color: var(--orange);
  font-style: italic;
  flex: 1;
  text-align: right;
  margin-right: 12px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Quick capture input */

@keyframes captureOpen {
  from { max-height: 0; opacity: 0; margin-top: 0; padding: 0 10px; }
  to { max-height: 40px; opacity: 1; margin-top: 8px; padding: 6px 10px; }
}

.fmn-capture {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  padding: 0 16px;
  background: var(--bg);
  border: 2px solid var(--orange);
  border-radius: var(--radius);
  color: var(--text);
  font-family: var(--font);
  font-size: 13px;
  outline: none;
  box-sizing: border-box;
  z-index: 1;
}

.fmn-capture::placeholder { color: var(--dim); }

/* Section header */

.fmn-section {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--dim);
  margin: 20px 0 8px;
}

/* Detail view */

.fmn-detail-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
}

.fmn-detail-title {
  font-size: 20px;
  font-weight: 600;
  flex: 1;
}

.fmn-detail-section {
  margin-bottom: 16px;
}

.fmn-detail-section h3 {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--dim);
  margin-bottom: 8px;
}

.fmn-detail-columns {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  align-items: start;
}

@media (max-width: 500px) {
  .fmn-detail-columns {
    grid-template-columns: 1fr;
  }
}

.fmn-detail-grid {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 4px 16px;
  font-size: 13px;
}

.fmn-detail-label {
  color: var(--dim);
}

/* Follow-up chain */

.fmn-chain {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  align-items: center;
  font-size: 13px;
}

.fmn-chain-item {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--border);
  padding: 2px 8px;
  border-radius: 3px;
}

.fmn-chain-arrow {
  color: var(--dim);
}

/* Action log */

.fmn-log-entry {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-size: 12px;
  padding: 4px 0;
  border-bottom: 1px solid var(--border);
}

.fmn-log-entry:last-child { border-bottom: none; }

.fmn-log-badge {
  font-size: 10px;
  font-weight: 600;
  padding: 1px 5px;
  border-radius: 2px;
}

.fmn-log-badge-reset { background: rgba(34, 211, 238, 0.15); color: var(--cyan); }
.fmn-log-badge-complete { background: rgba(74, 222, 128, 0.15); color: var(--green); }
.fmn-log-badge-note { background: rgba(96, 165, 250, 0.15); color: var(--accent); }

.fmn-log-note { color: var(--text); flex: 1; }
.fmn-log-time { color: var(--dim); font-size: 11px; white-space: nowrap; }

/* Inputs */

input, select, textarea {
  font-family: var(--font);
  font-size: 13px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: calc(var(--radius) - 2px);
  color: var(--text);
  padding: 6px 10px;
  outline: none;
  width: 100%;
}

input:focus, select:focus, textarea:focus {
  border-color: var(--accent);
}

textarea {
  resize: vertical;
  min-height: 60px;
}

select {
  cursor: pointer;
}

/* Settings */

.fmn-settings-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid var(--border);
}

.fmn-settings-row:last-child { border-bottom: none; }

.fmn-settings-label {
  font-size: 13px;
  color: var(--text);
}

.fmn-settings-control {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* Toggle switch */

.fmn-toggle {
  position: relative;
  width: 40px;
  height: 22px;
  cursor: pointer;
}

.fmn-toggle input {
  opacity: 0;
  width: 0;
  height: 0;
  position: absolute;
}

.fmn-toggle-track {
  position: absolute;
  inset: 0;
  background: var(--border);
  border-radius: 11px;
  transition: background 0.2s;
}

.fmn-toggle input:checked + .fmn-toggle-track {
  background: var(--accent);
}

.fmn-toggle-thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 18px;
  height: 18px;
  background: var(--text);
  border-radius: 50%;
  transition: transform 0.2s;
}

.fmn-toggle input:checked ~ .fmn-toggle-thumb {
  transform: translateX(18px);
}

/* Slider */

input[type="range"] {
  -webkit-appearance: none;
  height: 4px;
  background: var(--border);
  border-radius: 2px;
  border: none;
  padding: 0;
  width: 120px;
}

input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 16px;
  height: 16px;
  background: var(--accent);
  border-radius: 50%;
  cursor: pointer;
}

/* Domain tags */

.fmn-domain-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 4px;
}

.fmn-domain-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: var(--border);
  padding: 2px 8px;
  border-radius: 3px;
  font-size: 12px;
}

.fmn-domain-remove {
  cursor: pointer;
  color: var(--dim);
  font-size: 14px;
  line-height: 1;
}

.fmn-domain-remove:hover { color: var(--red); }

/* Create form */

.fmn-form-group {
  margin-bottom: 12px;
}

.fmn-form-group label {
  display: block;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--dim);
  margin-bottom: 4px;
}

.fmn-form-row {
  display: flex;
  gap: 8px;
}

.fmn-form-row > * { flex: 1; }

/* Empty state */

.fmn-empty {
  text-align: center;
  padding: 40px 16px;
  color: var(--dim);
  font-size: 13px;
}

/* Inline add */

.fmn-inline-add {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}

.fmn-inline-add input { flex: 1; min-width: 0; }
.fmn-inline-add select { width: auto; flex: 0 0 auto; }

/* Back link */

.fmn-back {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--dim);
  font-size: 13px;
  cursor: pointer;
  margin-bottom: 12px;
  background: none;
  border: none;
  padding: 0;
  font-family: var(--font);
}

.fmn-back:hover { color: var(--text); }

/* Status select */

.fmn-status-select {
  width: auto;
  padding: 2px 6px;
  font-size: 12px;
}

/* Footer */

.fmn-footer {
  flex-shrink: 0;
  padding: 12px 0;
  border-top: 1px solid var(--border);
  text-align: center;
  font-size: 12px;
  color: var(--dim);
}

.fmn-footer a {
  color: var(--accent);
  text-decoration: none;
}

.fmn-footer a:hover {
  text-decoration: underline;
}

/* === Task animations === */

/* Midnight: clean fade */
@keyframes animFade {
  0% { opacity: 1; transform: scale(1); }
  100% { opacity: 0; transform: scale(0.95); }
}
.fmn-anim-fade { animation: animFade 0.4s ease-out forwards; }

/* Sunrise: float up gently */
@keyframes animFloat {
  0% { opacity: 1; transform: translateY(0); }
  100% { opacity: 0; transform: translateY(-40px); }
}
.fmn-anim-float { animation: animFloat 0.5s ease-in-out forwards; }

/* Selva: grow and dissolve */
@keyframes animGrow {
  0% { opacity: 1; transform: scale(1); filter: blur(0); }
  50% { opacity: 0.7; transform: scale(1.05); }
  100% { opacity: 0; transform: scale(1.1); filter: blur(4px); }
}
.fmn-anim-grow { animation: animGrow 0.5s ease-out forwards; }

/* Kente: sharp geometric slide */
@keyframes animSlide {
  0% { opacity: 1; transform: translateX(0) scaleX(1); }
  40% { transform: translateX(10px) scaleX(0.98); }
  100% { opacity: 0; transform: translateX(-100%) scaleX(0.8); }
}
.fmn-anim-slide { animation: animSlide 0.4s cubic-bezier(0.7, 0, 0.3, 1) forwards; }

/* Neon: glitch and matrix dissolve */
@keyframes animGlitch {
  0% { opacity: 1; transform: translate(0, 0); filter: hue-rotate(0deg); }
  15% { transform: translate(-3px, 2px); filter: hue-rotate(90deg); }
  30% { transform: translate(3px, -1px); filter: hue-rotate(180deg); }
  45% { transform: translate(-2px, 3px) skewX(2deg); filter: hue-rotate(270deg); opacity: 0.7; }
  60% { transform: translate(4px, -2px) skewX(-3deg); filter: hue-rotate(360deg); opacity: 0.5; }
  75% { transform: translate(-1px, 1px) scaleY(0.95); opacity: 0.3; clip-path: inset(20% 0 30% 0); }
  100% { opacity: 0; transform: translate(0, -10px) scaleY(0); filter: hue-rotate(720deg) brightness(3); }
}
.fmn-anim-glitch { animation: animGlitch 0.6s steps(1, end) forwards; }

/* Cloud: soft drift */
@keyframes animDrift {
  0% { opacity: 1; transform: translateY(0) translateX(0); }
  100% { opacity: 0; transform: translateY(-20px) translateX(30px); filter: blur(2px); }
}
.fmn-anim-drift { animation: animDrift 0.6s ease-in-out forwards; }

/* Terracotta: crumble down */
@keyframes animCrumble {
  0% { opacity: 1; transform: translateY(0) rotate(0deg); }
  40% { transform: translateY(4px) rotate(0.5deg); }
  100% { opacity: 0; transform: translateY(30px) rotate(2deg) scaleY(0.8); }
}
.fmn-anim-crumble { animation: animCrumble 0.5s ease-in forwards; }

/* Matcha: zen dissolve */
@keyframes animZen {
  0% { opacity: 1; transform: scale(1); filter: blur(0); }
  100% { opacity: 0; transform: scale(1.02); filter: blur(8px) brightness(1.3); }
}
.fmn-anim-zen { animation: animZen 0.7s ease-out forwards; }

/* Vinyl: spin and shrink */
@keyframes animSpin {
  0% { opacity: 1; transform: rotate(0deg) scale(1); }
  100% { opacity: 0; transform: rotate(180deg) scale(0.3); }
}
.fmn-anim-spin { animation: animSpin 0.5s cubic-bezier(0.4, 0, 0.2, 1) forwards; }

/* Océano: wave ripple */
@keyframes animWave {
  0% { opacity: 1; transform: translateY(0) scaleX(1); }
  30% { transform: translateY(-5px) scaleX(1.02); }
  60% { transform: translateY(3px) scaleX(0.98); opacity: 0.5; }
  100% { opacity: 0; transform: translateY(-20px) scaleX(0.9); }
}
.fmn-anim-wave { animation: animWave 0.6s ease-in-out forwards; }

/* Sakura: petals float away */
@keyframes animPetals {
  0% { opacity: 1; transform: translateY(0) translateX(0) rotate(0deg); }
  25% { transform: translateY(-10px) translateX(8px) rotate(3deg); }
  50% { transform: translateY(-25px) translateX(-5px) rotate(-2deg); opacity: 0.6; }
  75% { transform: translateY(-40px) translateX(12px) rotate(5deg); opacity: 0.3; }
  100% { opacity: 0; transform: translateY(-60px) translateX(20px) rotate(8deg); }
}
.fmn-anim-petals { animation: animPetals 0.7s ease-out forwards; }

/* Enter animations (reverse feel) */
.fmn-anim-enter-fade { animation: animFade 0.3s ease-out reverse; }
.fmn-anim-enter-float { animation: animFloat 0.3s ease-out reverse; }
.fmn-anim-enter-grow { animation: animGrow 0.3s ease-out reverse; }
.fmn-anim-enter-slide { animation: animSlide 0.3s ease-out reverse; }
.fmn-anim-enter-glitch { animation: animGlitch 0.3s steps(1, end) reverse; }
.fmn-anim-enter-drift { animation: animDrift 0.3s ease-out reverse; }
.fmn-anim-enter-crumble { animation: animCrumble 0.3s ease-out reverse; }
.fmn-anim-enter-zen { animation: animZen 0.3s ease-out reverse; }
.fmn-anim-enter-spin { animation: animSpin 0.3s ease-out reverse; }
.fmn-anim-enter-wave { animation: animWave 0.3s ease-out reverse; }
.fmn-anim-enter-petals { animation: animPetals 0.4s ease-out reverse; }

/* Prevent pointer events during animation */
[class*="fmn-anim-"] { pointer-events: none; }

/* Smooth gap collapse when a card leaves */
.fmn-task {
  overflow: hidden;
}
.fmn-task.fmn-collapsing {
  margin-top: 0 !important;
  margin-bottom: 0 !important;
  padding-top: 0 !important;
  padding-bottom: 0 !important;
  border-width: 0 !important;
  max-height: 0 !important;
  opacity: 0 !important;
  transition: all 0.5s ease-in-out;
}
`

export function injectStyles(): void {
  const style = document.createElement('style')
  style.textContent = CSS
  document.head.appendChild(style)
}
