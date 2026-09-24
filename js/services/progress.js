// Records level results, daily streaks and rewards; triggers achievement checks.
import * as store from './storage.js';
import { evaluate } from './achievements.js';
import { LEVEL_COUNT, dateKey } from '../core/levels.js';

export const PERFECT_HINT_REWARD = 1;
export const DAILY_HINT_REWARD = 2;

export function yesterdayKey(from = new Date()) {
  const d = new Date(from);
  d.setDate(d.getDate() - 1);
  return dateKey(d);
}

export function currentStreak() {
  const { daily } = store.get();
  if (daily.last === dateKey() || daily.last === yesterdayKey()) return daily.streak;
  return 0;
}

/**
 * @param {{ kind: 'level'|'daily', id: number|string, res: object, session: object }} p
 */
export function recordWin({ kind, id, res, session }) {
  const s = store.get();
  let hints = 0;
  let firstClear = false;

  if (kind === 'level') {
    const prev = s.levels[id];
    firstClear = !prev;
    s.levels[id] = {
      stars: Math.max(prev?.stars || 0, res.stars),
      best: Math.max(prev?.best || 0, res.total),
      perfect: !!(prev?.perfect || res.perfect),
    };
    s.unlocked = Math.min(LEVEL_COUNT, Math.max(s.unlocked, id + 1));
    if (res.perfect && !prev?.perfect) hints += PERFECT_HINT_REWARD;
  } else {
    const prev = s.daily.done[id];
    firstClear = !prev;
    s.daily.done[id] = { stars: Math.max(prev?.stars || 0, res.stars), best: Math.max(prev?.best || 0, res.total) };
    if (firstClear) {
      hints += DAILY_HINT_REWARD;
      s.stats.dailyCount++;
      if (id === dateKey()) {
        s.daily.streak = s.daily.last === yesterdayKey() ? s.daily.streak + 1 : s.daily.last === id ? s.daily.streak : 1;
        s.daily.last = id;
        s.daily.best = Math.max(s.daily.best, s.daily.streak);
      }
    }
  }

  const st = s.stats;
  st.totalScore += res.total;
  if (res.perfect) st.perfect++;
  if (session.mode === 'zen') st.zenWins++;
  else st.challengeWins++;
  if (session.hintsUsed === 0) st.noHintWins++;
  st.maxCombo = Math.max(st.maxCombo, res.maxMult);
  st.maxChain = Math.max(st.maxChain, res.maxChain);
  s.hints += hints;
  store.save();
  const achievements = evaluate();
  return { hints, firstClear, achievements };
}

export function recordStats(session) {
  const st = store.get().stats;
  st.mistakes += session.mistakes;
  st.launches += session.moves;
  store.save();
}
