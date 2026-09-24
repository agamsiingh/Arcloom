// Board view: layout, zoom/pan transform, precise hit-testing, animation + particles.
import { DX, DY, KIND, occupancy } from '../core/model.js';
import { castRay } from '../core/rules.js';
import {
  buildTrack, drawTrackArrow, drawRotator, drawWall, drawGate, drawColorWall, drawPortal,
  drawBlocker, drawTrackLine, drawLock, drawText, kindBadge, roundRect, distToPath, withAlpha,
} from './draw.js';

const PORTAL_KEYS = ['portal1', 'portal2', 'portal3', 'portal4'];
const THEME_KEYS = [
  'ink', 'board', 'peg', 'warp', 'accent', 'danger', 'stone', 'stoneHi', 'gate', 'gateFrame', 'c0', 'c1',
  'onColor', 'spark', 'ghost', 'rot', 'rotRing', 'lock', 'drift', 'driftTrack', 'hint', 'bg', ...PORTAL_KEYS,
];
const cssName = (k) => '--' + k.replace(/[A-Z]/g, (m) => '-' + m.toLowerCase()).replace(/(\d)/, '-$1');

const easeOut = (p) => 1 - (1 - p) * (1 - p);
const easeInOut = (p) => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2);

export class BoardView {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.scale = 1;
    this.tx = 0;
    this.ty = 0;
    this.c = {};
    this.reducedMotion = false;
    this.readTheme();
  }

  readTheme() {
    const cs = getComputedStyle(document.documentElement);
    for (const k of THEME_KEYS) this.c[k] = cs.getPropertyValue(cssName(k)).trim() || '#888';
  }

  setLevel(level, session) {
    this.level = level;
    this.session = session;
    this.tracks = level.arrows.map((a) => buildTrack(a.cells, a.dir));
    this.resetFx();
    this.resetZoom();
    this.layout();
    this.born = performance.now();
  }

  resetFx() {
    const st = this.session.st;
    this.slides = [];
    this.bumps = [];
    this.flashes = [];
    this.particles = [];
    this.texts = [];
    this.unlocks = [];
    this.hint = -1;
    this.selected = -1;
    this.rotShown = Array.from(st.dirs, (d) => (d * Math.PI) / 2);
    this.rotTarget = this.rotShown.slice();
    this.blkShown = this.level.blockers.map((b, k) => [...b.track[st.bIdx[k]]]);
    this.cwK = [st.color === 0 ? 1 : 0, st.color === 1 ? 1 : 0];
  }

  /** Snap displayed state to the session (after undo / continue). */
  syncToState() {
    const { slides, particles, texts } = this;
    this.resetFx();
    this.slides = slides;
    this.particles = particles;
    this.texts = texts;
  }

  resize() {
    const r = this.canvas.getBoundingClientRect();
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.cssW = Math.max(1, r.width);
    this.cssH = Math.max(1, r.height);
    this.canvas.width = Math.round(this.cssW * this.dpr);
    this.canvas.height = Math.round(this.cssH * this.dpr);
    if (this.level) this.layout();
  }

  layout() {
    const { w, h } = this.level;
    const margin = 18;
    this.cell = Math.min((this.cssW - margin * 2) / (w + 0.6), (this.cssH - margin * 2) / (h + 0.6), 64);
    this.ox = (this.cssW - w * this.cell) / 2;
    this.oy = (this.cssH - h * this.cell) / 2;
    this.clampPan();
  }

  // ---- coordinates & zoom ------------------------------------------------------------
  toUnits(px, py) {
    const bx = (px - this.tx) / this.scale;
    const by = (py - this.ty) / this.scale;
    return { u: (bx - this.ox) / this.cell - 0.5, v: (by - this.oy) / this.cell - 0.5 };
  }

  maxScale() {
    return Math.max(1, Math.min(3.5, 64 / this.cell));
  }

  canZoom() {
    return this.maxScale() > 1.05;
  }

  zoomAt(px, py, factor) {
    const next = Math.max(1, Math.min(this.maxScale(), this.scale * factor));
    const f = next / this.scale;
    this.tx = px - (px - this.tx) * f;
    this.ty = py - (py - this.ty) * f;
    this.scale = next;
    this.clampPan();
  }

  pan(dx, dy) {
    this.tx += dx;
    this.ty += dy;
    this.clampPan();
  }

  clampPan() {
    if (!this.cssW) return;
    if (this.scale <= 1.001) {
      this.scale = 1;
      this.tx = 0;
      this.ty = 0;
      return;
    }
    const minX = this.cssW - this.cssW * this.scale;
    const minY = this.cssH - this.cssH * this.scale;
    this.tx = Math.min(0, Math.max(minX, this.tx));
    this.ty = Math.min(0, Math.max(minY, this.ty));
  }

  resetZoom() {
    this.scale = 1;
    this.tx = 0;
    this.ty = 0;
  }

  // ---- hit testing -------------------------------------------------------------------
  /**
   * Nearest arrow to a screen point. Taps inside an arrow's own cell get priority;
   * a tap that is nearly equidistant from two arrows is flagged `ambiguous` so the
   * caller can ask for confirmation instead of guessing.
   */
  hitTest(px, py, { large = false } = {}) {
    const { u, v } = this.toUnits(px, py);
    const st = this.session.st;
    const screenCell = this.cell * this.scale;
    const R = Math.min(0.95, Math.max(large ? 0.78 : 0.62, 20 / screenCell));
    const cx = Math.round(u);
    const cy = Math.round(v);
    let best = null;
    let second = null;
    this.level.arrows.forEach((a, i) => {
      if (!st.alive[i]) return;
      let d;
      if (a.kind === KIND.ROTATOR) {
        d = Math.max(0, Math.hypot(u - a.cells[0][0], v - a.cells[0][1]) - 0.3);
      } else {
        d = distToPath(u, v, a.cells, st.dirs[i]);
      }
      if (a.cells.some(([x, y]) => x === cx && y === cy)) d = Math.max(0, d - 0.25);
      if (d > R) return;
      if (!best || d < best.d) {
        second = best;
        best = { i, d };
      } else if (!second || d < second.d) {
        second = { i, d };
      }
    });
    if (!best) return null;
    const ambiguous = !!second && second.d - best.d < 0.2;
    return { i: best.i, alt: ambiguous ? second.i : -1, ambiguous };
  }

  // ---- effects -----------------------------------------------------------------------
  now() {
    return performance.now();
  }

  addSlide(i, trace, dir) {
    const a = this.level.arrows[i];
    let laneLen = 0;
    for (let k = 1; k < trace.pts.length; k++) if (!trace.pts[k][2]) laneLen++;
    const track = buildTrack(a.cells, dir, trace.pts, a.cells.length + 3);
    const dist = laneLen + a.cells.length + 1.5;
    const dur = this.reducedMotion ? 160 : Math.min(620, 200 + dist * 26);
    const exit = trace.pts[trace.pts.length - 1];
    this.slides.push({ i, track, dist, laneLen, dur, t0: this.now(), exit, dir, burst: false });
    this.tracks[i] = buildTrack(a.cells, dir);
  }

  addBump(i, trace, dir) {
    const a = this.level.arrows[i];
    let laneLen = 0;
    for (let k = 1; k < trace.pts.length; k++) if (!trace.pts[k][2]) laneLen++;
    const track = buildTrack(a.cells, dir, trace.pts, 1);
    this.bumps.push({ i, track, dist: laneLen, t0: this.now(), dur: 360, hit: trace.hit });
    this.flashes.push({ i, t0: this.now() });
  }

  shake(i) {
    this.flashes.push({ i, t0: this.now(), soft: true });
  }

  rotate(i) {
    this.rotTarget[i] += Math.PI / 2;
  }

  unlock(i) {
    this.unlocks.push({ i, t0: this.now() });
  }

  burst(x, y, color, n = 14, speed = 4) {
    if (this.reducedMotion) n = Math.ceil(n / 3);
    for (let k = 0; k < n; k++) {
      const a = Math.random() * Math.PI * 2;
      const s = speed * (0.4 + Math.random() * 0.8);
      this.particles.push({
        x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0, max: 0.5 + Math.random() * 0.5,
        color, size: 0.05 + Math.random() * 0.07, rect: Math.random() < 0.4,
      });
    }
  }

  floatText(x, y, text, color) {
    this.texts.push({ x, y, text, color, t0: this.now() });
  }

  celebrate() {
    const { w, h } = this.level;
    const cols = [this.c.accent, this.c.c0, this.c.c1, this.c.spark, this.c.portal2];
    for (let k = 0; k < 10; k++) {
      this.burst(Math.random() * (w - 1), Math.random() * (h - 1), cols[k % cols.length], 12, 5);
    }
  }

  busy() {
    return this.slides.length || this.bumps.length || this.particles.length || this.texts.length;
  }

  // ---- frame -------------------------------------------------------------------------
  frame(now, dt) {
    const { ctx, level, c } = this;
    if (!level) return;
    const st = this.session.st;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const k = this.dpr * this.scale * this.cell;
    ctx.setTransform(k, 0, 0, k,
      this.dpr * (this.tx + this.scale * (this.ox + this.cell / 2)),
      this.dpr * (this.ty + this.scale * (this.oy + this.cell / 2)));
    const t = now / 1000;
    const ease = Math.min(1, dt * 14);

    // Backdrop: loom surface, warp threads and pegs.
    ctx.fillStyle = c.board;
    roundRect(ctx, -0.8, -0.8, level.w + 0.6, level.h + 0.6, 0.45);
    ctx.fill();
    ctx.strokeStyle = c.warp;
    ctx.lineWidth = 0.025;
    ctx.beginPath();
    for (let x = 0; x < level.w; x++) {
      ctx.moveTo(x, -0.55);
      ctx.lineTo(x, level.h - 0.45);
    }
    ctx.stroke();
    ctx.fillStyle = c.peg;
    for (let y = 0; y < level.h; y++) {
      for (let x = 0; x < level.w; x++) {
        ctx.beginPath();
        ctx.arc(x, y, 0.055, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Static features.
    for (const [x, y] of level.walls) drawWall(ctx, x, y, c);
    for (const g of level.gates) drawGate(ctx, g.x, g.y, g.dir, c);
    for (let q = 0; q < 2; q++) this.cwK[q] += ((st.color === q ? 1 : 0) - this.cwK[q]) * ease;
    for (const cw of level.cwalls) drawColorWall(ctx, cw.x, cw.y, cw.c, st.color === cw.c, this.cwK[cw.c], c);
    const spin = this.reducedMotion ? 0 : t * 0.8;
    level.portals.forEach(([a, b], p) => {
      const col = c[PORTAL_KEYS[p % PORTAL_KEYS.length]];
      drawPortal(ctx, a[0], a[1], col, String(p + 1), spin, col);
      drawPortal(ctx, b[0], b[1], col, String(p + 1), -spin, col);
    });
    level.blockers.forEach((b, q) => {
      drawTrackLine(ctx, b.track, c);
      const target = b.track[st.bIdx[q]];
      const s = this.blkShown[q];
      s[0] += (target[0] - s[0]) * ease;
      s[1] += (target[1] - s[1]) * ease;
      drawBlocker(ctx, s[0], s[1], c, this.reducedMotion ? 0 : t);
    });

    // Selection lane preview.
    if (this.selected >= 0 && st.alive[this.selected]) this.drawPreview(this.selected);

    // Resting arrows.
    const bumping = new Set(this.bumps.map((b) => b.i));
    const intro = this.reducedMotion ? 1 : Math.min(1, (now - this.born) / 380);
    level.arrows.forEach((a, i) => {
      if (!st.alive[i] || bumping.has(i)) return;
      ctx.globalAlpha = intro;
      this.drawArrow(i, 0, now);
      ctx.globalAlpha = 1;
    });

    // Bumps (blocked launches): move up to the obstacle, knock, return.
    this.bumps = this.bumps.filter((b) => {
      const p = (now - b.t0) / b.dur;
      if (p >= 1) return false;
      const reach = b.dist + 0.12;
      const off = p < 0.45 ? reach * easeOut(p / 0.45) : reach * (1 - easeInOut((p - 0.45) / 0.55));
      this.drawArrow(b.i, off, now, b.track);
      if (b.hit && p > 0.3 && p < 0.8) {
        ctx.strokeStyle = c.danger;
        ctx.globalAlpha = 1 - Math.abs(p - 0.55) * 4;
        ctx.lineWidth = 0.07;
        ctx.beginPath();
        ctx.arc(b.hit[0], b.hit[1], 0.42, 0, Math.PI * 2);
        ctx.stroke();
        ctx.globalAlpha = 1;
      }
      return true;
    });

    // Launches.
    this.slides = this.slides.filter((s) => {
      const p = Math.min(1, (now - s.t0) / s.dur);
      const off = s.dist * (0.3 * p + 0.7 * p * p);
      const fade = off < s.laneLen ? 1 : Math.max(0, 1 - (off - s.laneLen) / (s.track.len + 0.5));
      ctx.globalAlpha = fade;
      drawTrackArrow(ctx, s.track, off, this.arrowColor(s.i), this.arrowStyle(s.i));
      ctx.globalAlpha = 1;
      if (!s.burst && off >= s.laneLen) {
        s.burst = true;
        const ex = s.exit[0] + DX[s.dir] * 0.6;
        const ey = s.exit[1] + DY[s.dir] * 0.6;
        this.burst(ex, ey, this.arrowColor(s.i), 10, 3.5);
      }
      return p < 1;
    });

    this.drawParticles(dt);
    this.drawTexts(now);
  }

  arrowColor(i) {
    const kind = this.level.arrows[i].kind;
    if (kind === KIND.SPARK) return this.c.spark;
    if (kind === KIND.GHOST) return this.c.ghost;
    if (kind === KIND.ROTATOR) return this.c.rot;
    return this.c.ink;
  }

  arrowStyle(i) {
    const kind = this.level.arrows[i].kind;
    return kind === KIND.GHOST ? { dash: [0.34, 0.2] } : {};
  }

  drawArrow(i, off, now, trackOverride = null) {
    const { ctx, c, level } = this;
    const a = level.arrows[i];
    const st = this.session.st;
    const locked = a.lock > st.cleared;
    let color = this.arrowColor(i);
    const fl = this.flashes.find((f) => f.i === i && now - f.t0 < 420);
    if (fl) color = fl.soft ? c.lock : c.danger;
    this.flashes = this.flashes.filter((f) => now - f.t0 < 420);
    const pulse = 0.5 + 0.5 * Math.sin(now / 160);
    let glow = null;
    if (i === this.hint) glow = withAlpha(c.hint, 0.35 + 0.35 * pulse);
    else if (i === this.selected) glow = withAlpha(c.accent, 0.45);
    let shakeX = 0;
    if (fl && fl.soft && !this.reducedMotion) shakeX = Math.sin((now - fl.t0) / 22) * 0.06 * (1 - (now - fl.t0) / 420);

    ctx.save();
    ctx.translate(shakeX, 0);
    if (locked) ctx.globalAlpha *= 0.42;
    if (a.kind === KIND.ROTATOR) {
      const r = this.rotShown;
      r[i] += (this.rotTarget[i] - r[i]) * Math.min(1, 0.25);
      const [x, y] = a.cells[0];
      if (off === 0) {
        drawRotator(ctx, x, y, r[i], color, c.rotRing, glow);
      } else {
        drawTrackArrow(ctx, trackOverride, off, color, { glow });
      }
    } else {
      drawTrackArrow(ctx, trackOverride || this.tracks[i], off, color, { ...this.arrowStyle(i), glow });
      if (off === 0 && (a.kind === KIND.SPARK || a.kind === KIND.SWITCH)) {
        const [x, y] = a.cells[0];
        ctx.fillStyle = c.board;
        ctx.beginPath();
        ctx.arc(x, y, 0.3, 0, Math.PI * 2);
        ctx.fill();
        kindBadge(ctx, a.kind, x, y, c);
      }
    }
    ctx.restore();

    if (off === 0 && (locked || this.unlocks.some((u) => u.i === i))) {
      const m = a.cells[Math.floor((a.cells.length - 1) / 2)];
      const u = this.unlocks.find((q) => q.i === i);
      if (locked) {
        drawLock(ctx, m[0], m[1], a.lock - st.cleared, c);
      } else if (u) {
        const p = (now - u.t0) / 450;
        if (p >= 1) this.unlocks = this.unlocks.filter((q) => q !== u);
        else {
          ctx.globalAlpha = 1 - p;
          drawLock(ctx, m[0], m[1] - p * 0.4, 0, c, 1 + p * 0.5);
          ctx.globalAlpha = 1;
        }
      }
    }
  }

  drawPreview(i) {
    const { ctx, c, level } = this;
    const a = level.arrows[i];
    const st = this.session.st;
    const [hx, hy] = a.cells[a.cells.length - 1];
    const ray = castRay(this.session.S, null, hx, hy, st.dirs[i], st.color, i, true);
    ctx.strokeStyle = withAlpha(c.accent, 0.55);
    ctx.lineWidth = 0.07;
    ctx.lineCap = 'round';
    ctx.setLineDash([0.1, 0.16]);
    ctx.beginPath();
    ray.pts.forEach(([x, y, j], k) => (k === 0 || j ? ctx.moveTo(x, y) : ctx.lineTo(x, y)));
    const last = ray.pts[ray.pts.length - 1];
    if (ray.ok) ctx.lineTo(last[0] + DX[st.dirs[i]] * 0.6, last[1] + DY[st.dirs[i]] * 0.6);
    ctx.stroke();
    ctx.setLineDash([]);
  }

  drawParticles(dt) {
    const { ctx } = this;
    this.particles = this.particles.filter((p) => {
      p.life += dt;
      if (p.life >= p.max) return false;
      p.vx *= 0.94;
      p.vy = p.vy * 0.94 + 3 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      ctx.globalAlpha = 1 - p.life / p.max;
      ctx.fillStyle = p.color;
      if (p.rect) ctx.fillRect(p.x - p.size, p.y - p.size / 2, p.size * 2, p.size);
      else {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        ctx.fill();
      }
      return true;
    });
    ctx.globalAlpha = 1;
  }

  drawTexts(now) {
    const { ctx } = this;
    this.texts = this.texts.filter((f) => {
      const p = (now - f.t0) / 900;
      if (p >= 1) return false;
      ctx.globalAlpha = p < 0.7 ? 1 : 1 - (p - 0.7) / 0.3;
      drawText(ctx, f.text, f.x, f.y - p * 0.8, 0.42, f.color, 800);
      ctx.globalAlpha = 1;
      return true;
    });
  }

  /** Head position in cell units (for floating score text). */
  headOf(i) {
    const a = this.level.arrows[i];
    return a.cells[a.cells.length - 1];
  }

  occupancy() {
    return occupancy(this.level, this.session.st);
  }
}

