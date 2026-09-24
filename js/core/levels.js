// Level catalog: chapters, difficulty curve, handcrafted + procedural levels, dailies.
import { Rng, hashString } from './rng.js';
import { normalizeLevel } from './model.js';
import { generateLevel } from './generator.js';
import { HANDCRAFTED } from './handcrafted.js';
import { BAKED } from './baked.js';
import { decodeLevel } from './codec.js';

export const LEVEL_COUNT = 150;

export const CHAPTERS = [
  { name: 'First Threads', mech: null, icon: 'arrow' },
  { name: 'Stone', mech: 'walls', icon: 'stone' },
  { name: 'Spin', mech: 'rotators', icon: 'spin' },
  { name: 'Locks', mech: 'locks', icon: 'lock' },
  { name: 'Portals', mech: 'portals', icon: 'portal' },
  { name: 'Gates', mech: 'gates', icon: 'gate' },
  { name: 'Tides', mech: 'cwalls', icon: 'switch' },
  { name: 'Drifters', mech: 'blockers', icon: 'drifter' },
  { name: 'Sparks', mech: 'sparks', icon: 'spark' },
  { name: 'Phantoms', mech: 'ghosts', icon: 'ghost' },
  { name: 'Grand Loom I', mech: 'mix', icon: 'loom' },
  { name: 'Grand Loom II', mech: 'mix', icon: 'loom' },
  { name: 'Grand Loom III', mech: 'mix', icon: 'loom' },
  { name: 'Grand Loom IV', mech: 'mix', icon: 'loom' },
  { name: 'Grand Loom V', mech: 'mix', icon: 'loom' },
];

const MECH_ORDER = ['walls', 'rotators', 'locks', 'portals', 'gates', 'cwalls', 'blockers', 'sparks', 'ghosts'];

export function chapterOf(n) {
  return Math.min(CHAPTERS.length - 1, Math.floor((n - 1) / 10));
}

function featureAmount(mech, area, k, main) {
  const s = main ? 1 : 0.5;
  const scale = area / 49;
  switch (mech) {
    case 'walls': return Math.round((2 + k / 3) * scale * s);
    case 'rotators': return Math.max(1, Math.round((1 + k / 4) * Math.sqrt(scale) * s));
    case 'locks': return Math.max(1, Math.round((2 + k / 3) * Math.sqrt(scale) * s));
    case 'portals': return Math.max(1, Math.round((1 + (area > 90 ? 1 : 0) + k / 6) * s));
    case 'gates': return Math.max(1, Math.round((2 + k / 3) * Math.sqrt(scale) * s));
    case 'cwalls': return Math.max(2, Math.round((3 + k / 3) * Math.sqrt(scale) * s));
    case 'blockers': return Math.max(1, Math.round((1 + (area > 100 ? 1 : 0)) * s));
    case 'sparks': return Math.max(1, Math.round((3 + k / 2) * Math.sqrt(scale) * s));
    case 'ghosts': return Math.max(1, Math.round((1 + k / 4) * Math.sqrt(scale) * s));
    default: return 0;
  }
}

function applyMech(feat, mech, area, k, main) {
  const amt = featureAmount(mech, area, k, main);
  feat[mech] = Math.max(feat[mech] || 0, amt);
  if (mech === 'cwalls') feat.switches = Math.max(feat.switches || 0, main ? 1 + (k > 5 ? 1 : 0) : 1);
}

export function paramsFor(n) {
  const ch = chapterOf(n);
  const k = (n - 1) % 10;
  const t = (n - 1) / (LEVEL_COUNT - 1);
  const rng = new Rng(hashString('arcloom-params-' + n));
  const base = 5 + Math.floor(n / 13) + (k >= 6 ? 1 : 0) - (k === 0 ? 1 : 0);
  const w = Math.max(5, Math.min(13, base));
  const h = Math.max(5, Math.min(17, base + 1 + Math.floor(n / 35)));
  const area = w * h;
  const feat = {};
  const chapter = CHAPTERS[ch];
  if (chapter.mech === 'mix') {
    const pool = rng.shuffle(MECH_ORDER.slice());
    const count = 2 + Math.min(2, Math.floor((n - 100) / 18)) + (k >= 8 ? 1 : 0);
    pool.slice(0, count).forEach((m, i) => applyMech(feat, m, area, k, i < 2));
  } else if (chapter.mech) {
    applyMech(feat, chapter.mech, area, k, true);
    const learned = MECH_ORDER.slice(0, MECH_ORDER.indexOf(chapter.mech));
    for (const m of learned) if (rng.chance(0.18 + k * 0.02)) applyMech(feat, m, area, k, false);
  }
  return {
    id: n,
    seed: hashString('arcloom-level-' + n),
    w, h,
    density: Math.min(0.94, 0.74 + 0.18 * t + k * 0.004),
    minLen: n > 70 ? 3 : 2,
    maxLen: Math.min(9, 3 + Math.floor(n / 20)),
    turn: 0.18 + 0.32 * t,
    feat,
  };
}

const cache = new Map();

export function getLevel(n) {
  if (cache.has(n)) return cache.get(n);
  let level;
  const ch = chapterOf(n);
  if (HANDCRAFTED[n]) {
    level = normalizeLevel({ id: n, ...HANDCRAFTED[n] });
  } else if (BAKED[n]) {
    level = decodeLevel(BAKED[n], n);
  } else {
    level = generateLevel(paramsFor(n));
  }
  level.id = n;
  level.chapter = ch;
  level.name = CHAPTERS[ch].name;
  cache.set(n, level);
  return level;
}

export function dateKey(d = new Date()) {
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${m}-${day}`;
}

export function getDailyLevel(key) {
  const cacheKey = 'daily-' + key;
  if (cache.has(cacheKey)) return cache.get(cacheKey);
  const seed = hashString('arcloom-daily-' + key);
  const rng = new Rng(seed);
  const w = rng.int(7, 9);
  const h = w + rng.int(1, 3);
  const feat = {};
  const mechs = rng.shuffle(MECH_ORDER.slice()).slice(0, rng.int(2, 3));
  mechs.forEach((m, i) => applyMech(feat, m, w * h, 5, i === 0));
  const level = generateLevel({
    id: cacheKey, seed, w, h, density: 0.86, minLen: 2, maxLen: 6, turn: 0.35, feat,
  });
  level.id = cacheKey;
  level.chapter = -1;
  level.name = 'Daily Weave';
  cache.set(cacheKey, level);
  return level;
}
