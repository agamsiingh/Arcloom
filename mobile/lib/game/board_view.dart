// Board view: layout, zoom/pan transform, precise hit-testing, animation + particles.
// Port of js/game/renderer.js. Painted every frame by BoardPainter.
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../ui/theme.dart';
import 'board_draw.dart';
import 'session.dart';

double _easeOut(double p) => 1 - (1 - p) * (1 - p);
double _easeInOut(double p) => p < 0.5 ? 2 * p * p : 1 - math.pow(-2 * p + 2, 2) / 2;

class _Slide {
  _Slide(this.i, this.track, this.dist, this.laneLen, this.dur, this.t0, this.exit, this.dir);
  final int i;
  final Track track;
  final double dist;
  final int laneLen;
  final double dur, t0;
  final (int, int) exit;
  final int dir;
  bool burst = false;
}

class _Bump {
  _Bump(this.i, this.track, this.dist, this.t0, this.hit);
  final int i;
  final Track track;
  final int dist;
  final double t0;
  final Cell? hit;
  static const double dur = 360;
}

class _Flash {
  _Flash(this.i, this.t0, {this.soft = false});
  final int i;
  final double t0;
  final bool soft;
}

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.max, this.color, this.size, this.rect);
  double x, y, vx, vy, life = 0;
  final double max, size;
  final Color color;
  final bool rect;
}

class _FloatText {
  _FloatText(this.x, this.y, this.text, this.color, this.t0);
  final double x, y, t0;
  final String text;
  final Color color;
}

class HitResult {
  const HitResult(this.i, this.alt, this.ambiguous);
  final int i;
  final int alt;
  final bool ambiguous;
}

class BoardView {
  BoardView(this.session, this.clock) {
    tracks = [for (final a in level.arrows) buildTrack(a.cells, a.dir)];
    resetFx();
    born = clock();
  }

  final Session session;

  /// Milliseconds clock (monotonic in production, controllable in tests).
  final double Function() clock;
  Level get level => session.level;
  late List<Track> tracks;
  late double born;
  bool reducedMotion = false;
  Palette pal = Palette.light;

  // layout
  Size size = Size.zero;
  double cell = 40, ox = 0, oy = 0;
  double scale = 1, tx = 0, ty = 0;

  // fx
  final List<_Slide> _slides = [];
  final List<_Bump> _bumps = [];
  final List<_Flash> _flashes = [];
  final List<_Particle> _particles = [];
  final List<_FloatText> _texts = [];
  final List<(int, double)> _unlocks = [];
  int hint = -1;
  int selected = -1;
  late List<double> _rotShown, _rotTarget;
  late List<Offset> _blkShown;
  final List<double> _cwK = [1, 0];
  final _rand = math.Random();

  void resetFx() {
    final st = session.st;
    _slides.clear();
    _bumps.clear();
    _flashes.clear();
    _particles.clear();
    _texts.clear();
    _unlocks.clear();
    hint = -1;
    selected = -1;
    _rotShown = [for (final d in st.dirs) d * math.pi / 2];
    _rotTarget = List.of(_rotShown);
    _blkShown = [
      for (var k = 0; k < level.blockers.length; k++)
        Offset(level.blockers[k].track[st.bIdx[k]].$1.toDouble(), level.blockers[k].track[st.bIdx[k]].$2.toDouble()),
    ];
    _cwK[0] = st.color == 0 ? 1 : 0;
    _cwK[1] = st.color == 1 ? 1 : 0;
  }

  /// Snap displayed state to the session (after undo / continue), keeping in-flight effects.
  void syncToState() {
    final slides = List.of(_slides), particles = List.of(_particles), texts = List.of(_texts);
    resetFx();
    _slides.addAll(slides);
    _particles.addAll(particles);
    _texts.addAll(texts);
  }

  void layout(Size s) {
    if (s == size) return;
    size = s;
    const margin = 18.0;
    cell = math.min(
      math.min((s.width - margin * 2) / (level.w + 0.6), (s.height - margin * 2) / (level.h + 0.6)),
      64,
    );
    ox = (s.width - level.w * cell) / 2;
    oy = (s.height - level.h * cell) / 2;
    clampPan();
  }

  // ---- coordinates & zoom ------------------------------------------------------------
  Offset toUnits(Offset p) {
    final bx = (p.dx - tx) / scale, by = (p.dy - ty) / scale;
    return Offset((bx - ox) / cell - 0.5, (by - oy) / cell - 0.5);
  }

  /// Screen position of a cell centre (tests / accessibility).
  Offset cellCenter(int x, int y) => Offset(tx + scale * (ox + (x + 0.5) * cell), ty + scale * (oy + (y + 0.5) * cell));

  double get maxScale => math.max(1, math.min(3.5, 64 / cell));
  bool get canZoom => maxScale > 1.05;

  void zoomAt(Offset p, double factor) {
    final next = (scale * factor).clamp(1.0, maxScale);
    final f = next / scale;
    tx = p.dx - (p.dx - tx) * f;
    ty = p.dy - (p.dy - ty) * f;
    scale = next;
    clampPan();
  }

  void pan(Offset d) {
    tx += d.dx;
    ty += d.dy;
    clampPan();
  }

  void clampPan() {
    if (size.isEmpty) return;
    if (scale <= 1.001) {
      scale = 1;
      tx = 0;
      ty = 0;
      return;
    }
    tx = tx.clamp(size.width - size.width * scale, 0.0);
    ty = ty.clamp(size.height - size.height * scale, 0.0);
  }

  void resetZoom() {
    scale = 1;
    tx = 0;
    ty = 0;
  }

  // ---- hit testing -------------------------------------------------------------------
  /// Nearest arrow to a screen point. Taps inside an arrow's own cell get priority;
  /// a tap nearly equidistant from two arrows is flagged ambiguous so the caller
  /// can ask for confirmation instead of guessing.
  HitResult? hitTest(Offset p, {bool large = false}) {
    final uv = toUnits(p);
    final u = uv.dx, v = uv.dy;
    final st = session.st;
    final screenCell = cell * scale;
    final r = math.min(0.95, math.max(large ? 0.78 : 0.62, 20 / screenCell));
    final cx = u.round(), cy = v.round();
    (int, double)? best, second;
    for (var i = 0; i < level.arrows.length; i++) {
      if (st.alive[i] == 0) continue;
      final a = level.arrows[i];
      var d = a.kind == Kind.rotator
          ? math.max(0.0, math.sqrt(math.pow(u - a.cells[0].$1, 2) + math.pow(v - a.cells[0].$2, 2)) - 0.3)
          : distToPath(u, v, a.cells, st.dirs[i]);
      if (a.cells.any((c) => c.$1 == cx && c.$2 == cy)) d = math.max(0, d - 0.25);
      if (d > r) continue;
      if (best == null || d < best.$2) {
        second = best;
        best = (i, d);
      } else if (second == null || d < second.$2) {
        second = (i, d);
      }
    }
    if (best == null) return null;
    final ambiguous = second != null && second.$2 - best.$2 < 0.2;
    return HitResult(best.$1, ambiguous ? second.$1 : -1, ambiguous);
  }

  // ---- effects -----------------------------------------------------------------------
  int _laneLen(Ray trace) => trace.pts.skip(1).where((p) => !p.$3).length;

  void addSlide(int i, Ray trace, int dir) {
    final a = level.arrows[i];
    final laneLen = _laneLen(trace);
    final track = buildTrack(a.cells, dir, lane: trace.pts, runOut: a.cells.length + 3);
    final dist = laneLen + a.cells.length + 1.5;
    final dur = reducedMotion ? 160.0 : math.min(620.0, 200 + dist * 26);
    final exit = trace.pts.last;
    _slides.add(_Slide(i, track, dist, laneLen, dur, clock(), (exit.$1, exit.$2), dir));
  }

  void addBump(int i, Ray trace, int dir) {
    final a = level.arrows[i];
    final track = buildTrack(a.cells, dir, lane: trace.pts, runOut: 1);
    _bumps.add(_Bump(i, track, _laneLen(trace), clock(), trace.hit));
    _flashes.add(_Flash(i, clock()));
  }

  void shake(int i) => _flashes.add(_Flash(i, clock(), soft: true));
  void rotate(int i) => _rotTarget[i] += math.pi / 2;
  void unlock(int i) => _unlocks.add((i, clock()));

  void burst(double x, double y, Color color, {int n = 14, double speed = 4}) {
    if (reducedMotion) n = (n / 3).ceil();
    for (var k = 0; k < n; k++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final s = speed * (0.4 + _rand.nextDouble() * 0.8);
      _particles.add(_Particle(x, y, math.cos(a) * s, math.sin(a) * s, 0.5 + _rand.nextDouble() * 0.5, color,
          0.05 + _rand.nextDouble() * 0.07, _rand.nextDouble() < 0.4));
    }
  }

  void floatText(double x, double y, String text, Color color) => _texts.add(_FloatText(x, y, text, color, clock()));

  void celebrate() {
    final cols = [pal.accent, pal.c0, pal.c1, pal.spark, pal.portals[1]];
    for (var k = 0; k < 10; k++) {
      burst(_rand.nextDouble() * (level.w - 1), _rand.nextDouble() * (level.h - 1), cols[k % cols.length], n: 12, speed: 5);
    }
  }

  Cell headOf(int i) => level.arrows[i].head;

  bool get busy => _slides.isNotEmpty || _bumps.isNotEmpty || _particles.isNotEmpty || _texts.isNotEmpty;

  Color arrowColor(int i) => switch (level.arrows[i].kind) {
        Kind.spark => pal.spark,
        Kind.ghost => pal.ghost,
        Kind.rotator => pal.rot,
        _ => pal.ink,
      };

  List<double>? _dash(int i) => level.arrows[i].kind == Kind.ghost ? const [0.34, 0.2] : null;

  // ---- frame -------------------------------------------------------------------------
  void paint(Canvas c, double now, double dt) {
    final p = pal;
    final st = session.st;
    c.save();
    c.translate(tx + scale * (ox + cell / 2), ty + scale * (oy + cell / 2));
    c.scale(scale * cell);
    final t = now / 1000;
    final ease = math.min(1.0, dt * 14);

    // Backdrop: loom surface, warp threads and pegs.
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-0.8, -0.8, level.w + 0.6, level.h + 0.6), const Radius.circular(0.45)),
      Paint()..color = p.board,
    );
    final warp = Paint()
      ..color = p.warp
      ..strokeWidth = 0.025;
    for (var x = 0; x < level.w; x++) {
      c.drawLine(Offset(x.toDouble(), -0.55), Offset(x.toDouble(), level.h - 0.45), warp);
    }
    final peg = Paint()..color = p.peg;
    for (var y = 0; y < level.h; y++) {
      for (var x = 0; x < level.w; x++) {
        c.drawCircle(Offset(x.toDouble(), y.toDouble()), 0.055, peg);
      }
    }

    // Static features.
    for (final (x, y) in level.walls) {
      drawWall(c, x.toDouble(), y.toDouble(), p);
    }
    for (final g in level.gates) {
      drawGate(c, g.x.toDouble(), g.y.toDouble(), g.dir, p);
    }
    for (var q = 0; q < 2; q++) {
      _cwK[q] += ((st.color == q ? 1 : 0) - _cwK[q]) * ease;
    }
    for (final w in level.cwalls) {
      drawColorWall(c, w.x.toDouble(), w.y.toDouble(), w.c, st.color == w.c, _cwK[w.c], p);
    }
    final spin = reducedMotion ? 0.0 : t * 0.8;
    for (var q = 0; q < level.portals.length; q++) {
      final (a, b) = level.portals[q];
      final col = p.portals[q % p.portals.length];
      drawPortal(c, a.$1.toDouble(), a.$2.toDouble(), col, '${q + 1}', spin);
      drawPortal(c, b.$1.toDouble(), b.$2.toDouble(), col, '${q + 1}', -spin);
    }
    for (var q = 0; q < level.blockers.length; q++) {
      final b = level.blockers[q];
      drawTrackLine(c, b.track, p);
      final target = b.track[st.bIdx[q]];
      final s = _blkShown[q];
      _blkShown[q] = Offset(s.dx + (target.$1 - s.dx) * ease, s.dy + (target.$2 - s.dy) * ease);
      drawBlocker(c, _blkShown[q].dx, _blkShown[q].dy, p, reducedMotion ? 0 : t);
    }

    // Selection lane preview.
    if (selected >= 0 && st.alive[selected] != 0) {
      final a = level.arrows[selected];
      final (hx, hy) = a.head;
      final ray = castRay(session.s, null, hx, hy, st.dirs[selected], st.color, selected, true);
      drawLanePreview(c, ray, st.dirs[selected], fade(p.accent, 0.55));
    }

    // Resting arrows.
    final bumping = {for (final b in _bumps) b.i};
    final intro = reducedMotion ? 1.0 : math.min(1.0, (now - born) / 380);
    _flashes.removeWhere((f) => now - f.t0 >= 420);
    for (var i = 0; i < level.arrows.length; i++) {
      if (st.alive[i] == 0 || bumping.contains(i)) continue;
      _drawArrow(c, i, 0, now, alpha: intro);
    }

    // Bumps (blocked launches): move up to the obstacle, knock, return.
    _bumps.removeWhere((b) {
      final pr = (now - b.t0) / _Bump.dur;
      if (pr >= 1) return true;
      final reach = b.dist + 0.12;
      final off = pr < 0.45 ? reach * _easeOut(pr / 0.45) : reach * (1 - _easeInOut((pr - 0.45) / 0.55));
      _drawArrow(c, b.i, off, now, track: b.track);
      final hit = b.hit;
      if (hit != null && pr > 0.3 && pr < 0.8) {
        c.drawCircle(
          Offset(hit.$1.toDouble(), hit.$2.toDouble()),
          0.42,
          Paint()
            ..color = fade(p.danger, 1 - (pr - 0.55).abs() * 4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.07,
        );
      }
      return false;
    });

    // Launches.
    _slides.removeWhere((s) {
      final pr = math.min(1.0, (now - s.t0) / s.dur);
      final off = s.dist * (0.3 * pr + 0.7 * pr * pr);
      final fadeA = off < s.laneLen ? 1.0 : math.max(0.0, 1 - (off - s.laneLen) / (s.track.len + 0.5));
      drawTrackArrow(c, s.track, off, arrowColor(s.i), dash: _dash(s.i), alpha: fadeA);
      if (!s.burst && off >= s.laneLen) {
        s.burst = true;
        burst(s.exit.$1 + dx[s.dir] * 0.6, s.exit.$2 + dy[s.dir] * 0.6, arrowColor(s.i), n: 10, speed: 3.5);
      }
      return pr >= 1;
    });

    _paintParticles(c, dt);
    _paintTexts(c, now);
    c.restore();
  }

  void _drawArrow(Canvas c, int i, double off, double now, {Track? track, double alpha = 1}) {
    final p = pal;
    final a = level.arrows[i];
    final st = session.st;
    final locked = a.lock > st.cleared;
    var color = arrowColor(i);
    _Flash? fl;
    for (final f in _flashes) {
      if (f.i == i) fl = f;
    }
    if (fl != null) color = fl.soft ? p.lock : p.danger;
    final pulse = 0.5 + 0.5 * math.sin(now / 160);
    Color? glow;
    if (i == hint) {
      glow = fade(p.hint, 0.35 + 0.35 * pulse);
    } else if (i == selected) {
      glow = fade(p.accent, 0.45);
    }
    var shakeX = 0.0;
    if (fl != null && fl.soft && !reducedMotion) {
      shakeX = math.sin((now - fl.t0) / 22) * 0.06 * (1 - (now - fl.t0) / 420);
    }
    final aAlpha = alpha * (locked ? 0.42 : 1);
    c.save();
    c.translate(shakeX, 0);
    if (a.kind == Kind.rotator) {
      _rotShown[i] += (_rotTarget[i] - _rotShown[i]) * 0.25;
      final (x, y) = a.cells[0];
      if (off == 0) {
        drawRotator(c, x.toDouble(), y.toDouble(), _rotShown[i], color, p.rotRing, glow, alpha: aAlpha);
      } else {
        drawTrackArrow(c, track!, off, color, glow: glow, alpha: aAlpha);
      }
    } else {
      drawTrackArrow(c, track ?? tracks[i], off, color, dash: _dash(i), glow: glow, alpha: aAlpha);
      if (off == 0 && (a.kind == Kind.spark || a.kind == Kind.switcher)) {
        final (x, y) = a.cells[0];
        c.drawCircle(Offset(x.toDouble(), y.toDouble()), 0.3, Paint()..color = p.board);
        kindBadge(c, a.kind, x.toDouble(), y.toDouble(), p);
      }
    }
    c.restore();

    if (off == 0) {
      final m = a.cells[(a.cells.length - 1) ~/ 2];
      if (locked) {
        drawLock(c, m.$1.toDouble(), m.$2.toDouble(), a.lock - st.cleared, p, alpha: alpha);
      } else {
        final u = _unlocks.where((q) => q.$1 == i).firstOrNull;
        if (u != null) {
          final pr = (now - u.$2) / 450;
          if (pr >= 1) {
            _unlocks.remove(u);
          } else {
            drawLock(c, m.$1.toDouble(), m.$2 - pr * 0.4, 0, p, k: 1 + pr * 0.5, alpha: 1 - pr);
          }
        }
      }
    }
  }

  void _paintParticles(Canvas c, double dt) {
    _particles.removeWhere((q) {
      q.life += dt;
      if (q.life >= q.max) return true;
      q.vx *= 0.94;
      q.vy = q.vy * 0.94 + 3 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
      final paint = Paint()..color = fade(q.color, 1 - q.life / q.max);
      if (q.rect) {
        c.drawRect(Rect.fromLTWH(q.x - q.size, q.y - q.size / 2, q.size * 2, q.size), paint);
      } else {
        c.drawCircle(Offset(q.x, q.y), q.size, paint);
      }
      return false;
    });
  }

  void _paintTexts(Canvas c, double now) {
    _texts.removeWhere((f) {
      final pr = (now - f.t0) / 900;
      if (pr >= 1) return true;
      final a = pr < 0.7 ? 1.0 : 1 - (pr - 0.7) / 0.3;
      drawText(c, f.text, f.x, f.y - pr * 0.8, 0.42, fade(f.color, a), FontWeight.w800);
      return false;
    });
  }
}
