// Achievement definitions + evaluation. Each unlock awards bonus hints.
import * as store from './storage.js';

const done = () => store.completedCount();

export const ACHIEVEMENTS = [
  { id: 'first', name: 'First Thread', desc: 'Clear your first level', reward: 1, goal: 1, value: done },
  { id: 'ten', name: 'Apprentice Weaver', desc: 'Clear 10 levels', reward: 2, goal: 10, value: done },
  { id: 'fifty', name: 'Journeyman', desc: 'Clear 50 levels', reward: 3, goal: 50, value: done },
  { id: 'hundred', name: 'Master Weaver', desc: 'Clear 100 levels', reward: 5, goal: 100, value: done },
  { id: 'all', name: 'The Grand Loom', desc: 'Clear all 150 levels', reward: 10, goal: 150, value: done },
  { id: 'perfect1', name: 'Flawless', desc: 'Get a perfect clear', reward: 1, goal: 1, value: (s) => s.stats.perfect },
  { id: 'perfect25', name: 'Perfectionist', desc: '25 perfect clears', reward: 3, goal: 25, value: (s) => s.stats.perfect },
  { id: 'combo5', name: 'In the Flow', desc: 'Reach a x5 combo', reward: 2, goal: 5, value: (s) => s.stats.maxCombo },
  { id: 'chain3', name: 'Chain Reaction', desc: 'Trigger a 3-spark chain', reward: 2, goal: 3, value: (s) => s.stats.maxChain },
  { id: 'daily1', name: 'Daily Weave', desc: 'Complete a daily challenge', reward: 1, goal: 1, value: (s) => s.stats.dailyCount },
  { id: 'streak3', name: 'Warm Streak', desc: 'Reach a 3-day daily streak', reward: 2, goal: 3, value: (s) => s.daily.best },
  { id: 'streak7', name: 'Week of Weaving', desc: 'Reach a 7-day daily streak', reward: 5, goal: 7, value: (s) => s.daily.best },
  { id: 'zen', name: 'Zen Garden', desc: 'Clear 20 levels in Zen mode', reward: 2, goal: 20, value: (s) => s.stats.zenWins },
  { id: 'challenger', name: 'Challenger', desc: 'Clear 20 levels in Challenge mode', reward: 2, goal: 20, value: (s) => s.stats.challengeWins },
  { id: 'selfmade', name: 'Self-Reliant', desc: 'Clear 25 levels without hints', reward: 3, goal: 25, value: (s) => s.stats.noHintWins },
  { id: 'score', name: 'High Tension', desc: 'Earn 250,000 total points', reward: 3, goal: 250000, value: (s) => s.stats.totalScore },
  { id: 'explorer', name: 'Explorer', desc: 'Reach the Phantoms chapter', reward: 3, goal: 91, value: (s) => s.unlocked },
];

/** Unlocks anything newly earned. Returns the list of newly unlocked achievements. */
export function evaluate() {
  const s = store.get();
  const fresh = [];
  for (const a of ACHIEVEMENTS) {
    if (s.achievements[a.id]) continue;
    if (a.value(s) >= a.goal) {
      s.achievements[a.id] = Date.now();
      s.hints += a.reward;
      fresh.push(a);
    }
  }
  if (fresh.length) store.save();
  return fresh;
}

export function progress(a) {
  return Math.min(1, a.value(store.get()) / a.goal);
}
