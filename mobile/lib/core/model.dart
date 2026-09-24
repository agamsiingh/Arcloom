// Level data model, static board lookup tables and mutable play state.
// Port of js/core/model.js.
import 'dart:typed_data';

const List<int> dx = [0, 1, 0, -1];
const List<int> dy = [-1, 0, 1, 0];
const Map<String, int> dirOf = {'U': 0, 'R': 1, 'D': 2, 'L': 3};

enum Kind {
  normal, // plain arrow
  rotator, // single-cell, turns clockwise after every player clear
  spark, // launches itself the moment its lane opens (chain reactions)
  switcher, // flips which colour barriers are raised
  ghost, // phases through other arrows, still stopped by stone & barriers
}

Kind kindFromName(String? s) => switch (s) {
      'rotator' => Kind.rotator,
      'spark' => Kind.spark,
      'switch' => Kind.switcher,
      'ghost' => Kind.ghost,
      _ => Kind.normal,
    };

// Static cell types
const int tEmpty = 0;
const int tWall = 1;
const int tPortal = 2;
const int tGate = 3;
const int tCwall = 4;

typedef Cell = (int, int);

class Arrow {
  Arrow({required this.cells, required this.dir, this.kind = Kind.normal, this.lock = 0});

  /// Ordered tail -> head.
  final List<Cell> cells;
  final int dir;
  Kind kind;
  int lock;

  Cell get head => cells.last;
}

class Gate {
  const Gate(this.x, this.y, this.dir);
  final int x, y, dir;
}

class ColorWall {
  const ColorWall(this.x, this.y, this.c);
  final int x, y, c;
}

class Blocker {
  const Blocker(this.track);
  final List<Cell> track;
}

class Level {
  Level({
    required this.id,
    required this.w,
    required this.h,
    required this.arrows,
    this.name = '',
    this.tip,
    List<Cell>? walls,
    List<(Cell, Cell)>? portals,
    List<Gate>? gates,
    List<ColorWall>? cwalls,
    List<Blocker>? blockers,
  })  : walls = walls ?? [],
        portals = portals ?? [],
        gates = gates ?? [],
        cwalls = cwalls ?? [],
        blockers = blockers ?? [];

  Object id; // int for campaign levels, 'daily-YYYY-MM-DD' for dailies
  String name;
  String? tip;
  int chapter = 0;
  final int w, h;
  List<Arrow> arrows;
  final List<Cell> walls;
  final List<(Cell, Cell)> portals;
  final List<Gate> gates;
  final List<ColorWall> cwalls;
  final List<Blocker> blockers;
}

/// Hand-authored arrow: tail cell `at`, path of moves `p` (head points along the
/// final move) or explicit `d` for single-cell arrows.
class ArrowSpec {
  const ArrowSpec(this.at, {this.p = '', this.d, this.kind = 'normal', this.lock = 0});
  final Cell at;
  final String p;
  final String? d;
  final String kind;
  final int lock;

  Arrow build() {
    final cells = <Cell>[at];
    var dir = d != null ? dirOf[d]! : 0;
    for (final ch in p.split('')) {
      final m = dirOf[ch]!;
      final last = cells.last;
      cells.add((last.$1 + dx[m], last.$2 + dy[m]));
      dir = m;
    }
    return Arrow(cells: cells, dir: dir, kind: kindFromName(kind), lock: lock);
  }
}

class StaticBoard {
  StaticBoard(this.w, this.h, this.type, this.partner, this.gdir, this.ccol);
  final int w, h;
  final Uint8List type;
  final Int16List partner;
  final Int8List gdir;
  final Int8List ccol;
}

/// Precomputed per-cell lookup tables for the immutable parts of a level.
StaticBoard buildStatic(Level level) {
  final w = level.w, h = level.h, n = w * h;
  final type = Uint8List(n);
  final partner = Int16List(n)..fillRange(0, n, -1);
  final gdir = Int8List(n)..fillRange(0, n, -1);
  final ccol = Int8List(n)..fillRange(0, n, -1);
  for (final (x, y) in level.walls) {
    type[y * w + x] = tWall;
  }
  for (final (a, b) in level.portals) {
    final ia = a.$2 * w + a.$1;
    final ib = b.$2 * w + b.$1;
    type[ia] = tPortal;
    type[ib] = tPortal;
    partner[ia] = ib;
    partner[ib] = ia;
  }
  for (final g in level.gates) {
    type[g.y * w + g.x] = tGate;
    gdir[g.y * w + g.x] = g.dir;
  }
  for (final c in level.cwalls) {
    type[c.y * w + c.x] = tCwall;
    ccol[c.y * w + c.x] = c.c;
  }
  return StaticBoard(w, h, type, partner, gdir, ccol);
}

class PlayState {
  PlayState({
    required this.alive,
    required this.dirs,
    required this.color,
    required this.cleared,
    required this.bIdx,
    required this.bStep,
  });

  final Uint8List alive;
  final Int8List dirs;
  int color;
  int cleared;
  final Int8List bIdx;
  final Int8List bStep;

  PlayState clone() => PlayState(
        alive: Uint8List.fromList(alive),
        dirs: Int8List.fromList(dirs),
        color: color,
        cleared: cleared,
        bIdx: Int8List.fromList(bIdx),
        bStep: Int8List.fromList(bStep),
      );

  int get remaining {
    var r = 0;
    for (final a in alive) {
      r += a;
    }
    return r;
  }

  String get key {
    final sb = StringBuffer();
    for (final a in alive) {
      sb.write(a != 0 ? '1' : '0');
    }
    sb
      ..write('|')
      ..write(color);
    for (final d in dirs) {
      sb.write(d);
    }
    for (var b = 0; b < bIdx.length; b++) {
      sb
        ..write(',')
        ..write(bIdx[b])
        ..write(bStep[b] > 0 ? '+' : '-');
    }
    return sb.toString();
  }
}

PlayState initialState(Level level) {
  final n = level.arrows.length;
  final nb = level.blockers.length;
  return PlayState(
    alive: Uint8List(n)..fillRange(0, n, 1),
    dirs: Int8List.fromList([for (final a in level.arrows) a.dir]),
    color: 0,
    cleared: 0,
    bIdx: Int8List(nb),
    bStep: Int8List(nb)..fillRange(0, nb, 1),
  );
}

Cell blockerPos(Level level, PlayState st, int b) => level.blockers[b].track[st.bIdx[b]];

/// Cell -> occupant: arrow index, -2 for a drifting blocker, -1 empty.
Int16List occupancy(Level level, PlayState st) {
  final w = level.w;
  final occ = Int16List(w * level.h)..fillRange(0, w * level.h, -1);
  for (var i = 0; i < level.arrows.length; i++) {
    if (st.alive[i] == 0) continue;
    for (final (x, y) in level.arrows[i].cells) {
      occ[y * w + x] = i;
    }
  }
  for (var b = 0; b < level.blockers.length; b++) {
    final (x, y) = blockerPos(level, st, b);
    occ[y * w + x] = -2;
  }
  return occ;
}
