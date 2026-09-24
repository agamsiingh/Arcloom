// Canvas drawing primitives. Coordinates are in cell units: cell (x, y) is centred at (x, y).
import { DX, DY, KIND } from '../core/model.js';

export const LINE = 0.16;
const TIP = 0.36;
const HEAD_LEN = 0.36;
const HEAD_HALF = 0.23;

/**
 * Build an arrow's travel track: a virtual point behind the tail, body cells,
 * then the lane (`lane` points from castRay, head first) and a run-out beyond the edge.
 */
export function buildTrack(cells, dir, lane = null, runOut = 0) {
  const first = cells.length > 1
    ? [cells[1][0] - cells[0][0], cells[1][1] - cells[0][1]]
    : [DX[dir], DY[dir]];
  const T = [{ x: cells[0][0] - first[0], y: cells[0][1] - first[1], j: false }];
  for (const [x, y] of cells) T.push({ x, y, j: false });
  let last = T[T.length - 1];
  if (lane) {
    for (let k = 1; k < lane.length; k++) {
      T.push({ x: lane[k][0], y: lane[k][1], j: lane[k][2] });
    }
    last = T[T.length - 1];
  }
  const ext = Math.max(1, runOut);
  for (let k = 1; k <= ext; k++) T.push({ x: last.x + DX[dir] * k, y: last.y + DY[dir] * k, j: false });
  const s = [0];
  for (let k = 1; k < T.length; k++) s.push(s[k - 1] + (T[k].j ? 0 : 1));
  return { T, s, len: cells.length };
}

function pointAt(track, v) {
  const { T, s } = track;
  for (let k = 1; k < T.length; k++) {
    if (T[k].j) continue;
    if (v <= s[k] || k === T.length - 1) {
      const f = Math.max(0, Math.min(1, v - s[k - 1]));
      return {
        x: T[k - 1].x + (T[k].x - T[k - 1].x) * f,
        y: T[k - 1].y + (T[k].y - T[k - 1].y) * f,
        dx: T[k].x - T[k - 1].x,
        dy: T[k].y - T[k - 1].y,
      };
    }
  }
  const e = T[T.length - 1];
  return { x: e.x, y: e.y, dx: 0, dy: -1 };
}

/** Polylines covering arc-length window [a, b], split at portal jumps. */
function sample(track, a, b) {
  const { T, s } = track;
  const lines = [];
  let cur = null;
  for (let k = 1; k < T.length; k++) {
    if (T[k].j) {
      if (cur) lines.push(cur);
      cur = null;
      continue;
    }
    const s0 = s[k - 1];
    const s1 = s[k];
    const lo = Math.max(a, s0);
    const hi = Math.min(b, s1);
    if (hi < lo) {
      if (s0 > b) break;
      continue;
    }
    const lerp = (v) => [T[k - 1].x + (T[k].x - T[k - 1].x) * (v - s0), T[k - 1].y + (T[k].y - T[k - 1].y) * (v - s0)];
    if (!cur) cur = [lerp(lo)];
    cur.push(lerp(hi));
  }
  if (cur) lines.push(cur);
  return lines;
}

function strokeLines(ctx, lines) {
  ctx.beginPath();
  for (const l of lines) {
    ctx.moveTo(l[0][0], l[0][1]);
    for (let k = 1; k < l.length; k++) ctx.lineTo(l[k][0], l[k][1]);
  }
  ctx.stroke();
}

function arrowHead(ctx, x, y, dx, dy) {
  const len = Math.hypot(dx, dy) || 1;
  const ux = dx / len;
  const uy = dy / len;
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x - ux * HEAD_LEN - uy * HEAD_HALF, y - uy * HEAD_LEN + ux * HEAD_HALF);
  ctx.lineTo(x - ux * HEAD_LEN + uy * HEAD_HALF, y - uy * HEAD_LEN - ux * HEAD_HALF);
  ctx.closePath();
  ctx.fill();
}

/** Draw an arrow along its track, shifted `off` cells forward. */
export function drawTrackArrow(ctx, track, off, color, { width = LINE, dash = null, glow = null } = {}) {
  const a = 1 - 0.22 + off;
  const b = track.len + TIP + off;
  const lines = sample(track, a, b - HEAD_LEN * 0.7);
  const tip = pointAt(track, b);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  if (glow) {
    ctx.strokeStyle = glow;
    ctx.fillStyle = glow;
    ctx.lineWidth = width + 0.22;
    strokeLines(ctx, lines);
    arrowHead(ctx, tip.x + tip.dx * 0.08, tip.y + tip.dy * 0.08, tip.dx, tip.dy);
  }
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = width;
  if (dash) ctx.setLineDash(dash);
  strokeLines(ctx, lines);
  ctx.setLineDash([]);
  arrowHead(ctx, tip.x, tip.y, tip.dx, tip.dy);
  return tip;
}

export function drawRotator(ctx, x, y, angle, color, ring, glow) {
  const ux = Math.sin(angle);
  const uy = -Math.cos(angle);
  ctx.lineCap = 'round';
  ctx.strokeStyle = ring;
  ctx.lineWidth = 0.06;
  ctx.beginPath();
  ctx.arc(x, y, 0.4, -Math.PI * 0.35, Math.PI * 1.2);
  ctx.stroke();
  // Tiny clockwise marker at the ring's end.
  const e = Math.PI * 1.2;
  const ex = x + Math.cos(e) * 0.4;
  const ey = y + Math.sin(e) * 0.4;
  ctx.fillStyle = ring;
  ctx.beginPath();
  ctx.moveTo(ex + 0.1, ey - 0.02);
  ctx.lineTo(ex - 0.06, ey + 0.1);
  ctx.lineTo(ex - 0.07, ey - 0.08);
  ctx.fill();
  if (glow) {
    ctx.strokeStyle = glow;
    ctx.lineWidth = LINE + 0.22;
    ctx.beginPath();
    ctx.moveTo(x - ux * 0.26, y - uy * 0.26);
    ctx.lineTo(x + ux * 0.1, y + uy * 0.1);
    ctx.stroke();
  }
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = LINE;
  ctx.beginPath();
  ctx.moveTo(x - ux * 0.26, y - uy * 0.26);
  ctx.lineTo(x + ux * 0.06, y + uy * 0.06);
  ctx.stroke();
  arrowHead(ctx, x + ux * 0.34, y + uy * 0.34, ux, uy);
}

export function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export function drawWall(ctx, x, y, c) {
  ctx.fillStyle = c.stone;
  roundRect(ctx, x - 0.4, y - 0.4, 0.8, 0.8, 0.16);
  ctx.fill();
  ctx.fillStyle = c.stoneHi;
  roundRect(ctx, x - 0.4, y - 0.4, 0.8, 0.3, 0.14);
  ctx.fill();
}

export function drawGate(ctx, x, y, dir, c) {
  ctx.strokeStyle = c.gateFrame;
  ctx.lineWidth = 0.05;
  roundRect(ctx, x - 0.42, y - 0.42, 0.84, 0.84, 0.14);
  ctx.stroke();
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(dir * Math.PI / 2);
  ctx.strokeStyle = c.gate;
  ctx.lineWidth = 0.09;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  for (const oy of [0.14, -0.12]) {
    ctx.beginPath();
    ctx.moveTo(-0.22, oy + 0.12);
    ctx.lineTo(0, oy - 0.1);
    ctx.lineTo(0.22, oy + 0.12);
    ctx.stroke();
  }
  ctx.restore();
}

export function drawColorWall(ctx, x, y, colorIdx, raised, k, c) {
  const col = colorIdx === 0 ? c.c0 : c.c1;
  const r = 0.28 + 0.14 * k; // k: 0 lowered .. 1 raised
  if (raised || k > 0.02) {
    ctx.globalAlpha = 0.35 + 0.65 * k;
    ctx.fillStyle = col;
    roundRect(ctx, x - r, y - r, r * 2, r * 2, 0.1);
    ctx.fill();
    ctx.globalAlpha = 1;
    // Pattern glyph for colour-blind players: stripes (A) or dots (B).
    ctx.strokeStyle = c.onColor;
    ctx.fillStyle = c.onColor;
    ctx.lineWidth = 0.05;
    if (colorIdx === 0) {
      ctx.beginPath();
      for (const o of [-0.16, 0, 0.16]) {
        ctx.moveTo(x + o - 0.1 * k, y + 0.12 * k);
        ctx.lineTo(x + o + 0.1 * k, y - 0.12 * k);
      }
      ctx.stroke();
    } else {
      for (const [ox, oy] of [[-0.12, -0.12], [0.12, -0.12], [-0.12, 0.12], [0.12, 0.12]]) {
        ctx.beginPath();
        ctx.arc(x + ox * k, y + oy * k, 0.04, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
  if (k < 0.98) {
    ctx.strokeStyle = col;
    ctx.lineWidth = 0.05;
    ctx.setLineDash([0.08, 0.07]);
    roundRect(ctx, x - 0.3, y - 0.3, 0.6, 0.6, 0.1);
    ctx.stroke();
    ctx.setLineDash([]);
  }
}

export function drawPortal(ctx, x, y, col, label, t, textColor) {
  ctx.strokeStyle = col;
  ctx.lineWidth = 0.07;
  ctx.beginPath();
  ctx.arc(x, y, 0.38, 0, Math.PI * 2);
  ctx.stroke();
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(t);
  ctx.setLineDash([0.12, 0.1]);
  ctx.lineWidth = 0.05;
  ctx.beginPath();
  ctx.arc(0, 0, 0.26, 0, Math.PI * 2);
  ctx.stroke();
  ctx.restore();
  ctx.setLineDash([]);
  ctx.fillStyle = col;
  ctx.globalAlpha = 0.18;
  ctx.beginPath();
  ctx.arc(x, y, 0.38, 0, Math.PI * 2);
  ctx.fill();
  ctx.globalAlpha = 1;
  drawText(ctx, label, x, y + 0.01, 0.26, textColor, 700);
}

export function drawText(ctx, text, x, y, size, color, weight = 600) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(size / 20, size / 20);
  ctx.fillStyle = color;
  ctx.font = `${weight} 20px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, 0, 0);
  ctx.restore();
}

export function drawBlocker(ctx, x, y, c, t) {
  const s = 0.34 + Math.sin(t * 3) * 0.015;
  ctx.fillStyle = c.drift;
  ctx.beginPath();
  for (let k = 0; k < 6; k++) {
    const a = Math.PI / 6 + (k * Math.PI) / 3;
    const px = x + Math.cos(a) * s;
    const py = y + Math.sin(a) * s;
    if (k === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = c.onColor;
  ctx.beginPath();
  ctx.arc(x - 0.09, y - 0.03, 0.05, 0, Math.PI * 2);
  ctx.arc(x + 0.09, y - 0.03, 0.05, 0, Math.PI * 2);
  ctx.fill();
}

export function drawTrackLine(ctx, track, c) {
  ctx.strokeStyle = c.driftTrack;
  ctx.lineWidth = 0.08;
  ctx.lineCap = 'round';
  ctx.setLineDash([0.02, 0.18]);
  ctx.beginPath();
  track.forEach(([x, y], k) => (k ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
  ctx.stroke();
  ctx.setLineDash([]);
  for (const k of [0, track.length - 1]) {
    ctx.beginPath();
    ctx.arc(track[k][0], track[k][1], 0.08, 0, Math.PI * 2);
    ctx.fillStyle = c.driftTrack;
    ctx.fill();
  }
}

export function drawLock(ctx, x, y, count, c, k = 1) {
  k *= 1.4;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(k, k);
  ctx.strokeStyle = c.lock;
  ctx.lineWidth = 0.06;
  ctx.beginPath();
  ctx.arc(0, -0.1, 0.12, Math.PI, 0);
  ctx.stroke();
  ctx.fillStyle = c.lock;
  roundRect(ctx, -0.2, -0.1, 0.4, 0.3, 0.06);
  ctx.fill();
  ctx.restore();
  drawText(ctx, String(count), x, y + 0.05 * k, 0.21 * k, c.onColor, 800);
}

export function kindBadge(ctx, kind, x, y, c) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(1.35, 1.35);
  ctx.translate(-x, -y);
  if (kind === KIND.SPARK) {
    ctx.fillStyle = c.spark;
    ctx.beginPath();
    ctx.moveTo(x + 0.05, y - 0.22);
    ctx.lineTo(x - 0.12, y + 0.03);
    ctx.lineTo(x, y + 0.03);
    ctx.lineTo(x - 0.05, y + 0.22);
    ctx.lineTo(x + 0.12, y - 0.03);
    ctx.lineTo(x, y - 0.03);
    ctx.closePath();
    ctx.fill();
  } else if (kind === KIND.SWITCH) {
    ctx.fillStyle = c.c0;
    ctx.beginPath();
    ctx.arc(x, y, 0.17, Math.PI / 2, Math.PI * 1.5);
    ctx.fill();
    ctx.fillStyle = c.c1;
    ctx.beginPath();
    ctx.arc(x, y, 0.17, -Math.PI / 2, Math.PI / 2);
    ctx.fill();
  }
  ctx.restore();
}

// ---- geometry helpers ---------------------------------------------------------------
export function distToPath(u, v, cells, dir) {
  const pts = cells.map(([x, y]) => [x, y]);
  const [hx, hy] = cells[cells.length - 1];
  pts.push([hx + DX[dir] * 0.36, hy + DY[dir] * 0.36]);
  if (cells.length === 1) pts.unshift([hx - DX[dir] * 0.3, hy - DY[dir] * 0.3]);
  let best = Infinity;
  for (let k = 1; k < pts.length; k++) best = Math.min(best, distSeg(u, v, pts[k - 1], pts[k]));
  return best;
}

function distSeg(px, py, [ax, ay], [bx, by]) {
  const dx = bx - ax;
  const dy = by - ay;
  const L = dx * dx + dy * dy;
  const t = L ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / L)) : 0;
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

export function withAlpha(color, a) {
  if (color.startsWith('#') && color.length === 7) {
    const n = parseInt(color.slice(1), 16);
    return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
  }
  return color;
}
