// Pure game rules: lane tracing, move resolution, world ticks and chain reactions.
// Port of js/core/rules.js.
import 'dart:typed_data';

import 'model.dart';

/// A lane point; `jump` = reached by teleporting through a portal pair.
typedef LanePoint = (int x, int y, bool jump);

class Ray {
  Ray(this.ok, this.pts, {this.hit});
  final bool ok;
  final List<LanePoint> pts;
  final Cell? hit;
}

/// Cast a lane from (x, y) heading `d`. ok=true means the lane exits the board.
Ray castRay(StaticBoard s, Int16List? occ, int x, int y, int d, int color, int self, bool ghost) {
  final pts = <LanePoint>[(x, y, false)];
  final seen = <int>{};
  var guard = 0;
  for (;;) {
    final nx = x + dx[d];
    final ny = y + dy[d];
    if (nx < 0 || ny < 0 || nx >= s.w || ny >= s.h) return Ray(true, pts);
    final c = ny * s.w + nx;
    final t = s.type[c];
    if (t == tWall) return Ray(false, pts, hit: (nx, ny));
    if (t == tGate && s.gdir[c] != d) return Ray(false, pts, hit: (nx, ny));
    if (t == tCwall && s.ccol[c] == color) return Ray(false, pts, hit: (nx, ny));
    final o = occ != null ? occ[c] : -1;
    if (o == -2) return Ray(false, pts, hit: (nx, ny));
    if (o >= 0 && (o == self || !ghost)) return Ray(false, pts, hit: (nx, ny));
    pts.add((nx, ny, false));
    if (t == tPortal) {
      final key = c * 4 + d;
      if (!seen.add(key)) return Ray(false, pts, hit: (nx, ny));
      final p = s.partner[c];
      x = p % s.w;
      y = (p - x) ~/ s.w;
      pts.add((x, y, true));
    } else {
      x = nx;
      y = ny;
    }
    if (++guard > 4000) return Ray(false, pts, hit: (nx, ny));
  }
}

Ray traceArrow(Level level, StaticBoard s, PlayState st, Int16List occ, int i) {
  final a = level.arrows[i];
  final (hx, hy) = a.head;
  return castRay(s, occ, hx, hy, st.dirs[i], st.color, i, a.kind == Kind.ghost);
}

bool isLocked(Level level, PlayState st, int i) => level.arrows[i].lock > st.cleared;

List<int> legalMoves(Level level, StaticBoard s, PlayState st, [Int16List? occ]) {
  occ ??= occupancy(level, st);
  final out = <int>[];
  for (var i = 0; i < level.arrows.length; i++) {
    if (st.alive[i] == 0 || isLocked(level, st, i)) continue;
    if (traceArrow(level, s, st, occ, i).ok) out.add(i);
  }
  return out;
}

sealed class GameEvent {
  const GameEvent();
}

class ClearEvent extends GameEvent {
  const ClearEvent(this.i, this.trace, this.dir, this.chain);
  final int i;
  final Ray trace;
  final int dir;
  final int chain;
}

class SwitchEvent extends GameEvent {
  const SwitchEvent(this.color);
  final int color;
}

class UnlockEvent extends GameEvent {
  const UnlockEvent(this.i);
  final int i;
}

class RotateEvent extends GameEvent {
  const RotateEvent(this.i, this.dir);
  final int i;
  final int dir;
}

class DriftEvent extends GameEvent {
  const DriftEvent(this.b, this.idx);
  final int b;
  final int idx;
}

enum MoveResult { invalid, locked, blocked, cleared }

class MoveOutcome {
  MoveOutcome(this.result, this.st, {this.events = const [], this.trace, this.chain = 0});
  final MoveResult result;
  final PlayState st;
  final List<GameEvent> events;
  final Ray? trace;
  final int chain;
}

void _clearArrow(Level level, PlayState st, int i, List<GameEvent> events, Ray trace, int chain) {
  final before = st.cleared;
  st.alive[i] = 0;
  st.cleared++;
  events.add(ClearEvent(i, trace, st.dirs[i], chain));
  if (level.arrows[i].kind == Kind.switcher) {
    st.color ^= 1;
    events.add(SwitchEvent(st.color));
  }
  for (var j = 0; j < level.arrows.length; j++) {
    final l = level.arrows[j].lock;
    if (st.alive[j] != 0 && l > before && l <= st.cleared) events.add(UnlockEvent(j));
  }
}

void _tick(Level level, PlayState st, List<GameEvent> events) {
  for (var j = 0; j < level.arrows.length; j++) {
    if (st.alive[j] != 0 && level.arrows[j].kind == Kind.rotator) {
      st.dirs[j] = (st.dirs[j] + 1) % 4;
      events.add(RotateEvent(j, st.dirs[j]));
    }
  }
  for (var b = 0; b < level.blockers.length; b++) {
    final len = level.blockers[b].track.length;
    if (len < 2) continue;
    var next = st.bIdx[b] + st.bStep[b];
    if (next < 0 || next >= len) {
      st.bStep[b] = -st.bStep[b];
      next = st.bIdx[b] + st.bStep[b];
    }
    st.bIdx[b] = next;
    events.add(DriftEvent(b, next));
  }
}

/// Launch every spark arrow whose lane is open, repeatedly, until the board settles.
int _resolveChains(Level level, StaticBoard s, PlayState st, List<GameEvent> events) {
  var depth = 0;
  for (;;) {
    var fired = false;
    final occ = occupancy(level, st);
    for (var j = 0; j < level.arrows.length; j++) {
      if (st.alive[j] == 0 || level.arrows[j].kind != Kind.spark || isLocked(level, st, j)) continue;
      final tr = traceArrow(level, s, st, occ, j);
      if (tr.ok) {
        depth++;
        _clearArrow(level, st, j, events, tr, depth);
        fired = true;
        break;
      }
    }
    if (!fired) return depth;
  }
}

/// Attempt to launch arrow i.
MoveOutcome applyMove(Level level, StaticBoard s, PlayState st, int i) {
  if (st.alive[i] == 0) return MoveOutcome(MoveResult.invalid, st);
  if (isLocked(level, st, i)) return MoveOutcome(MoveResult.locked, st);
  final occ = occupancy(level, st);
  final tr = traceArrow(level, s, st, occ, i);
  if (!tr.ok) return MoveOutcome(MoveResult.blocked, st, trace: tr);
  final ns = st.clone();
  final events = <GameEvent>[];
  _clearArrow(level, ns, i, events, tr, 0);
  _tick(level, ns, events);
  final chain = _resolveChains(level, s, ns, events);
  return MoveOutcome(MoveResult.cleared, ns, events: events, trace: tr, chain: chain);
}

bool isSolved(PlayState st) => st.remaining == 0;

bool isStuck(Level level, StaticBoard s, PlayState st) =>
    st.remaining > 0 && legalMoves(level, s, st).isEmpty;
