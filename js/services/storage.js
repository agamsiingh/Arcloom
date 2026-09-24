// Offline local progress. Everything lives in localStorage under one versioned key.

const KEY = 'arcloom.save.v1';

export const DEFAULT_SETTINGS = {
  theme: 'system', // system | light | dark | amoled
  sound: true,
  soundVolume: 0.8,
  music: true,
  musicVolume: 0.35,
  haptics: true,
  tapConfirm: false,
  largeHitboxes: false,
  reducedMotion: false,
  highContrast: false,
  textScale: 1,
  mode: 'challenge', // challenge | zen
};

function defaults() {
  return {
    version: 1,
    levels: {}, // n -> { stars, best, perfect }
    unlocked: 1,
    hints: 3,
    adFree: false,
    settings: { ...DEFAULT_SETTINGS },
    stats: {
      totalScore: 0, perfect: 0, zenWins: 0, challengeWins: 0, noHintWins: 0,
      maxCombo: 1, maxChain: 0, dailyCount: 0, mistakes: 0, launches: 0,
    },
    daily: { done: {}, streak: 0, best: 0, last: null },
    achievements: {},
    seenTips: {},
    rewardedToday: { date: null, count: 0 },
  };
}

let data = null;
const listeners = new Set();

function merge(base, saved) {
  for (const k of Object.keys(saved || {})) {
    if (base[k] && typeof base[k] === 'object' && !Array.isArray(base[k]) && typeof saved[k] === 'object') {
      base[k] = merge(base[k], saved[k]);
    } else if (saved[k] !== undefined) {
      base[k] = saved[k];
    }
  }
  return base;
}

export function load() {
  let saved = null;
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) saved = JSON.parse(raw);
  } catch {
    saved = null;
  }
  data = merge(defaults(), saved);
  return data;
}

export function save() {
  try {
    localStorage.setItem(KEY, JSON.stringify(data));
  } catch {
    // Storage full or unavailable (private mode): progress stays in memory.
  }
  listeners.forEach((fn) => fn(data));
}

export function get() {
  return data || load();
}

export function onChange(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function setSetting(key, value) {
  get().settings[key] = value;
  save();
}

export function resetProgress() {
  const keep = { ...get().settings };
  const adFree = get().adFree;
  data = defaults();
  data.settings = keep;
  data.adFree = adFree;
  save();
}

export function completedCount() {
  return Object.keys(get().levels).length;
}

export function totalStars() {
  return Object.values(get().levels).reduce((s, l) => s + (l.stars || 0), 0);
}
