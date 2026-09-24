// Level data model, static board lookup tables and mutable play state.

export const DX = [0, 1, 0, -1];
export const DY = [-1, 0, 1, 0];
export const DIR_OF = { U: 0, R: 1, D: 2, L: 3 };

export const KIND = {
  NORMAL: 'normal',
  ROTATOR: 'rotator', // single-cell, turns clockwise after every player clear
  SPARK: 'spark', // launches itself the moment its lane opens (chain reactions)
  SWITCH: 'switch', // flips which colour barriers are raised
  GHOST: 'ghost', // phases through other arrows, still stopped by stone & barriers
};

// Static cell types
export const T_EMPTY = 0;
export const T_WALL = 1;
export const T_PORTAL = 2;
export const T_GATE = 3;
export const T_CWALL = 4;

/**
 * Normalise a level definition. Arrow cells are ordered tail -> head.
 * Accepts either explicit `cells` or the compact hand-authored form
 * `{ at: [x, y], p: 'UUR', d: 'U' }` (path of moves from the tail).
 */
export function normalizeLevel(def) {
  const arrows = def.arrows.map((a) => {
    let cells, dir;
    if (a.cells) {
      cells = a.cells.map((c) => [c[0], c[1]]);
      dir = a.dir;
    } else {
      cells = [[a.at[0], a.at[1]]];
      dir = a.d !== undefined ? DIR_OF[a.d] : 0;
      for (const ch of a.p || '') {
        const d = DIR_OF[ch];
        const last = cells[cells.length - 1];
        cells.push([last[0] + DX[d], last[1] + DY[d]]);
        dir = d;
      }
    }
    return { cells, dir, kind: a.kind || KIND.NORMAL, lock: a.lock || 0 };
  });
  return {
    id: def.id,
    name: def.name || '',
    tip: def.tip || null,
    w: def.w,
    h: def.h,
    arrows,
    walls: (def.walls || []).map((c) => [c[0], c[1]]),
    portals: (def.portals || []).map((p) => [[p[0][0], p[0][1]], [p[1][0], p[1][1]]]),
    gates: (def.gates || []).map((g) => ({ x: g.x, y: g.y, dir: typeof g.dir === 'string' ? DIR_OF[g.dir] : g.dir })),
    cwalls: (def.cwalls || []).map((c) => ({ x: c.x, y: c.y, c: c.c })),
    blockers: (def.blockers || []).map((b) => ({ track: b.track.map((c) => [c[0], c[1]]) })),
  };
}

/** Precomputed per-cell lookup tables for the immutable parts of a level. */
export function buildStatic(level) {
  const { w, h } = level;
  const n = w * h;
  const type = new Uint8Array(n);
  const partner = new Int16Array(n).fill(-1);
  const gdir = new Int8Array(n).fill(-1);
  const ccol = new Int8Array(n).fill(-1);
  for (const [x, y] of level.walls) type[y * w + x] = T_WALL;
  for (const [a, b] of level.portals) {
    const ia = a[1] * w + a[0];
    const ib = b[1] * w + b[0];
    type[ia] = T_PORTAL;
    type[ib] = T_PORTAL;
    partner[ia] = ib;
    partner[ib] = ia;
  }
  for (const g of level.gates) {
    type[g.y * w + g.x] = T_GATE;
    gdir[g.y * w + g.x] = g.dir;
  }
  for (const c of level.cwalls) {
    type[c.y * w + c.x] = T_CWALL;
    ccol[c.y * w + c.x] = c.c;
  }
  return { w, h, type, partner, gdir, ccol };
}

export function initialState(level) {
  const n = level.arrows.length;
  const nb = level.blockers.length;
  return {
    alive: new Uint8Array(n).fill(1),
    dirs: Int8Array.from(level.arrows.map((a) => a.dir)),
    color: 0,
    cleared: 0,
    bIdx: new Int8Array(nb),
    bStep: new Int8Array(nb).fill(1),
  };
}

export function cloneState(st) {
  return {
    alive: st.alive.slice(),
    dirs: st.dirs.slice(),
    color: st.color,
    cleared: st.cleared,
    bIdx: st.bIdx.slice(),
    bStep: st.bStep.slice(),
  };
}

export function remaining(st) {
  let r = 0;
  for (let i = 0; i < st.alive.length; i++) r += st.alive[i];
  return r;
}

export function blockerPos(level, st, b) {
  return level.blockers[b].track[st.bIdx[b]];
}

/** Cell -> occupant: arrow index, -2 for a drifting blocker, -1 empty. */
export function occupancy(level, st) {
  const { w, h } = level;
  const occ = new Int16Array(w * h).fill(-1);
  for (let i = 0; i < level.arrows.length; i++) {
    if (!st.alive[i]) continue;
    for (const [x, y] of level.arrows[i].cells) occ[y * w + x] = i;
  }
  for (let b = 0; b < level.blockers.length; b++) {
    const [x, y] = blockerPos(level, st, b);
    occ[y * w + x] = -2;
  }
  return occ;
}

export function stateKey(st) {
  let k = '';
  for (let i = 0; i < st.alive.length; i++) k += st.alive[i] ? '1' : '0';
  k += '|' + st.color;
  for (let i = 0; i < st.dirs.length; i++) k += st.dirs[i];
  for (let b = 0; b < st.bIdx.length; b++) k += ',' + st.bIdx[b] + (st.bStep[b] > 0 ? '+' : '-');
  return k;
}
