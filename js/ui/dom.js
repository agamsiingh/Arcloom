// Tiny DOM helpers: icons, screens/router, modals, toasts.
import { sfx } from '../services/audio.js';

const P = {
  back: '<path d="M15 5l-7 7 7 7"/>',
  gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.8v2.4M12 18.8v2.4M4.2 7.5l2.1 1.2M17.7 15.3l2.1 1.2M4.2 16.5l2.1-1.2M17.7 8.7l2.1-1.2"/><circle cx="12" cy="12" r="7"/>',
  undo: '<path d="M9 7L4.5 11.5 9 16"/><path d="M5 11.5h9a5 5 0 010 10h-3"/>',
  restart: '<path d="M4.5 12a7.5 7.5 0 102.2-5.3"/><path d="M4.5 4.5v4h4"/>',
  bulb: '<path d="M9 17.5h6M10 21h4"/><path d="M12 3a6 6 0 00-3.6 10.8c.6.5 1 1.2 1 2V16h5.2v-.2c0-.8.4-1.5 1-2A6 6 0 0012 3z"/>',
  heart: '<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0112 7.3 4.3 4.3 0 0119.5 10c0 5.4-7.5 10-7.5 10z"/>',
  star: '<path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.8z"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  trophy: '<path d="M7 4h10v5a5 5 0 01-10 0z"/><path d="M7 6H4v1.5A3.5 3.5 0 007.5 11M17 6h3v1.5a3.5 3.5 0 01-3.5 3.5M12 14v4M8 21h8M9.5 18h5"/>',
  grid: '<rect x="4" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="4" width="6.5" height="6.5" rx="1.6"/><rect x="4" y="13.5" width="6.5" height="6.5" rx="1.6"/><rect x="13.5" y="13.5" width="6.5" height="6.5" rx="1.6"/>',
  play: '<path d="M8 5.5v13l10-6.5z"/>',
  zoom: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.3-4.3M8.5 11h5"/>',
  gem: '<path d="M6 4h12l3 5-9 11L3 9z"/><path d="M3 9h18M9 4l3 16M15 4l-3 16"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  lock: '<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V8a3.5 3.5 0 017 0v2.5"/>',
  flame: '<path d="M12 21c-3.9 0-6.5-2.6-6.5-6.2 0-3.9 3.3-5.8 4-9.8 2.8 1.6 4.3 4 4.4 6.6.9-.6 1.5-1.6 1.7-2.8 1.9 1.6 2.9 3.8 2.9 6 0 3.6-2.6 6.2-6.5 6.2z"/>',
  infinity: '<path d="M7.5 15.5a3.5 3.5 0 110-7c3 0 6 7 9 7a3.5 3.5 0 100-7c-3 0-6 7-9 7z"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  leaf: '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z"/><path d="M5 19l7-7"/>',
  bolt: '<path d="M13 3L5 13.5h6L10 21l8-10.5h-6z"/>',
  film: '<rect x="3.5" y="5" width="17" height="14" rx="3"/><path d="M10 9.5v5l4.5-2.5z"/>',
};

export function icon(name, cls = '') {
  return `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${P[name] || ''}</svg>`;
}

export function $(sel, root = document) {
  return root.querySelector(sel);
}

export function $$(sel, root = document) {
  return [...root.querySelectorAll(sel)];
}

export function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// ---- router -------------------------------------------------------------------------
const renderers = {};
const stack = [];
let current = null;

export function registerScreen(name, render) {
  renderers[name] = render;
}

export function go(name, params = {}, { replace = false } = {}) {
  if (current && !replace) stack.push(current);
  show(name, params);
}

/** Keep one spare history entry so the Android/browser back button maps to in-app back. */
export function initHistory() {
  history.pushState({ arcloom: 1 }, '');
}

/** Return to an existing screen in the back stack (or open it fresh), dropping what's above it. */
export function jump(name, params = {}) {
  const idx = stack.map((s) => s.name).lastIndexOf(name);
  if (idx >= 0) stack.length = idx;
  show(name, params, true);
}

export function back() {
  const prev = stack.pop();
  if (prev) show(prev.name, prev.params, true);
  else show('home', {}, true);
}

export function currentScreen() {
  return current?.name;
}

function show(name, params, isBack = false) {
  const leaving = current && renderers[current.name]?.leave;
  if (leaving) leaving();
  current = { name, params };
  document.querySelectorAll('.screen').forEach((s) => s.classList.toggle('active', s.id === 'screen-' + name));
  const el = document.getElementById('screen-' + name);
  el.classList.toggle('from-back', isBack);
  renderers[name]?.enter?.(el, params);
}

window.addEventListener('popstate', () => {
  const m = document.querySelector('.modal.open');
  if (m && !m.dataset.blocking) closeModal(m);
  else if (!m && current?.name !== 'home') back();
  else if (!m) return; // on home: let the app/browser exit
  initHistory();
});

// ---- modals & toasts ----------------------------------------------------------------
export function modal(html, { onClose, blocking = false, cls = '' } = {}) {
  const root = document.getElementById('modal-root');
  const el = document.createElement('div');
  el.className = `modal ${cls}`;
  if (blocking) el.dataset.blocking = '1';
  el.innerHTML = `<div class="modal-card" role="dialog" aria-modal="true">${html}</div>`;
  el._onClose = onClose;
  root.appendChild(el);
  requestAnimationFrame(() => el.classList.add('open'));
  if (!blocking) {
    el.addEventListener('pointerdown', (e) => {
      if (e.target === el) closeModal(el);
    });
  }
  const focusable = el.querySelector('button');
  focusable?.focus({ preventScroll: true });
  return el;
}

export function closeModal(el) {
  if (!el || el._closing) return;
  el._closing = true;
  el.classList.remove('open');
  el._onClose?.();
  setTimeout(() => el.remove(), 220);
}

export function closeAllModals() {
  document.querySelectorAll('#modal-root .modal').forEach(closeModal);
}

export function toast(text, { icon: ic = null, ms = 2200 } = {}) {
  const root = document.getElementById('toasts');
  const el = document.createElement('div');
  el.className = 'toast';
  el.setAttribute('role', 'status');
  el.innerHTML = `${ic ? icon(ic) : ''}<span>${esc(text)}</span>`;
  root.appendChild(el);
  requestAnimationFrame(() => el.classList.add('show'));
  setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => el.remove(), 300);
  }, ms);
}

/** Delegate clicks on [data-act] elements inside root to handlers. */
export function bindActions(root, handlers) {
  root.onclick = (e) => {
    const t = e.target.closest('[data-act]');
    if (!t || !root.contains(t) || t.disabled) return;
    const fn = handlers[t.dataset.act];
    if (fn) {
      sfx.ui();
      fn(t, e);
    }
  };
}

export function starsHtml(n, total = 3, cls = '') {
  let s = '';
  for (let i = 0; i < total; i++) s += `<span class="st ${i < n ? 'on' : ''} ${cls}">${icon('star')}</span>`;
  return s;
}
