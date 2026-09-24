// Procedural level generator — faithful port of js/core/generator.js.
// Arrows are placed in *reverse* solution order: each new arrow must have an open
// lane given everything already placed, so the static puzzle is solvable by
// construction. Dynamic mechanics are then verified with the solver.
// NOTE: every RNG call happens in exactly the same order as the JS version so
// seeds produce identical levels (see test/parity_test.dart).
import 'dart:math' as math;
import 'dart:typed_data';

import 'model.dart';
import 'rng.dart';
import 'rules.dart';
import 'solver.dart';

class Feat {
  Feat({
    this.walls = 0,
    this.portals = 0,
    this.gates = 0,
    this.cwalls = 0,
    this.blockers = 0,
    this.rotators = 0,
    this.locks = 0,
    this.sparks = 0,
    this.switches = 0,
    this.ghosts = 0,
  });

  int walls, portals, gates, cwalls, blockers, rotators, locks, sparks, switches, ghosts;

  Feat copyWith({int? rotators, int? blockers, int? switches}) => Feat(
        walls: walls,
        portals: portals,
        gates: gates,
        cwalls: cwalls,
        blockers: blockers ?? this.blockers,
        rotators: rotators ?? this.rotators,
        locks: locks,
        sparks: sparks,
        switches: switches ?? this.switches,
        ghosts: ghosts,
      );

  int operator [](String k) => switch (k) {
        'walls' => walls,
        'portals' => portals,
        'gates' => gates,
        'cwalls' => cwalls,
        'blockers' => blockers,
        'rotators' => rotators,
        'locks' => locks,
        'sparks' => sparks,
        'switches' => switches,
        'ghosts' => ghosts,
        _ => throw ArgumentError(k),
      };

  void operator []=(String k, int v) {
    switch (k) {
      case 'walls':
        walls = v;
      case 'portals':
        portals = v;
      case 'gates':
        gates = v;
      case 'cwalls':
        cwalls = v;
      case 'blockers':
        blockers = v;
      case 'rotators':
        rotators = v;
      case 'locks':
        locks = v;
      case 'sparks':
        sparks = v;
      case 'switches':
        switches = v;
      case 'ghosts':
        ghosts = v;
      default:
        throw ArgumentError(k);
    }
  }

  Map<String, int> toJson() => {
        for (final k in const [
          'walls', 'portals', 'gates', 'cwalls', 'blockers', 'rotators', 'locks', 'sparks', 'switches', 'ghosts',
        ])
          if (this[k] != 0) k: this[k],
      };
}

class GenParams {
  GenParams({
    required this.id,
    required this.seed,
    required this.w,
    required this.h,
    this.density = 0.85,
    this.minLen = 2,
    this.maxLen = 4,
    this.turn = 0.3,
    required this.feat,
  });

  final Object id;
  final int seed, w, h, minLen, maxLen;
  final double density, turn;
  final Feat feat;
}

Level generateLevel(GenParams opts) {
  final feat = opts.feat;
  final tries = <(Feat, int)>[
    (feat, 10),
    (feat.copyWith(rotators: math.min(feat.rotators, 2), blockers: math.min(feat.blockers, 1)), 10),
    (feat.copyWith(rotators: 0, blockers: 0, switches: 0), 30),
  ];
  var salt = 0;
  for (final (f, n) in tries) {
    for (var k = 0; k < n; k++) {
      final rng = Rng((opts.seed + salt++ * 7919) & 0xFFFFFFFF);
      final lvl = _buildOnce(rng, opts, f);
      if (_verify(lvl)) return lvl;
    }
  }
  throw StateError('Generator failed for seed ${opts.seed}');
}

bool _verify(Level level) {
  if (level.arrows.length < 2) return false;
  final s = buildStatic(level);
  final st = initialState(level);
  final hasDynamic = level.blockers.isNotEmpty ||
      level.arrows.any((a) => a.kind == Kind.rotator || a.kind == Kind.switcher);
  return solve(level, s, st, maxNodes: hasDynamic ? 2500 : 2000).solved;
}

Level _buildOnce(Rng rng, GenParams opts, Feat feat) {
  final w = opts.w, h = opts.h, n = w * h;
  final reserved = Uint8List(n);
  final trackCell = Uint8List(n);
  final level = Level(id: opts.id, w: w, h: h, arrows: []);

  Cell? inner(int margin) {
    for (var t = 0; t < 120; t++) {
      final x = rng.nextInt(margin, w - 1 - margin);
      final y = rng.nextInt(margin, h - 1 - margin);
      if (reserved[y * w + x] == 0) return (x, y);
    }
    return null;
  }

  void reserve(Cell c) => reserved[c.$2 * w + c.$1] = 1;

  for (var i = 0; i < feat.walls; i++) {
    final c = inner(1);
    if (c != null) {
      reserve(c);
      level.walls.add(c);
    }
  }
  for (var i = 0; i < feat.portals; i++) {
    final a = inner(1);
    if (a == null) break;
    reserve(a);
    Cell? b;
    for (var t = 0; t < 60 && b == null; t++) {
      final c = inner(1);
      if (c != null && (c.$1 - a.$1).abs() + (c.$2 - a.$2).abs() >= 3 && c.$1 != a.$1 && c.$2 != a.$2) b = c;
    }
    if (b == null) {
      reserved[a.$2 * w + a.$1] = 0;
      break;
    }
    reserve(b);
    level.portals.add((a, b));
  }
  for (var i = 0; i < feat.gates; i++) {
    final c = inner(1);
    if (c != null) {
      reserve(c);
      level.gates.add(Gate(c.$1, c.$2, rng.nextInt(0, 3)));
    }
  }
  for (var i = 0; i < feat.cwalls;) {
    final c = inner(1);
    if (c == null) break;
    final color = rng.nextInt(0, 1);
    final d = rng.nextInt(0, 3);
    final len = rng.nextInt(1, 3);
    for (var k = 0; k < len && i < feat.cwalls; k++) {
      final x = c.$1 + dx[d] * k;
      final y = c.$2 + dy[d] * k;
      if (x < 0 || y < 0 || x >= w || y >= h || reserved[y * w + x] != 0) break;
      reserve((x, y));
      level.cwalls.add(ColorWall(x, y, color));
      i++;
    }
  }
  for (var i = 0; i < feat.blockers; i++) {
    for (var t = 0; t < 40; t++) {
      final len = rng.nextInt(3, 4);
      final d = rng.nextInt(1, 2); // right or down
      final x0 = rng.nextInt(0, w - 1 - (d == 1 ? len - 1 : 0));
      final y0 = rng.nextInt(0, h - 1 - (d == 2 ? len - 1 : 0));
      final track = [for (var k = 0; k < len; k++) (x0 + dx[d] * k, y0 + dy[d] * k)];
      if (track.any((c) => reserved[c.$2 * w + c.$1] != 0)) continue;
      for (final c in track) {
        reserve(c);
        trackCell[c.$2 * w + c.$1] = 1;
      }
      level.blockers.add(Blocker(track));
      break;
    }
  }

  final s = buildStatic(level);
  final occ = Int16List(n)..fillRange(0, n, -1);
  bool isSpecialCell(int x, int y) {
    final c = y * w + x;
    return s.type[c] != tEmpty || trackCell[c] != 0;
  }

  var freeCount = 0;
  for (var c = 0; c < n; c++) {
    if (reserved[c] == 0) freeCount++;
  }
  final targetFill = (freeCount * opts.density).floor();
  var filled = 0;
  var fails = 0;
  var rotators = 0;
  final hasFeatureCells =
      level.portals.isNotEmpty || level.gates.isNotEmpty || level.cwalls.isNotEmpty || level.blockers.isNotEmpty;

  while (filled < targetFill && fails < 500) {
    final empties = <int>[
      for (var c = 0; c < n; c++)
        if (reserved[c] == 0 && occ[c] == -1) c,
    ];
    if (empties.isEmpty) break;
    final hc = rng.pick(empties);
    final hx = hc % w;
    final hy = (hc - hx) ~/ w;
    final makeRot = rotators < feat.rotators && rng.chance(0.3);
    final options = <(int, Ray, bool)>[];
    for (final d in rng.shuffle([0, 1, 2, 3])) {
      final ray = castRay(s, occ, hx, hy, d, 0, -1, false);
      if (!ray.ok) continue;
      final featured = ray.pts.any((p) => isSpecialCell(p.$1, p.$2));
      options.add((d, ray, featured));
    }
    if (options.isEmpty) {
      fails++;
      continue;
    }
    var pickOrder = options;
    if (hasFeatureCells && rng.chance(0.75)) {
      pickOrder = [...options.where((o) => o.$3), ...options.where((o) => !o.$3)];
    }
    var placed = false;
    for (final (d, ray, _) in pickOrder) {
      final raySet = {for (final p in ray.pts.skip(1)) p.$2 * w + p.$1};
      List<Cell> cells;
      if (makeRot) {
        cells = [(hx, hy)];
      } else {
        final len = rng.nextInt(opts.minLen, opts.maxLen);
        cells = _growBody(rng, w, h, hx, hy, d, len, opts.turn, occ, reserved, raySet);
        if (cells.length < math.max(2, math.min(opts.minLen, 3))) continue;
      }
      final idx = level.arrows.length;
      for (final (x, y) in cells) {
        occ[y * w + x] = idx;
      }
      level.arrows.add(Arrow(cells: cells, dir: d, kind: makeRot ? Kind.rotator : Kind.normal));
      filled += cells.length;
      if (makeRot) rotators++;
      placed = true;
      break;
    }
    if (!placed) fails++;
  }

  _assignSpecials(rng, level, feat);
  final order = rng.shuffle([for (var i = 0; i < level.arrows.length; i++) i]);
  level.arrows = [for (final i in order) level.arrows[i]];

  // Spark arrows must not launch before the player's first move.
  final s2 = buildStatic(level);
  final st = initialState(level);
  for (final i in legalMoves(level, s2, st)) {
    if (level.arrows[i].kind == Kind.spark) level.arrows[i].kind = Kind.normal;
  }
  return level;
}

List<Cell> _growBody(Rng rng, int w, int h, int hx, int hy, int d, int len, double turn, Int16List occ,
    Uint8List reserved, Set<int> raySet) {
  final body = <Cell>[(hx, hy)];
  final used = <int>{hy * w + hx};
  var seg = d;
  var cx = hx, cy = hy;
  while (body.length < len) {
    final sides = rng.shuffle([(seg + 1) % 4, (seg + 3) % 4]);
    final opts = body.length == 1
        ? [seg]
        : rng.chance(turn)
            ? [...sides, seg]
            : [seg, ...sides];
    var moved = false;
    for (final sd in opts) {
      final px = cx - dx[sd];
      final py = cy - dy[sd];
      if (px < 0 || py < 0 || px >= w || py >= h) continue;
      final c = py * w + px;
      if (reserved[c] != 0 || occ[c] != -1 || used.contains(c) || raySet.contains(c)) continue;
      body.add((px, py));
      used.add(c);
      seg = sd;
      cx = px;
      cy = py;
      moved = true;
      break;
    }
    if (!moved) break;
  }
  return body.reversed.toList();
}

class _PoolItem {
  _PoolItem(this.a, this.sol);
  final Arrow a;
  final int sol;
  bool used = false;
}

void _assignSpecials(Rng rng, Level level, Feat feat) {
  final n = level.arrows.length;
  // Placement index p is cleared at solution position n-1-p.
  final pool = rng.shuffle([
    for (var p = 0; p < n; p++)
      if (level.arrows[p].kind == Kind.normal) _PoolItem(level.arrows[p], n - 1 - p),
  ]);
  void take(int count, bool Function(_PoolItem) pred, void Function(_PoolItem) fn) {
    var k = 0;
    for (final o in pool) {
      if (k >= count) break;
      if (o.used || !pred(o)) continue;
      o.used = true;
      fn(o);
      k++;
    }
  }

  take(feat.locks, (o) => o.sol >= 2, (o) => o.a.lock = rng.nextInt(1, math.min(o.sol, 9)));
  take(feat.sparks, (o) => o.sol >= 1, (o) => o.a.kind = Kind.spark);
  take(feat.ghosts, (_) => true, (o) => o.a.kind = Kind.ghost);
  if (level.cwalls.isNotEmpty) take(math.max(1, feat.switches), (_) => true, (o) => o.a.kind = Kind.switcher);
}
