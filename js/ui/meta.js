// Daily challenge calendar, trophies (achievements) and the supporter shop.
import * as store from '../services/storage.js';
import { dateKey } from '../core/levels.js';
import { ACHIEVEMENTS, progress } from '../services/achievements.js';
import { currentStreak } from '../services/progress.js';
import {
  showRewarded, purchaseAdFree, restorePurchases, rewardedLeft,
  AD_FREE_PRICE, SUPPORTER_BONUS_HINTS,
} from '../services/monetization.js';
import { icon, bindActions, go, back, toast, esc } from './dom.js';

let monthOffset = 0;

export const dailyScreen = {
  enter(el) {
    monthOffset = 0;
    render(el);
  },
};

function render(el) {
  const s = store.get();
  const today = new Date();
  const todayKey = dateKey(today);
  const view = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
  const daysIn = new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate();
  const lead = view.getDay();
  let doneInMonth = 0;
  let cells = '';
  for (let i = 0; i < lead; i++) cells += '<span class="day empty"></span>';
  for (let d = 1; d <= daysIn; d++) {
    const key = dateKey(new Date(view.getFullYear(), view.getMonth(), d));
    const done = s.daily.done[key];
    if (done) doneInMonth++;
    const future = key > todayKey;
    const isToday = key === todayKey;
    cells += `<button class="day ${done ? 'done' : ''} ${isToday ? 'today' : ''}" data-act="day" data-key="${key}"
      ${future ? 'disabled' : ''} aria-label="${key}${done ? ', completed' : ''}">${done ? icon('star') : ''}<span>${d}</span></button>`;
  }
  const todayDone = !!s.daily.done[todayKey];
  const monthName = view.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
  const week = ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => `<span>${d}</span>`).join('');
  el.innerHTML = `
    <header class="topbar">
      <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
      <div class="title"><div class="t1">Daily Weave</div><div class="t2">A fresh puzzle every day</div></div>
      <span class="icon-btn ghost-slot"></span>
    </header>
    <div class="scroll">
      <section class="card streak-card">
        <div class="streak-num">${icon('flame')}<b>${currentStreak()}</b><small>day streak</small></div>
        <div class="streak-best"><small>Best</small><b>${s.daily.best}</b></div>
        <div class="streak-best"><small>Total</small><b>${Object.keys(s.daily.done).length}</b></div>
      </section>
      <section class="card">
        <div class="cal-head">
          <button class="icon-btn" data-act="prev" aria-label="Previous month">${icon('back')}</button>
          <b>${esc(monthName)}</b>
          <span class="cal-count">${icon('star')} ${doneInMonth}/${daysIn}</span>
          <button class="icon-btn flip" data-act="nextm" aria-label="Next month" ${monthOffset >= 0 ? 'disabled' : ''}>${icon('back')}</button>
        </div>
        <div class="cal-week">${week}</div>
        <div class="cal-grid">${cells}</div>
        <p class="muted small">Past days can be replayed any time; only today's puzzle grows your streak. Each first clear earns 2 hints.</p>
      </section>
      <button class="btn primary huge" data-act="today">
        <span>${todayDone ? 'Replay today' : 'Play today'}</span><small>${today.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</small>
      </button>
    </div>`;
  bindActions(el, {
    back: () => back(),
    today: () => go('game', { kind: 'daily', id: todayKey }),
    day: (b) => go('game', { kind: 'daily', id: b.dataset.key }),
    prev: () => { monthOffset--; render(el); },
    nextm: () => { monthOffset = Math.min(0, monthOffset + 1); render(el); },
  });
}

export const trophiesScreen = {
  enter(el) {
    const s = store.get();
    const items = ACHIEVEMENTS.map((a) => {
      const got = !!s.achievements[a.id];
      const p = progress(a);
      return `<li class="ach ${got ? 'got' : ''}">
        <span class="ach-ic">${icon(got ? 'trophy' : 'lock')}</span>
        <div class="ach-body"><b>${esc(a.name)}</b><small>${esc(a.desc)}</small>
          ${got ? '' : `<div class="bar"><i style="transform:scaleX(${p.toFixed(3)})"></i></div>`}</div>
        <span class="ach-reward">${icon('bulb')}+${a.reward}</span>
      </li>`;
    }).join('');
    const st = s.stats;
    el.innerHTML = `
      <header class="topbar">
        <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
        <div class="title"><div class="t1">Trophies</div><div class="t2">${Object.keys(s.achievements).length} / ${ACHIEVEMENTS.length} unlocked</div></div>
        <span class="icon-btn ghost-slot"></span>
      </header>
      <div class="scroll">
        <section class="card stats">
          <div><b>${st.totalScore.toLocaleString()}</b><small>Total score</small></div>
          <div><b>${st.perfect}</b><small>Perfect clears</small></div>
          <div><b>×${st.maxCombo}</b><small>Best combo</small></div>
          <div><b>${st.maxChain}</b><small>Longest chain</small></div>
          <div><b>${st.launches}</b><small>Launches</small></div>
          <div><b>${s.daily.best}</b><small>Best streak</small></div>
        </section>
        <ul class="ach-list">${items}</ul>
      </div>`;
    bindActions(el, { back: () => back() });
  },
};

export const shopScreen = {
  enter(el) {
    const s = store.get();
    const left = rewardedLeft();
    el.innerHTML = `
      <header class="topbar">
        <button class="icon-btn" data-act="back" aria-label="Back">${icon('back')}</button>
        <div class="title"><div class="t1">${s.adFree ? 'Supporter' : 'Go ad-free'}</div></div>
        <span class="icon-btn ghost-slot"></span>
      </header>
      <div class="scroll">
        <section class="card supporter ${s.adFree ? 'owned' : ''}">
          <div class="sup-badge">${icon('gem', 'xl')}</div>
          <h2>Arcloom Supporter</h2>
          <p class="muted">One-time purchase. Yours forever.</p>
          <ul class="perks">
            <li>${icon('check')} Never see an ad — hint & continue rewards are instant</li>
            <li>${icon('check')} ${SUPPORTER_BONUS_HINTS} bonus hints right away</li>
            <li>${icon('check')} Support an indie puzzle with no pay-walls</li>
          </ul>
          ${s.adFree
            ? `<div class="owned-tag">${icon('check')} Owned — thank you!</div>`
            : `<button class="btn primary huge" data-act="buy"><span>Unlock for ${AD_FREE_PRICE}</span></button>
               <button class="btn link" data-act="restore">Restore purchase</button>`}
        </section>
        <section class="card">
          <h3>Free hints</h3>
          <p class="muted small">Hints are also earned by perfect clears, daily puzzles and trophies. You have <b>${s.hints}</b>.</p>
          <button class="btn ghost" data-act="ad" ${left > 0 ? '' : 'disabled'}>${icon(s.adFree ? 'bulb' : 'film')} ${s.adFree ? 'Claim +2 hints' : 'Watch an ad · +2 hints'}</button>
          ${s.adFree ? '' : `<p class="muted small">${left > 0 ? `${left} left today` : 'Daily limit reached'}</p>`}
        </section>
        <p class="muted small center">Ads are always optional. There are no ads between levels, after mistakes, or during play.</p>
      </div>`;
    bindActions(el, {
      back: () => back(),
      buy: async () => {
        if (await purchaseAdFree()) {
          toast('Thank you for supporting Arcloom!', { icon: 'gem' });
          shopScreen.enter(el);
        }
      },
      restore: async () => {
        toast((await restorePurchases()) ? 'Supporter restored' : 'No purchase found');
        shopScreen.enter(el);
      },
      ad: async () => {
        if (s.adFree && store.get().rewardedToday.date === dateKey() && store.get().rewardedToday.count >= 5) {
          toast('That\'s plenty for today — come back tomorrow');
          return;
        }
        if (await showRewarded('hints')) {
          const cur = store.get();
          cur.hints += 2;
          if (cur.adFree) {
            if (cur.rewardedToday.date !== dateKey()) cur.rewardedToday = { date: dateKey(), count: 0 };
            cur.rewardedToday.count++;
          }
          store.save();
          toast('+2 hints', { icon: 'bulb' });
          shopScreen.enter(el);
        }
      },
    });
  },
};
