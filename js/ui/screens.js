// Home and level-select screens.
import * as store from '../services/storage.js';
import { LEVEL_COUNT, CHAPTERS, chapterOf, dateKey } from '../core/levels.js';
import { ACHIEVEMENTS } from '../services/achievements.js';
import { currentStreak } from '../services/progress.js';
import { icon, bindActions, go, back, starsHtml } from './dom.js';
import { applySettings } from './settings.js';

export const LOGO_SVG = `
<svg class="logo-mark" viewBox="0 0 120 120" aria-hidden="true">
  <rect x="6" y="6" width="108" height="108" rx="30" class="lm-bg"/>
  <g fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
    <path class="lm-a" d="M32 30v60"/>
    <path class="lm-b" d="M60 90V44"/>
    <path class="lm-a" d="M88 30v34"/>
    <path class="lm-c" d="M24 46h26M70 46h28"/>
    <path class="lm-c" d="M24 74h16M50 74h20M80 74h14"/>
  </g>
  <path class="lm-head" d="M60 26l-12 16h24z"/>
</svg>`;

function nextLevel() {
  const s = store.get();
  for (let n = 1; n <= Math.min(s.unlocked, LEVEL_COUNT); n++) if (!s.levels[n]) return n;
  return Math.min(s.unlocked, LEVEL_COUNT);
}

export const homeScreen = {
  enter(el) {
    const s = store.get();
    const n = nextLevel();
    const ch = CHAPTERS[chapterOf(n)];
    const stars = Object.values(s.levels).reduce((a, l) => a + l.stars, 0);
    const done = Object.keys(s.levels).length;
    const trophies = Object.keys(s.achievements).length;
    const dailyDone = !!s.daily.done[dateKey()];
    el.innerHTML = `
      <div class="home">
        <header class="home-top">
          <span class="pill" title="Daily streak">${icon('flame')}<b>${currentStreak()}</b></span>
          <span class="pill" title="Stars">${icon('star')}<b>${stars}</b></span>
          <span class="pill" title="Hints">${icon('bulb')}<b>${s.hints}</b></span>
          <span class="spacer"></span>
          <button class="icon-btn" data-act="settings" aria-label="Settings">${icon('gear')}</button>
        </header>
        <div class="brand">
          ${LOGO_SVG}
          <h1>ARCLOOM</h1>
          <p class="tagline">weave · launch · unravel</p>
        </div>
        <div class="mode-seg" role="radiogroup" aria-label="Mode">
          <button data-act="mode" data-mode="challenge" class="${s.settings.mode === 'challenge' ? 'on' : ''}" role="radio" aria-checked="${s.settings.mode === 'challenge'}">${icon('heart')} Challenge</button>
          <button data-act="mode" data-mode="zen" class="${s.settings.mode === 'zen' ? 'on' : ''}" role="radio" aria-checked="${s.settings.mode === 'zen'}">${icon('leaf')} Zen</button>
        </div>
        <button class="btn primary huge" data-act="play">
          <span>${done >= LEVEL_COUNT ? 'Replay' : 'Play'}</span>
          <small>Level ${n} · ${ch.name}</small>
        </button>
        <div class="tiles">
          <button class="tile ${dailyDone ? 'done' : 'glow'}" data-act="daily">
            ${icon('calendar')}<b>Daily Weave</b><small>${dailyDone ? 'Completed today' : 'New puzzle today'}</small>
          </button>
          <button class="tile" data-act="levels">${icon('grid')}<b>Levels</b><small>${done} / ${LEVEL_COUNT}</small></button>
          <button class="tile" data-act="trophies">${icon('trophy')}<b>Trophies</b><small>${trophies} / ${ACHIEVEMENTS.length}</small></button>
          <button class="tile" data-act="shop">${icon('gem')}<b>${s.adFree ? 'Supporter' : 'Go ad-free'}</b><small>${s.adFree ? 'Thank you!' : 'Hints & perks'}</small></button>
        </div>
      </div>`;
    bindActions(el, {
      play: () => go('game', { kind: 'level', id: n }),
      daily: () => go('daily'),
      levels: () => go('levels', { focus: n }),
      trophies: () => go('trophies'),
      shop: () => go('shop'),
      settings: () => go('settings'),
      mode: (b) => {
        store.setSetting('mode', b.dataset.mode);
        applySettings();
        el.querySelectorAll('[data-mode]').forEach((x) => {
          x.classList.toggle('on', x === b);
          x.setAttribute('aria-checked', x === b);
        });
      },
    });
  },
};

export const levelsScreen = {
  enter(el, params = {}) {
    const s = store.get();
    let html = '';
    for (let c = 0; c < CHAPTERS.length; c++) {
      const first = c * 10 + 1;
      const lastN = Math.min(LEVEL_COUNT, first + 9);
      if (first > LEVEL_COUNT) break;
      const locked = first > s.unlocked;
      let got = 0;
      let cells = '';
      for (let n = first; n <= lastN; n++) {
        const rec = s.levels[n];
        got += rec?.stars || 0;
        const open = n <= s.unlocked;
        cells += `<button class="lvl ${rec ? 'done' : ''} ${open ? '' : 'locked'} ${rec?.perfect ? 'perfect' : ''}"
          data-act="open" data-n="${n}" ${open ? '' : 'disabled'} aria-label="Level ${n}${rec ? `, ${rec.stars} stars` : open ? '' : ', locked'}">
          ${open ? `<b>${n}</b><span class="mini-stars">${starsHtml(rec?.stars || 0)}</span>` : icon('lock')}
        </button>`;
      }
      html += `
        <section class="chapter ${locked ? 'locked' : ''}" id="ch-${c}">
          <div class="ch-head">
            <div><h3>${CHAPTERS[c].name}</h3><small>${chapterBlurb(c)}</small></div>
            <span class="ch-stars">${icon('star')} ${got}/30</span>
          </div>
          <div class="lvl-grid">${cells}</div>
        </section>`;
    }
    el.innerHTML = `
      <header class="topbar">
        <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
        <div class="title"><div class="t1">Levels</div><div class="t2">${Object.keys(s.levels).length} / ${LEVEL_COUNT} woven</div></div>
        <span class="icon-btn ghost-slot"></span>
      </header>
      <div class="scroll">${html}</div>`;
    bindActions(el, {
      back: () => back(),
      open: (b) => go('game', { kind: 'level', id: Number(b.dataset.n) }),
    });
    const focus = params.focus || s.unlocked;
    const target = el.querySelector(`#ch-${chapterOf(focus)}`);
    if (target) requestAnimationFrame(() => target.scrollIntoView({ block: 'center' }));
  },
};

function chapterBlurb(c) {
  return [
    'Launch arrows in the right order',
    'Stone blocks that never move',
    'Spinners turn after every launch',
    'Padlocks open after N launches',
    'Linked portals bend your lanes',
    'One-way gates',
    'Colour barriers & switches',
    'Drifting blockers on tracks',
    'Self-launching sparks & chains',
    'Phantoms pass through arrows',
    'Every mechanic, woven together',
  ][Math.min(c, 10)];
}
