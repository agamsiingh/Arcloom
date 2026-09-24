// Game screen controller: wires session + board view + input + HUD + audio/haptics.
import { Session } from './session.js';
import { BoardView } from './renderer.js';
import { attachInput } from './input.js';
import { getLevel, getDailyLevel, LEVEL_COUNT, CHAPTERS, dateKey } from '../core/levels.js';
import * as store from '../services/storage.js';
import * as audio from '../services/audio.js';
import { buzz } from '../services/haptics.js';
import { showRewarded } from '../services/monetization.js';
import { recordWin, recordStats, currentStreak } from '../services/progress.js';
import { icon, $, bindActions, go, back, jump, toast, closeAllModals, closeModal, modal } from '../ui/dom.js';
import { showWin, showFail, showStuck, showTip, showNoHints } from '../ui/gameModals.js';
import { toggleListHtml, bindToggles } from '../ui/settings.js';

const { sfx } = audio;
let el, view, session, params, raf = 0, last = 0, detachInput = null, bannerTimer = 0;
let lastTheme = '';

// Test/debug hook (only with ?debug in the URL).
if (new URLSearchParams(location.search).has('debug')) {
  window.__arcloom = { go, get view() { return view; }, get session() { return session; } };
}

function markup() {
  return `
    <header class="topbar">
      <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
      <div class="title"><div class="t1" id="g-title"></div><div class="t2" id="g-sub"></div></div>
      <button class="icon-btn" data-act="quick" aria-label="Quick settings">${icon('gear')}</button>
    </header>
    <div class="hud">
      <div class="hud-left" id="g-hearts" aria-live="polite"></div>
      <div class="hud-mid"><div id="g-score" class="score">0</div><div id="g-combo" class="combo">×1</div></div>
      <div class="hud-right"><span id="g-left">0</span><small>left</small></div>
    </div>
    <div class="board-wrap">
      <canvas id="board" aria-label="Puzzle board"></canvas>
      <div id="g-banner" class="banner" role="status"></div>
      <button id="g-zoom" class="zoom-btn" data-act="zoomReset" hidden>${icon('zoom')} Fit</button>
    </div>
    <footer class="tools">
      <button class="tool" data-act="undo" id="g-undo">${icon('undo')}<span>Undo</span></button>
      <button class="tool" data-act="restart">${icon('restart')}<span>Restart</span></button>
      <button class="tool" data-act="hint">${icon('bulb')}<span>Hint</span><b class="badge" id="g-hints">0</b></button>
    </footer>`;
}

function init(screen) {
  el = screen;
  el.innerHTML = markup();
  view = new BoardView($('#board', el));
  bindActions(el, {
    back: () => back(),
    quick: openQuick,
    undo: undo,
    restart: () => restart(),
    hint: hint,
    zoomReset: () => {
      view.resetZoom();
      updateZoomBtn();
    },
  });
  window.addEventListener('resize', () => {
    if (session && el.classList.contains('active')) view.resize();
  });
}

export const gameScreen = {
  enter(screen, p) {
    if (!el) init(screen);
    params = p;
    closeAllModals();
    startLevel();
    detachInput = attachInput($('#board', el), view, { onTap, onZoomChange: updateZoomBtn });
    last = performance.now();
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(loop);
  },
  leave() {
    cancelAnimationFrame(raf);
    raf = 0;
    detachInput?.();
    detachInput = null;
    finalizeStats();
  },
};

function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  const theme = document.documentElement.dataset.theme + document.documentElement.dataset.contrast;
  if (theme !== lastTheme) {
    lastTheme = theme;
    view.readTheme();
  }
  view.frame(now, dt);
  raf = requestAnimationFrame(loop);
}

function currentLevel() {
  return params.kind === 'daily' ? getDailyLevel(params.id) : getLevel(params.id);
}

function startLevel() {
  const s = store.get();
  const level = currentLevel();
  session = new Session(level, { mode: s.settings.mode });
  view.reducedMotion = s.settings.reducedMotion;
  view.resize();
  view.setLevel(level, session);
  if (params.kind === 'daily') {
    $('#g-title', el).textContent = 'Daily Weave';
    $('#g-sub', el).textContent = new Date(params.id + 'T12:00').toLocaleDateString(undefined, { month: 'long', day: 'numeric' });
  } else {
    $('#g-title', el).textContent = `Level ${params.id}`;
    $('#g-sub', el).textContent = level.name;
  }
  updateHud();
  updateZoomBtn();
  maybeTip(level);
}

function maybeTip(level) {
  const s = store.get();
  if (params.kind !== 'level' || !level.tip || s.seenTips[level.id]) return;
  const ch = CHAPTERS[level.chapter];
  showTip({ title: level.id === 1 ? 'Welcome to Arcloom' : ch.name, text: level.tip, mech: ch.mech }, () => {
    s.seenTips[level.id] = 1;
    store.save();
  });
}

function finalizeStats() {
  if (session && !session.statsRecorded) {
    session.statsRecorded = true;
    recordStats(session);
  }
}

function restart(silent = false) {
  if (!silent) sfx.ui();
  finalizeStats();
  startLevel();
}

// ---- HUD ----------------------------------------------------------------------------
function updateHud() {
  const s = store.get();
  const hearts = $('#g-hearts', el);
  if (session.mode === 'zen') {
    hearts.innerHTML = `<span class="zen-chip">${icon('leaf')} Zen</span>`;
  } else {
    let h = '';
    for (let i = 0; i < session.maxHearts; i++) h += `<span class="heart ${i < session.hearts ? 'on' : ''}">${icon('heart')}</span>`;
    hearts.innerHTML = h;
    hearts.setAttribute('aria-label', `${session.hearts} hearts left`);
  }
  $('#g-score', el).textContent = session.score.toLocaleString();
  const combo = $('#g-combo', el);
  combo.textContent = `×${session.mult}`;
  combo.classList.toggle('hot', session.mult > 1);
  $('#g-left', el).textContent = session.left;
  $('#g-hints', el).textContent = s.hints;
  $('#g-undo', el).disabled = !session.canUndo();
}

function pulse(sel) {
  const n = $(sel, el);
  n.classList.remove('pulse');
  void n.offsetWidth;
  n.classList.add('pulse');
}

function banner(text) {
  const b = $('#g-banner', el);
  b.textContent = text;
  b.classList.add('show');
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => b.classList.remove('show'), 1500);
}

function updateZoomBtn() {
  $('#g-zoom', el).hidden = view.scale <= 1.01;
}

// ---- input --------------------------------------------------------------------------
function onTap(px, py) {
  audio.unlock();
  if (session.status !== 'playing') return;
  const s = store.get().settings;
  const hit = view.hitTest(px, py, { large: s.largeHitboxes });
  if (!hit) {
    if (view.selected >= 0) view.selected = -1;
    return;
  }
  if (hit.ambiguous && view.selected >= 0 && (view.selected === hit.i || view.selected === hit.alt)) {
    launch(view.selected);
    return;
  }
  const needsConfirm = s.tapConfirm || hit.ambiguous;
  if (needsConfirm && view.selected !== hit.i) {
    view.selected = hit.i;
    sfx.select();
    buzz('select');
    banner(hit.ambiguous && !s.tapConfirm ? 'Two arrows here — tap again to launch' : 'Tap again to launch');
    return;
  }
  launch(hit.i);
}

function launch(i) {
  view.selected = -1;
  const res = session.tap(i, Date.now());
  if (res.result === 'locked') {
    view.shake(i);
    sfx.locked();
    buzz('light');
    const need = session.level.arrows[i].lock - session.st.cleared;
    banner(`Locked — ${need} more launch${need > 1 ? 'es' : ''} to open`);
    return;
  }
  if (res.result === 'blocked') {
    view.addBump(i, res.trace, session.st.dirs[i]);
    sfx.bump();
    buzz('error');
    updateHud();
    if (session.mode === 'challenge') pulse('#g-hearts');
    if (session.status === 'failed') setTimeout(fail, 480);
    return;
  }
  if (res.result !== 'cleared') return;

  view.hint = -1;
  let rotated = false;
  let chainDepth = 0;
  for (const e of res.events) {
    if (e.type === 'clear') {
      view.addSlide(e.i, e.trace, e.dir);
      if (e.trace.pts.some((p) => p[2])) setTimeout(() => sfx.portal(), 80);
      if (e.chain > 0) {
        chainDepth = e.chain;
        const [hx, hy] = view.headOf(e.i);
        setTimeout(() => {
          sfx.chain(e.chain);
          buzz('chain');
          view.floatText(hx, hy - 0.3, `Chain ×${e.chain}`, view.c.spark);
        }, 110 * e.chain);
      }
    } else if (e.type === 'switch') {
      sfx.toggle();
    } else if (e.type === 'unlock') {
      view.unlock(e.i);
      setTimeout(() => sfx.unlock(), 120);
    } else if (e.type === 'rotate') {
      view.rotate(e.i);
      rotated = true;
    }
  }
  if (rotated) setTimeout(() => sfx.rotate(), 140);
  sfx.slide(Math.max(0, session.combo - 1));
  buzz('light');
  const [hx, hy] = view.headOf(i);
  view.floatText(hx, hy, `+${res.gained}`, view.c.accent);
  if (res.multUp) {
    sfx.combo(res.mult);
    buzz('medium');
    banner(`Combo ×${res.mult}!`);
    pulse('#g-combo');
  } else if (chainDepth >= 2) {
    banner(`Chain reaction ×${chainDepth}!`);
  }
  updateHud();
  if (session.status === 'won') setTimeout(win, 520);
  else if (session.stuck()) setTimeout(() => session.stuck() && stuck(), 650);
}

// ---- tools --------------------------------------------------------------------------
function undo() {
  if (!session.undo()) return;
  view.syncToState();
  updateHud();
  buzz('light');
}

async function hint() {
  if (session.status !== 'playing') return;
  if (view.hint >= 0 && session.st.alive[view.hint]) return;
  const s = store.get();
  if (s.hints <= 0) {
    showNoHints({
      ad: async () => {
        if (await showRewarded('hints')) {
          store.get().hints += 2;
          store.save();
          updateHud();
          toast('+2 hints', { icon: 'bulb' });
        }
      },
      shop: () => go('shop'),
      close: () => {},
    });
    return;
  }
  const m = session.findHint();
  if (m === 'dead') {
    toast('Dead end from here — try Undo', { icon: 'undo' });
    return;
  }
  s.hints--;
  store.save();
  session.useHint();
  view.hint = m;
  sfx.hint();
  buzz('select');
  updateHud();
}

function openQuick() {
  const m = modal(`
    <h2>Quick settings</h2>
    <div class="toggles">${toggleListHtml(['sound', 'music', 'haptics', 'tapConfirm', 'largeHitboxes', 'reducedMotion'])}</div>
    <div class="row">
      <button class="btn ghost" data-q="mode">${icon(session.mode === 'zen' ? 'heart' : 'leaf')} Restart in ${session.mode === 'zen' ? 'Challenge' : 'Zen'}</button>
      <button class="btn primary" data-q="close">Done</button>
    </div>`);
  bindToggles(m, () => { view.reducedMotion = store.get().settings.reducedMotion; });
  m.addEventListener('click', (e) => {
    const b = e.target.closest('[data-q]');
    if (!b) return;
    closeModal(m);
    if (b.dataset.q === 'mode') {
      store.setSetting('mode', session.mode === 'zen' ? 'challenge' : 'zen');
      restart(true);
    }
  });
}

// ---- outcomes -----------------------------------------------------------------------
function win() {
  const res = session.results();
  const kind = params.kind;
  finalizeStats();
  const rec = recordWin({ kind, id: params.id, res, session });
  view.celebrate();
  sfx.complete();
  buzz('success');
  const hasNext = kind === 'level' && params.id < LEVEL_COUNT;
  showWin({ res, rec, isDaily: kind === 'daily', streak: currentStreak(), hasNext }, {
    next: () => go('game', { kind: 'level', id: params.id + 1 }, { replace: true }),
    replay: () => restart(true),
    menu: () => (kind === 'daily' ? jump('home') : jump('levels', { focus: params.id })),
    calendar: () => jump('daily'),
  });
  updateHud();
}

function fail() {
  sfx.fail();
  showFail({
    continue: async () => {
      if (await showRewarded('continue')) {
        session.continueRun(2);
        updateHud();
        toast('+2 hearts — keep weaving!', { icon: 'heart' });
      } else {
        fail();
      }
    },
    retry: () => restart(true),
    zen: () => {
      store.setSetting('mode', 'zen');
      restart(true);
      toast('Zen mode: unlimited retries', { icon: 'leaf' });
    },
  });
}

function stuck() {
  showStuck({
    undo: () => undo(),
    restart: () => restart(true),
  });
}

export function todayKey() {
  return dateKey();
}
