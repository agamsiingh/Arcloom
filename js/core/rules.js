// Pure game rules: lane tracing, move resolution, world ticks and chain reactions.
import {
  DX, DY, KIND, T_WALL, T_PORTAL, T_GATE, T_CWALL,
  cloneState, occupancy, remaining,
} from './model.js';

/**
 * Cast a lane from (x, y) heading `d`. Returns the visited points; a point with
 * `j = true` was reached by teleporting through a portal pair.
 * ok=true means the lane exits the board.
 */
export function castRay(S, occ, x, y, d, color, self, ghost) {
  const pts = [[x, y, false]];
  const seen = new Set();
  let guard = 0;
  for (;;) {
    const nx = x + DX[d];
    const ny = y + DY[d];
    if (nx < 0 || ny < 0 || nx >= S.w || ny >= S.h) return { ok: true, pts, exitDir: d };
    const c = ny * S.w + nx;
    const t = S.type[c];
    if (t === T_WALL) return { ok: false, pts, hit: [nx, ny] };
    if (t === T_GATE && S.gdir[c] !== d) return { ok: false, pts, hit: [nx, ny] };
    if (t === T_CWALL && S.ccol[c] === color) return { ok: false, pts, hit: [nx, ny] };
    const o = occ ? occ[c] : -1;
    if (o === -2) return { ok: false, pts, hit: [nx, ny] };
    if (o >= 0 && (o === self || !ghost)) return { ok: false, pts, hit: [nx, ny] };
    pts.push([nx, ny, false]);
    if (t === T_PORTAL) {
      const key = c * 4 + d;
      if (seen.has(key)) return { ok: false, pts, hit: [nx, ny] };
      seen.add(key);
      const p = S.partner[c];
      x = p % S.w;
      y = (p - x) / S.w;
      pts.push([x, y, true]);
    } else {
      x = nx;
      y = ny;
    }
    if (++guard > 4000) return { ok: false, pts, hit: [nx, ny] };
  }
}

export function traceArrow(level, S, st, occ, i) {
  const a = level.arrows[i];
  const [hx, hy] = a.cells[a.cells.length - 1];
  return castRay(S, occ, hx, hy, st.dirs[i], st.color, i, a.kind === KIND.GHOST);
}

export function isLocked(level, st, i) {
  return level.arrows[i].lock > st.cleared;
}

export function legalMoves(level, S, st, occ = occupancy(level, st)) {
  const out = [];
  for (let i = 0; i < level.arrows.length; i++) {
    if (!st.alive[i] || isLocked(level, st, i)) continue;
    if (traceArrow(level, S, st, occ, i).ok) out.push(i);
  }
  return out;
}

function clearArrow(level, st, i, events, trace, chain) {
  const before = st.cleared;
  st.alive[i] = 0;
  st.cleared++;
  events.push({ type: 'clear', i, trace, dir: st.dirs[i], chain });
  if (level.arrows[i].kind === KIND.SWITCH) {
    st.color ^= 1;
    events.push({ type: 'switch', color: st.color });
  }
  for (let j = 0; j < level.arrows.length; j++) {
    const l = level.arrows[j].lock;
    if (st.alive[j] && l > before && l <= st.cleared) events.push({ type: 'unlock', i: j });
  }
}

function tick(level, st, events) {
  for (let j = 0; j < level.arrows.length; j++) {
    if (st.alive[j] && level.arrows[j].kind === KIND.ROTATOR) {
      st.dirs[j] = (st.dirs[j] + 1) % 4;
      events.push({ type: 'rotate', i: j, dir: st.dirs[j] });
    }
  }
  for (let b = 0; b < level.blockers.length; b++) {
    const len = level.blockers[b].track.length;
    if (len < 2) continue;
    let next = st.bIdx[b] + st.bStep[b];
    if (next < 0 || next >= len) {
      st.bStep[b] = -st.bStep[b];
      next = st.bIdx[b] + st.bStep[b];
    }
    st.bIdx[b] = next;
    events.push({ type: 'drift', b, idx: next });
  }
}

/** Launch every spark arrow whose lane is open, repeatedly, until the board settles. */
function resolveChains(level, S, st, events) {
  let depth = 0;
  for (;;) {
    let fired = false;
    const occ = occupancy(level, st);
    for (let j = 0; j < level.arrows.length; j++) {
      if (!st.alive[j] || level.arrows[j].kind !== KIND.SPARK || isLocked(level, st, j)) continue;
      const tr = traceArrow(level, S, st, occ, j);
      if (tr.ok) {
        depth++;
        clearArrow(level, st, j, events, tr, depth);
        fired = true;
        break;
      }
    }
    if (!fired) return depth;
  }
}

/**
 * Attempt to launch arrow i.
 * result: 'invalid' | 'locked' | 'blocked' | 'cleared'
 */
export function applyMove(level, S, st, i) {
  if (!st.alive[i]) return { result: 'invalid', st, events: [] };
  if (isLocked(level, st, i)) return { result: 'locked', st, events: [] };
  const occ = occupancy(level, st);
  const tr = traceArrow(level, S, st, occ, i);
  if (!tr.ok) return { result: 'blocked', st, events: [], trace: tr };
  const ns = cloneState(st);
  const events = [];
  clearArrow(level, ns, i, events, tr, 0);
  tick(level, ns, events);
  const chain = resolveChains(level, S, ns, events);
  return { result: 'cleared', st: ns, events, trace: tr, chain };
}

export function isSolved(st) {
  return remaining(st) === 0;
}

export function isStuck(level, S, st) {
  return remaining(st) > 0 && legalMoves(level, S, st).length === 0;
}
