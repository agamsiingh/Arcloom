// Settings screen + shared toggle widgets + applying theme/accessibility/audio settings.
import * as store from '../services/storage.js';
import * as audio from '../services/audio.js';
import { setEnabled as setHaptics } from '../services/haptics.js';
import { restorePurchases } from '../services/monetization.js';
import { icon, bindActions, back, modal, closeModal, toast, esc } from './dom.js';

const TOGGLES = {
  sound: ['Sound effects', 'Taps, slides, chains and chimes'],
  music: ['Music', 'Calm generative ambience'],
  haptics: ['Haptics', 'Subtle vibration feedback'],
  tapConfirm: ['Tap to confirm', 'First tap selects and previews the lane, second tap launches'],
  largeHitboxes: ['Large touch targets', 'Even more generous invisible hitboxes'],
  reducedMotion: ['Reduce motion', 'Shorter animations, fewer particles'],
  highContrast: ['High contrast', 'Stronger colours and outlines'],
};

export function toggleListHtml(keys) {
  const s = store.get().settings;
  return keys.map((k) => `
    <label class="toggle">
      <span class="tl"><b>${TOGGLES[k][0]}</b><small>${TOGGLES[k][1]}</small></span>
      <input type="checkbox" role="switch" data-setting="${k}" ${s[k] ? 'checked' : ''}>
      <i class="sw" aria-hidden="true"></i>
    </label>`).join('');
}

export function bindToggles(root, after) {
  root.onchange = (e) => {
    const t = e.target;
    if (!t.dataset.setting) return;
    const k = t.dataset.setting;
    let v;
    if (t.type === 'checkbox') v = t.checked;
    else if (t.type === 'range') v = Number(t.value) / 100;
    else v = Number.isNaN(Number(t.value)) ? t.value : Number(t.value);
    store.setSetting(k, v);
    applySettings();
    audio.unlock();
    audio.sfx.ui();
    after?.(k, v);
  };
}

const darkMq = window.matchMedia('(prefers-color-scheme: dark)');
darkMq.addEventListener?.('change', () => applySettings());

export function applySettings() {
  const s = store.get().settings;
  const root = document.documentElement;
  const theme = s.theme === 'system' ? (darkMq.matches ? 'dark' : 'light') : s.theme;
  root.dataset.theme = theme;
  root.dataset.contrast = s.highContrast ? 'high' : 'normal';
  root.dataset.motion = s.reducedMotion ? 'reduce' : 'full';
  root.style.setProperty('--text-scale', s.textScale);
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.content = getComputedStyle(root).getPropertyValue('--bg').trim() || '#f6f3ee';
  audio.configure(s);
  setHaptics(s.haptics);
}

function seg(name, options, value) {
  return `<div class="seg" role="radiogroup">${options.map(([v, label]) => `
    <label class="${String(v) === String(value) ? 'on' : ''}">
      <input type="radio" name="${name}" data-setting="${name}" value="${v}" ${String(v) === String(value) ? 'checked' : ''}>${label}
    </label>`).join('')}</div>`;
}

function slider(key, label) {
  const s = store.get().settings;
  return `<label class="slider"><span>${label}</span>
    <input type="range" min="0" max="100" value="${Math.round(s[key] * 100)}" data-setting="${key}" aria-label="${esc(label)}"></label>`;
}

export const settingsScreen = {
  enter(el) {
    const s = store.get().settings;
    el.innerHTML = `
      <header class="topbar">
        <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
        <div class="title"><div class="t1">Settings</div></div><span class="icon-btn ghost-slot"></span>
      </header>
      <div class="scroll">
        <section class="card">
          <h3>Play</h3>
          <div class="field"><span>Default mode</span>${seg('mode', [['challenge', 'Challenge'], ['zen', 'Zen']], s.mode)}</div>
          <p class="muted small">Challenge gives you 3 hearts per level. Zen has unlimited retries.</p>
          <div class="toggles">${toggleListHtml(['tapConfirm', 'largeHitboxes'])}</div>
        </section>
        <section class="card">
          <h3>Audio</h3>
          <div class="toggles">${toggleListHtml(['sound'])}</div>
          ${slider('soundVolume', 'Effects volume')}
          <div class="toggles">${toggleListHtml(['music'])}</div>
          ${slider('musicVolume', 'Music volume')}
          <div class="toggles">${toggleListHtml(['haptics'])}</div>
        </section>
        <section class="card">
          <h3>Display & accessibility</h3>
          <div class="field"><span>Theme</span>${seg('theme', [['system', 'Auto'], ['light', 'Light'], ['dark', 'Dark'], ['amoled', 'AMOLED']], s.theme)}</div>
          <div class="field"><span>Text size</span>${seg('textScale', [[1, 'A'], [1.15, 'A+'], [1.3, 'A++']], s.textScale)}</div>
          <div class="toggles">${toggleListHtml(['reducedMotion', 'highContrast'])}</div>
          <p class="muted small">Colour barriers always carry stripe / dot patterns and every special arrow has its own symbol, so no mechanic relies on colour alone.</p>
        </section>
        <section class="card">
          <h3>Data</h3>
          <p class="muted small">Your progress is saved on this device only and works fully offline. No account, no tracking.</p>
          <div class="row">
            <button class="btn ghost" data-act="restore">${icon('gem')} Restore purchase</button>
            <button class="btn danger-ghost" data-act="reset">${icon('restart')} Reset progress</button>
          </div>
        </section>
        <p class="muted small center">ARCLOOM v1.0.0</p>
      </div>`;
    bindActions(el, {
      back: () => back(),
      restore: async () => toast((await restorePurchases()) ? 'Supporter restored' : 'No purchase found'),
      reset: () => {
        const m = modal(`<h2>Reset progress?</h2><p class="muted">Levels, stars, streaks and achievements will be erased. Settings and purchases are kept.</p>
          <div class="row"><button class="btn ghost" data-r="no">Cancel</button><button class="btn danger" data-r="yes">Reset</button></div>`);
        m.addEventListener('click', (e) => {
          const b = e.target.closest('[data-r]');
          if (!b) return;
          if (b.dataset.r === 'yes') {
            store.resetProgress();
            toast('Progress reset');
          }
          closeModal(m);
        });
      },
    });
    bindToggles(el, (k) => {
      if (k === 'mode' || k === 'theme' || k === 'textScale') {
        const name = k;
        el.querySelectorAll(`input[name="${name}"]`).forEach((i) => i.parentElement.classList.toggle('on', i.checked));
      }
    });
  },
};
