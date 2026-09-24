// Procedural level generator.
// Arrows are placed in *reverse* solution order: each new arrow must have an open
// lane given everything already placed, so the static puzzle is solvable by
// construction. Dynamic mechanics (rotators, drifters, colour switches) are then
// verified with the solver and the seed is re-rolled when needed.
import { Rng } from './rng.js';
import { DX, DY, KIND, T_EMPTY, buildStatic, initialState } from './model.js';
import { castRay, legalMoves } from './rules.js';
import { solve } from './solver.js';

const DEFAULT_FEAT = {
  walls: 0, portals: 0, gates: 0, cwalls: 0, blockers: 0,
  rotators: 0, locks: 0, sparks: 0, switches: 0, ghosts: 0,
};

export function generateLevel(opts) {
  const feat = { ...DEFAULT_FEAT, ...opts.feat };
  const tries = [
    { feat, n: 10 },
    { feat: { ...feat, rotators: Math.min(feat.rotators, 2), blockers: Math.min(feat.blockers, 1) }, n: 10 },
    { feat: { ...feat, rotators: 0, blockers: 0, switches: 0 }, n: 30 },
  ];
  let salt = 0;
  for (const t of tries) {
    for (let k = 0; k < t.n; k++) {
      const rng = new Rng((opts.seed + salt++ * 7919) >>> 0);
      const lvl = buildOnce(rng, { ...opts, feat: t.feat });
      if (lvl && verify(lvl)) return lvl;
    }
  }
  throw new Error(`Generator failed for seed ${opts.seed}`);
}

function verify(level) {
  if (level.arrows.length < 2) return false;
  const S = buildStatic(level);
  const st = initialState(level);
  const hasDynamic = level.blockers.length || level.arrows.some((a) => a.kind === KIND.ROTATOR || a.kind === KIND.SWITCH);
  const r = solve(level, S, st, { maxNodes: hasDynamic ? 2500 : 2000 });
  return r.solved;
}

function buildOnce(rng, opts) {
  const { w, h, density = 0.85, minLen = 2, maxLen = 4, turn = 0.3 } = opts;
  const feat = opts.feat;
  const N = w * h;
  const reserved = new Uint8Array(N);
  const trackCell = new Uint8Array(N);
  const level = {
    id: opts.id, name: opts.name || '', tip: null, w, h,
    arrows: [], walls: [], portals: [], gates: [], cwalls: [], blockers: [],
  };

  const inner = (margin) => {
    for (let t = 0; t < 120; t++) {
      const x = rng.int(margin, w - 1 - margin);
      const y = rng.int(margin, h - 1 - margin);
      if (!reserved[y * w + x]) return [x, y];
    }
    return null;
  };
  const reserve = ([x, y]) => { reserved[y * w + x] = 1; };

  for (let i = 0; i < feat.walls; i++) {
    const c = inner(1);
    if (c) { reserve(c); level.walls.push(c); }
  }
  for (let i = 0; i < feat.portals; i++) {
    const a = inner(1);
    if (!a) break;
    reserve(a);
    let b = null;
    for (let t = 0; t < 60 && !b; t++) {
      const c = inner(1);
      if (c && Math.abs(c[0] - a[0]) + Math.abs(c[1] - a[1]) >= 3 && c[0] !== a[0] && c[1] !== a[1]) b = c;
    }
    if (!b) { reserved[a[1] * w + a[0]] = 0; break; }
    reserve(b);
    level.portals.push([a, b]);
  }
  for (let i = 0; i < feat.gates; i++) {
    const c = inner(1);
    if (c) { reserve(c); level.gates.push({ x: c[0], y: c[1], dir: rng.int(0, 3) }); }
  }
  for (let i = 0; i < feat.cwalls; ) {
    const c = inner(1);
    if (!c) break;
    const color = rng.int(0, 1);
    const d = rng.int(0, 3);
    const len = rng.int(1, 3);
    for (let k = 0; k < len && i < feat.cwalls; k++) {
      const x = c[0] + DX[d] * k;
      const y = c[1] + DY[d] * k;
      if (x < 0 || y < 0 || x >= w || y >= h || reserved[y * w + x]) break;
      reserve([x, y]);
      level.cwalls.push({ x, y, c: color });
      i++;
    }
  }
  for (let i = 0; i < feat.blockers; i++) {
    for (let t = 0; t < 40; t++) {
      const len = rng.int(3, 4);
      const d = rng.int(1, 2); // right or down
      const x0 = rng.int(0, w - 1 - (d === 1 ? len - 1 : 0));
      const y0 = rng.int(0, h - 1 - (d === 2 ? len - 1 : 0));
      const track = [];
      for (let k = 0; k < len; k++) track.push([x0 + DX[d] * k, y0 + DY[d] * k]);
      if (track.some(([x, y]) => reserved[y * w + x])) continue;
      track.forEach((c) => { reserve(c); trackCell[c[1] * w + c[0]] = 1; });
      level.blockers.push({ track });
      break;
    }
  }

  const S = buildStatic(level);
  const occ = new Int16Array(N).fill(-1);
  const isSpecialCell = (x, y) => {
    const c = y * w + x;
    return S.type[c] !== T_EMPTY || trackCell[c];
  };

  let freeCount = 0;
  for (let c = 0; c < N; c++) if (!reserved[c]) freeCount++;
  const targetFill = Math.floor(freeCount * density);
  let filled = 0;
  let fails = 0;
  let rotators = 0;
  const hasFeatureCells = level.portals.length || level.gates.length || level.cwalls.length || level.blockers.length;

  while (filled < targetFill && fails < 500) {
    const empties = [];
    for (let c = 0; c < N; c++) if (!reserved[c] && occ[c] === -1) empties.push(c);
    if (!empties.length) break;
    const hc = rng.pick(empties);
    const hx = hc % w;
    const hy = (hc - hx) / w;
    const makeRot = rotators < feat.rotators && rng.chance(0.3);
    const options = [];
    for (const d of rng.shuffle([0, 1, 2, 3])) {
      const ray = castRay(S, occ, hx, hy, d, 0, -1, false);
      if (!ray.ok) continue;
      const featured = ray.pts.some(([x, y]) => isSpecialCell(x, y));
      options.push({ d, ray, featured });
    }
    if (!options.length) { fails++; continue; }
    let pickOrder = options;
    if (hasFeatureCells && rng.chance(0.75)) {
      pickOrder = options.filter((o) => o.featured).concat(options.filter((o) => !o.featured));
    }
    let placed = false;
    for (const { d, ray } of pickOrder) {
      const raySet = new Set(ray.pts.slice(1).map(([x, y]) => y * w + x));
      let cells;
      if (makeRot) {
        cells = [[hx, hy]];
      } else {
        cells = growBody(rng, w, h, hx, hy, d, rng.int(minLen, maxLen), turn, occ, reserved, raySet);
        if (cells.length < Math.max(2, Math.min(minLen, 3))) continue;
      }
      const idx = level.arrows.length;
      for (const [x, y] of cells) occ[y * w + x] = idx;
      level.arrows.push({ cells, dir: d, kind: makeRot ? KIND.ROTATOR : KIND.NORMAL, lock: 0 });
      filled += cells.length;
      if (makeRot) rotators++;
      placed = true;
      break;
    }
    if (!placed) fails++;
  }

  assignSpecials(rng, level, feat);
  const order = rng.shuffle(level.arrows.map((_, i) => i));
  level.arrows = order.map((i) => level.arrows[i]);

  // Spark arrows must not launch before the player's first move.
  const S2 = buildStatic(level);
  const st = initialState(level);
  for (const i of legalMoves(level, S2, st)) {
    if (level.arrows[i].kind === KIND.SPARK) level.arrows[i].kind = KIND.NORMAL;
  }
  return level;
}

function growBody(rng, w, h, hx, hy, d, len, turn, occ, reserved, raySet) {
  const body = [[hx, hy]];
  const used = new Set([hy * w + hx]);
  let seg = d;
  let cx = hx;
  let cy = hy;
  while (body.length < len) {
    const sides = rng.shuffle([(seg + 1) % 4, (seg + 3) % 4]);
    const opts = body.length === 1 ? [seg] : rng.chance(turn) ? [...sides, seg] : [seg, ...sides];
    let moved = false;
    for (const s of opts) {
      const px = cx - DX[s];
      const py = cy - DY[s];
      if (px < 0 || py < 0 || px >= w || py >= h) continue;
      const c = py * w + px;
      if (reserved[c] || occ[c] !== -1 || used.has(c) || raySet.has(c)) continue;
      body.push([px, py]);
      used.add(c);
      seg = s;
      cx = px;
      cy = py;
      moved = true;
      break;
    }
    if (!moved) break;
  }
  return body.reverse();
}

function assignSpecials(rng, level, feat) {
  const n = level.arrows.length;
  // Placement index p is cleared at solution position n-1-p.
  const pool = rng.shuffle(
    level.arrows.map((a, p) => ({ a, sol: n - 1 - p })).filter((o) => o.a.kind === KIND.NORMAL),
  );
  const take = (count, pred, fn) => {
    let k = 0;
    for (const o of pool) {
      if (k >= count) break;
      if (o.used || !pred(o)) continue;
      o.used = true;
      fn(o);
      k++;
    }
  };
  take(feat.locks, (o) => o.sol >= 2, (o) => { o.a.lock = rng.int(1, Math.min(o.sol, 9)); });
  take(feat.sparks, (o) => o.sol >= 1, (o) => { o.a.kind = KIND.SPARK; });
  take(feat.ghosts, () => true, (o) => { o.a.kind = KIND.GHOST; });
  if (level.cwalls.length) take(Math.max(1, feat.switches), () => true, (o) => { o.a.kind = KIND.SWITCH; });
}
