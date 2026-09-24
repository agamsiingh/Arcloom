// Compact string encoding for levels (used by the baked campaign data).
import { DX, DY, KIND, normalizeLevel } from './model.js';

const DCH = 'URDL';
const K2C = { [KIND.NORMAL]: 'n', [KIND.ROTATOR]: 'r', [KIND.SPARK]: 's', [KIND.SWITCH]: 'w', [KIND.GHOST]: 'g' };
const C2K = Object.fromEntries(Object.entries(K2C).map(([k, c]) => [c, k]));

function moveChar(a, b) {
  for (let d = 0; d < 4; d++) if (a[0] + DX[d] === b[0] && a[1] + DY[d] === b[1]) return DCH[d];
  throw new Error('non-adjacent arrow cells');
}

export function encodeLevel(level) {
  const arrows = level.arrows.map((a) => {
    let path = '';
    for (let i = 1; i < a.cells.length; i++) path += moveChar(a.cells[i - 1], a.cells[i]);
    const [x, y] = a.cells[0];
    return `${x},${y},${path},${DCH[a.dir]},${K2C[a.kind]},${a.lock}`;
  }).join(';');
  const pts = (list) => list.map(([x, y]) => `${x},${y}`).join(';');
  return [
    `${level.w},${level.h}`,
    arrows,
    pts(level.walls),
    level.portals.map(([a, b]) => `${a[0]},${a[1]},${b[0]},${b[1]}`).join(';'),
    level.gates.map((g) => `${g.x},${g.y},${g.dir}`).join(';'),
    level.cwalls.map((c) => `${c.x},${c.y},${c.c}`).join(';'),
    level.blockers.map((b) => b.track.map(([x, y]) => `${x},${y}`).join(',')).join(';'),
  ].join('|');
}

export function decodeLevel(str, id) {
  const [size, arrows, walls, portals, gates, cwalls, blockers] = str.split('|');
  const list = (s) => (s ? s.split(';').map((p) => p.split(',')) : []);
  const [w, h] = size.split(',').map(Number);
  return normalizeLevel({
    id, w, h,
    arrows: list(arrows).map(([x, y, p, d, k, lock]) => ({
      at: [+x, +y], p, d, kind: C2K[k], lock: +lock,
    })),
    walls: list(walls).map(([x, y]) => [+x, +y]),
    portals: list(portals).map(([ax, ay, bx, by]) => [[+ax, +ay], [+bx, +by]]),
    gates: list(gates).map(([x, y, dir]) => ({ x: +x, y: +y, dir: +dir })),
    cwalls: list(cwalls).map(([x, y, c]) => ({ x: +x, y: +y, c: +c })),
    blockers: list(blockers).map((nums) => {
      const track = [];
      for (let i = 0; i < nums.length; i += 2) track.push([+nums[i], +nums[i + 1]]);
      return { track };
    }),
  });
}
