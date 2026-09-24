// Result / fail / stuck / tip / out-of-hints dialogs for the game screen.
import { icon, modal, closeModal, starsHtml, esc } from './dom.js';
import { sfx } from '../services/audio.js';
import * as store from '../services/storage.js';
import { rewardedLeft, AD_FREE_PRICE } from '../services/monetization.js';

const fmt = (n) => n.toLocaleString();

function wire(el, handlers) {
  el.addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]');
    if (!b || b.disabled) return;
    sfx.ui();
    const fn = handlers[b.dataset.act];
    if (fn) {
      closeModal(el);
      fn();
    }
  });
}

export function showWin({ res, rec, isDaily, streak, hasNext }, handlers) {
  const title = res.perfect ? 'Perfect Weave!' : 'Woven!';
  const rewards = [];
  if (rec.hints) rewards.push(`<span class="chip good">${icon('bulb')} +${rec.hints} hint${rec.hints > 1 ? 's' : ''}</span>`);
  for (const a of rec.achievements) {
    rewards.push(`<span class="chip gold">${icon('trophy')} ${esc(a.name)} · +${a.reward}</span>`);
  }
  const el = modal(`
    <div class="win">
      <div class="win-stars">${starsHtml(0, 3, 'big')}</div>
      <h2>${title}</h2>
      ${isDaily ? `<p class="muted">${icon('flame')} Daily streak: <b>${streak}</b></p>` : ''}
      <div class="score-table">
        <div><span>Launch points</span><b>${fmt(res.base)}</b></div>
        ${res.perfectBonus ? `<div><span>Perfect clear</span><b>+${fmt(res.perfectBonus)}</b></div>` : ''}
        ${res.heartBonus ? `<div><span>Hearts left</span><b>+${fmt(res.heartBonus)}</b></div>` : ''}
        <div class="total"><span>Total</span><b>${fmt(res.total)}</b></div>
      </div>
      ${rewards.length ? `<div class="rewards">${rewards.join('')}</div>` : ''}
      <div class="stack">
        ${hasNext ? `<button class="btn primary big" data-act="next">${icon('play')} Next level</button>` : ''}
        ${isDaily ? `<button class="btn primary big" data-act="calendar">${icon('calendar')} Calendar</button>` : ''}
        <div class="row">
          <button class="btn ghost" data-act="replay">${icon('restart')} Replay</button>
          <button class="btn ghost" data-act="menu">${icon('grid')} ${isDaily ? 'Home' : 'Levels'}</button>
        </div>
      </div>
    </div>`, { blocking: true, cls: 'win-modal' });
  const stars = el.querySelectorAll('.win-stars .st');
  stars.forEach((s, i) => {
    if (i < res.stars) {
      setTimeout(() => {
        s.classList.add('on', 'pop');
        sfx.star(i);
      }, 350 + i * 260);
    }
  });
  wire(el, handlers);
  return el;
}

export function showFail(handlers) {
  const s = store.get();
  const canAd = s.adFree || rewardedLeft() > 0;
  const el = modal(`
    <div class="center">
      <div class="big-ic danger">${icon('heart')}</div>
      <h2>Out of hearts</h2>
      <p class="muted">Keep your progress on the board and carry on, or start fresh.</p>
      <div class="stack">
        <button class="btn primary big" data-act="continue" ${canAd ? '' : 'disabled'}>
          ${s.adFree ? icon('heart') : icon('film')} Continue with +2 hearts${s.adFree ? '' : ' · watch ad'}
        </button>
        <button class="btn ghost" data-act="retry">${icon('restart')} Retry level</button>
        <button class="btn ghost" data-act="zen">${icon('leaf')} Switch to Zen mode</button>
      </div>
    </div>`, { blocking: true });
  wire(el, handlers);
  return el;
}

export function showStuck(handlers) {
  const el = modal(`
    <div class="center">
      <div class="big-ic">${icon('lock')}</div>
      <h2>No moves left</h2>
      <p class="muted">Every remaining arrow is blocked. Step back and try another order.</p>
      <div class="stack">
        <button class="btn primary big" data-act="undo">${icon('undo')} Undo last launch</button>
        <button class="btn ghost" data-act="restart">${icon('restart')} Restart</button>
      </div>
    </div>`, { blocking: true });
  wire(el, handlers);
  return el;
}

export function showTip({ title, text, mech }, onDone) {
  const el = modal(`
    <div class="center tip">
      <div class="tip-art">${tipArt(mech)}</div>
      <h2>${esc(title)}</h2>
      <p>${esc(text)}</p>
      <button class="btn primary big" data-act="ok">Got it</button>
    </div>`, { onClose: onDone });
  wire(el, { ok: () => {} });
  return el;
}

export function showNoHints(handlers) {
  const s = store.get();
  const left = rewardedLeft();
  const el = modal(`
    <div class="center">
      <div class="big-ic">${icon('bulb')}</div>
      <h2>Out of hints</h2>
      <p class="muted">Earn hints with perfect clears, daily challenges and achievements — or grab a couple now.</p>
      <div class="stack">
        <button class="btn primary big" data-act="ad" ${left > 0 ? '' : 'disabled'}>${icon('film')} Watch ad · +2 hints</button>
        ${s.adFree ? '' : `<button class="btn ghost" data-act="shop">${icon('gem')} Go ad-free · ${AD_FREE_PRICE}</button>`}
        <button class="btn ghost" data-act="close">Not now</button>
      </div>
      ${left > 0 ? '' : '<p class="muted small">Daily ad limit reached — come back tomorrow.</p>'}
    </div>`);
  wire(el, handlers);
  return el;
}

function tipArt(mech) {
  const map = {
    null: 'play', walls: 'grid', rotators: 'restart', locks: 'lock', portals: 'zoom',
    gates: 'back', cwalls: 'leaf', blockers: 'gem', sparks: 'bolt', ghosts: 'infinity',
  };
  return icon(map[mech] || 'play', 'xl');
}
