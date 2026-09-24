// Canvas drawing primitives — port of js/game/draw.js.
// Coordinates are in cell units: cell (x, y) is centred at (x, y).
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../ui/theme.dart';

const double lineW = 0.16;
const double _tip = 0.36;
const double _headLen = 0.36;
const double _headHalf = 0.23;

class TrackPoint {
  const TrackPoint(this.x, this.y, this.j);
  final double x, y;
  final bool j; // reached by a portal jump (zero-length, not drawn)
}

class Track {
  Track(this.t, this.s, this.len);
  final List<TrackPoint> t;
  final List<double> s;
  final int len;
}

/// Virtual point behind the tail, body cells, then the lane and a run-out past the edge.
Track buildTrack(List<Cell> cells, int dir, {List<LanePoint>? lane, int runOut = 0}) {
  final first = cells.length > 1
      ? (cells[1].$1 - cells[0].$1, cells[1].$2 - cells[0].$2)
      : (dx[dir], dy[dir]);
  final t = <TrackPoint>[
    TrackPoint((cells[0].$1 - first.$1).toDouble(), (cells[0].$2 - first.$2).toDouble(), false),
    for (final (x, y) in cells) TrackPoint(x.toDouble(), y.toDouble(), false),
  ];
  if (lane != null) {
    for (var k = 1; k < lane.length; k++) {
      t.add(TrackPoint(lane[k].$1.toDouble(), lane[k].$2.toDouble(), lane[k].$3));
    }
  }
  final last = t.last;
  final ext = math.max(1, runOut);
  for (var k = 1; k <= ext; k++) {
    t.add(TrackPoint(last.x + dx[dir] * k, last.y + dy[dir] * k, false));
  }
  final s = <double>[0];
  for (var k = 1; k < t.length; k++) {
    s.add(s[k - 1] + (t[k].j ? 0 : 1));
  }
  return Track(t, s, cells.length);
}

({double x, double y, double dx, double dy}) _pointAt(Track tr, double v) {
  final t = tr.t, s = tr.s;
  for (var k = 1; k < t.length; k++) {
    if (t[k].j) continue;
    if (v <= s[k] || k == t.length - 1) {
      final f = (v - s[k - 1]).clamp(0.0, 1.0);
      return (
        x: t[k - 1].x + (t[k].x - t[k - 1].x) * f,
        y: t[k - 1].y + (t[k].y - t[k - 1].y) * f,
        dx: t[k].x - t[k - 1].x,
        dy: t[k].y - t[k - 1].y,
      );
    }
  }
  return (x: t.last.x, y: t.last.y, dx: 0, dy: -1);
}

/// Polylines covering arc-length window [a, b], split at portal jumps.
List<List<Offset>> _sample(Track tr, double a, double b) {
  final t = tr.t, s = tr.s;
  final lines = <List<Offset>>[];
  List<Offset>? cur;
  for (var k = 1; k < t.length; k++) {
    if (t[k].j) {
      if (cur != null) lines.add(cur);
      cur = null;
      continue;
    }
    final s0 = s[k - 1], s1 = s[k];
    final lo = math.max(a, s0), hi = math.min(b, s1);
    if (hi < lo) {
      if (s0 > b) break;
      continue;
    }
    Offset lerp(double v) =>
        Offset(t[k - 1].x + (t[k].x - t[k - 1].x) * (v - s0), t[k - 1].y + (t[k].y - t[k - 1].y) * (v - s0));
    cur ??= [lerp(lo)];
    cur.add(lerp(hi));
  }
  if (cur != null) lines.add(cur);
  return lines;
}

Color fade(Color c, double alpha) => alpha >= 1 ? c : c.withValues(alpha: c.a * alpha.clamp(0, 1));

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Path dashPath(Path src, List<double> pattern) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    var i = 0;
    while (d < m.length) {
      final len = pattern[i % pattern.length];
      if (i.isEven) out.addPath(m.extractPath(d, math.min(d + len, m.length)), Offset.zero);
      d += len;
      i++;
    }
  }
  return out;
}

Path _polyPath(List<List<Offset>> lines) {
  final p = Path();
  for (final l in lines) {
    p.moveTo(l[0].dx, l[0].dy);
    for (var k = 1; k < l.length; k++) {
      p.lineTo(l[k].dx, l[k].dy);
    }
  }
  return p;
}

void _arrowHead(Canvas c, double x, double y, double ddx, double ddy, Paint paint) {
  final len = math.sqrt(ddx * ddx + ddy * ddy);
  final ux = len == 0 ? 0.0 : ddx / len, uy = len == 0 ? -1.0 : ddy / len;
  c.drawPath(
    Path()
      ..moveTo(x, y)
      ..lineTo(x - ux * _headLen - uy * _headHalf, y - uy * _headLen + ux * _headHalf)
      ..lineTo(x - ux * _headLen + uy * _headHalf, y - uy * _headLen - ux * _headHalf)
      ..close(),
    paint,
  );
}

/// Draw an arrow along its track, shifted `off` cells forward.
void drawTrackArrow(Canvas c, Track tr, double off, Color color,
    {double width = lineW, List<double>? dash, Color? glow, double alpha = 1}) {
  final a = 1 - 0.22 + off;
  final b = tr.len + _tip + off;
  final path = _polyPath(_sample(tr, a, b - _headLen * 0.7));
  final tip = _pointAt(tr, b);
  if (glow != null) {
    final g = fade(glow, alpha);
    c.drawPath(path, _stroke(g, width + 0.22));
    _arrowHead(c, tip.x + tip.dx * 0.08, tip.y + tip.dy * 0.08, tip.dx, tip.dy, _fill(g));
  }
  final col = fade(color, alpha);
  c.drawPath(dash != null ? dashPath(path, dash) : path, _stroke(col, width));
  _arrowHead(c, tip.x, tip.y, tip.dx, tip.dy, _fill(col));
}

void drawRotator(Canvas c, double x, double y, double angle, Color color, Color ring, Color? glow, {double alpha = 1}) {
  final ux = math.sin(angle), uy = -math.cos(angle);
  final r = fade(ring, alpha);
  c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 0.4), -math.pi * 0.35, math.pi * 1.55, false, _stroke(r, 0.06));
  const e = math.pi * 1.2;
  final ex = x + math.cos(e) * 0.4, ey = y + math.sin(e) * 0.4;
  c.drawPath(
    Path()
      ..moveTo(ex + 0.1, ey - 0.02)
      ..lineTo(ex - 0.06, ey + 0.1)
      ..lineTo(ex - 0.07, ey - 0.08)
      ..close(),
    _fill(r),
  );
  if (glow != null) {
    c.drawLine(Offset(x - ux * 0.26, y - uy * 0.26), Offset(x + ux * 0.1, y + uy * 0.1), _stroke(fade(glow, alpha), lineW + 0.22));
  }
  final col = fade(color, alpha);
  c.drawLine(Offset(x - ux * 0.26, y - uy * 0.26), Offset(x + ux * 0.06, y + uy * 0.06), _stroke(col, lineW));
  _arrowHead(c, x + ux * 0.34, y + uy * 0.34, ux, uy, _fill(col));
}

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

void drawWall(Canvas c, double x, double y, Palette p) {
  c.drawRRect(_rr(x - 0.4, y - 0.4, 0.8, 0.8, 0.16), _fill(p.stone));
  c.drawRRect(_rr(x - 0.4, y - 0.4, 0.8, 0.3, 0.14), _fill(p.stoneHi));
}

void drawGate(Canvas c, double x, double y, int dir, Palette p) {
  c.drawRRect(_rr(x - 0.42, y - 0.42, 0.84, 0.84, 0.14), _stroke(p.gateFrame, 0.05));
  c.save();
  c.translate(x, y);
  c.rotate(dir * math.pi / 2);
  final paint = _stroke(p.gate, 0.09);
  for (final oy in const [0.14, -0.12]) {
    c.drawPath(
      Path()
        ..moveTo(-0.22, oy + 0.12)
        ..lineTo(0, oy - 0.1)
        ..lineTo(0.22, oy + 0.12),
      paint,
    );
  }
  c.restore();
}

/// k: 0 lowered .. 1 raised. Stripes (colour A) / dots (colour B) for colour-blind players.
void drawColorWall(Canvas c, double x, double y, int colorIdx, bool raised, double k, Palette p) {
  final col = colorIdx == 0 ? p.c0 : p.c1;
  final r = 0.28 + 0.14 * k;
  if (raised || k > 0.02) {
    c.drawRRect(_rr(x - r, y - r, r * 2, r * 2, 0.1), _fill(fade(col, 0.35 + 0.65 * k)));
    if (colorIdx == 0) {
      final path = Path();
      for (final o in const [-0.16, 0.0, 0.16]) {
        path
          ..moveTo(x + o - 0.1 * k, y + 0.12 * k)
          ..lineTo(x + o + 0.1 * k, y - 0.12 * k);
      }
      c.drawPath(path, _stroke(p.onColor, 0.05));
    } else {
      for (final (ox, oy) in const [(-0.12, -0.12), (0.12, -0.12), (-0.12, 0.12), (0.12, 0.12)]) {
        c.drawCircle(Offset(x + ox * k, y + oy * k), 0.04, _fill(p.onColor));
      }
    }
  }
  if (k < 0.98) {
    final outline = Path()..addRRect(_rr(x - 0.3, y - 0.3, 0.6, 0.6, 0.1));
    c.drawPath(dashPath(outline, const [0.08, 0.07]), _stroke(col, 0.05)..strokeCap = StrokeCap.butt);
  }
}

void drawPortal(Canvas c, double x, double y, Color col, String label, double t) {
  c.drawCircle(Offset(x, y), 0.38, _fill(fade(col, 0.18)));
  c.drawCircle(Offset(x, y), 0.38, _stroke(col, 0.07));
  c.save();
  c.translate(x, y);
  c.rotate(t);
  final ring = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.26));
  c.drawPath(dashPath(ring, const [0.12, 0.1]), _stroke(col, 0.05)..strokeCap = StrokeCap.butt);
  c.restore();
  drawText(c, label, x, y + 0.01, 0.26, col, FontWeight.w700);
}

final Map<String, TextPainter> _textCache = {};

void drawText(Canvas c, String text, double x, double y, double size, Color color, [FontWeight weight = FontWeight.w600]) {
  // Quantize alpha so fading text reuses cached painters instead of re-laying out each frame.
  color = color.withValues(alpha: (color.a * 16).round() / 16);
  final key = '$text|${color.toARGB32()}|${weight.value}';
  final tp = _textCache.putIfAbsent(key, () {
    if (_textCache.length > 400) _textCache.clear();
    return TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 20, fontWeight: weight, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
  });
  c.save();
  c.translate(x, y);
  c.scale(size / 20);
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  c.restore();
}

void drawBlocker(Canvas c, double x, double y, Palette p, double t) {
  final s = 0.34 + math.sin(t * 3) * 0.015;
  final path = Path();
  for (var k = 0; k < 6; k++) {
    final a = math.pi / 6 + k * math.pi / 3;
    final px = x + math.cos(a) * s, py = y + math.sin(a) * s;
    k == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
  }
  c.drawPath(path..close(), _fill(p.drift));
  c.drawCircle(Offset(x - 0.09, y - 0.03), 0.05, _fill(p.onColor));
  c.drawCircle(Offset(x + 0.09, y - 0.03), 0.05, _fill(p.onColor));
}

void drawTrackLine(Canvas c, List<Cell> track, Palette p) {
  final path = Path()..moveTo(track[0].$1.toDouble(), track[0].$2.toDouble());
  for (final (x, y) in track.skip(1)) {
    path.lineTo(x.toDouble(), y.toDouble());
  }
  c.drawPath(dashPath(path, const [0.02, 0.18]), _stroke(p.driftTrack, 0.08));
  for (final cell in [track.first, track.last]) {
    c.drawCircle(Offset(cell.$1.toDouble(), cell.$2.toDouble()), 0.08, _fill(p.driftTrack));
  }
}

void drawLock(Canvas c, double x, double y, int count, Palette p, {double k = 1, double alpha = 1}) {
  k *= 1.4;
  final col = fade(p.lock, alpha);
  c.save();
  c.translate(x, y);
  c.scale(k);
  c.drawArc(Rect.fromCircle(center: const Offset(0, -0.1), radius: 0.12), math.pi, math.pi, false, _stroke(col, 0.06));
  c.drawRRect(_rr(-0.2, -0.1, 0.4, 0.3, 0.06), _fill(col));
  c.restore();
  drawText(c, '$count', x, y + 0.05 * k, 0.21 * k, fade(p.onColor, alpha), FontWeight.w800);
}

void kindBadge(Canvas c, Kind kind, double x, double y, Palette p) {
  c.save();
  c.translate(x, y);
  c.scale(1.35);
  if (kind == Kind.spark) {
    c.drawPath(
      Path()
        ..moveTo(0.05, -0.22)
        ..lineTo(-0.12, 0.03)
        ..lineTo(0, 0.03)
        ..lineTo(-0.05, 0.22)
        ..lineTo(0.12, -0.03)
        ..lineTo(0, -0.03)
        ..close(),
      _fill(p.spark),
    );
  } else if (kind == Kind.switcher) {
    final r = Rect.fromCircle(center: Offset.zero, radius: 0.17);
    c.drawArc(r, math.pi / 2, math.pi, true, _fill(p.c0));
    c.drawArc(r, -math.pi / 2, math.pi, true, _fill(p.c1));
  }
  c.restore();
}

void drawLanePreview(Canvas c, Ray ray, int dir, Color color) {
  final path = Path();
  for (var k = 0; k < ray.pts.length; k++) {
    final (x, y, j) = ray.pts[k];
    (k == 0 || j) ? path.moveTo(x.toDouble(), y.toDouble()) : path.lineTo(x.toDouble(), y.toDouble());
  }
  if (ray.ok) {
    final (x, y, _) = ray.pts.last;
    path.lineTo(x + dx[dir] * 0.6, y + dy[dir] * 0.6);
  }
  c.drawPath(dashPath(path, const [0.1, 0.16]), _stroke(color, 0.07));
}

// ---- geometry ---------------------------------------------------------------------------

double distToPath(double u, double v, List<Cell> cells, int dir) {
  final (hx, hy) = cells.last;
  final pts = <(double, double)>[
    if (cells.length == 1) (hx - dx[dir] * 0.3, hy - dy[dir] * 0.3),
    for (final (x, y) in cells) (x.toDouble(), y.toDouble()),
    (hx + dx[dir] * 0.36, hy + dy[dir] * 0.36),
  ];
  var best = double.infinity;
  for (var k = 1; k < pts.length; k++) {
    best = math.min(best, _distSeg(u, v, pts[k - 1], pts[k]));
  }
  return best;
}

double _distSeg(double px, double py, (double, double) a, (double, double) b) {
  final ddx = b.$1 - a.$1, ddy = b.$2 - a.$2;
  final l = ddx * ddx + ddy * ddy;
  final t = l == 0 ? 0.0 : (((px - a.$1) * ddx + (py - a.$2) * ddy) / l).clamp(0.0, 1.0);
  final ex = px - (a.$1 + t * ddx), ey = py - (a.$2 + t * ddy);
  return math.sqrt(ex * ex + ey * ey);
}

