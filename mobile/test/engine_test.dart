// Engine tests — Dart ports of the PWA's tests/levels.test.mjs and tests/rules.test.mjs.
import 'package:arcloom/core/codec.dart';
import 'package:arcloom/core/levels.dart';
import 'package:arcloom/core/model.dart';
import 'package:arcloom/core/rules.dart';
import 'package:arcloom/core/solver.dart';
import 'package:arcloom/game/session.dart';
import 'package:flutter_test/flutter_test.dart';

Level make(int w, int h, List<ArrowSpec> arrows,
        {List<Cell> walls = const [], List<(Cell, Cell)> portals = const [], List<Gate> gates = const [],
        List<ColorWall> cwalls = const [], List<Blocker> blockers = const []}) =>
    Level(
      id: 't',
      w: w,
      h: h,
      arrows: [for (final a in arrows) a.build()],
      walls: List.of(walls),
      portals: List.of(portals),
      gates: List.of(gates),
      cwalls: List.of(cwalls),
      blockers: List.of(blockers),
    );

MoveOutcome move(Level l, PlayState st, int i) => applyMove(l, buildStatic(l), st, i);

void checkLevel(Level level) {
  final s = buildStatic(level);
  final st = initialState(level);
  final seen = <int>{};
  void mark(int x, int y, String what) {
    expect(x >= 0 && y >= 0 && x < level.w && y < level.h, isTrue, reason: '$what out of bounds in ${level.id}');
    expect(seen.add(y * level.w + x), isTrue, reason: 'overlap at $x,$y ($what) in ${level.id}');
  }

  for (final a in level.arrows) {
    for (final (x, y) in a.cells) {
      mark(x, y, 'arrow');
    }
  }
  for (final (x, y) in level.walls) {
    mark(x, y, 'wall');
  }
  for (final (a, b) in level.portals) {
    mark(a.$1, a.$2, 'portal');
    mark(b.$1, b.$2, 'portal');
  }
  for (final g in level.gates) {
    mark(g.x, g.y, 'gate');
  }
  for (final c in level.cwalls) {
    mark(c.x, c.y, 'cwall');
  }
  for (final b in level.blockers) {
    for (final (x, y) in b.track) {
      mark(x, y, 'track');
    }
  }
  for (final i in legalMoves(level, s, st)) {
    expect(level.arrows[i].kind, isNot(Kind.spark), reason: 'spark free at start in ${level.id}');
  }
  final r = solve(level, s, st, maxNodes: 200000);
  expect(r.solved, isTrue, reason: 'level ${level.id} unsolvable');
  var cur = st;
  for (final m in r.moves) {
    final res = applyMove(level, s, cur, m);
    expect(res.result, MoveResult.cleared);
    cur = res.st;
  }
  expect(cur.remaining, 0);
}

void main() {
  test('all 150 campaign levels are valid and solvable', () {
    for (var n = 1; n <= levelCount; n++) {
      checkLevel(getLevel(n));
    }
  });

  test('mechanics are introduced progressively', () {
    expect(paramsFor(5).feat.toJson(), isEmpty);
    expect(paramsFor(25).feat.rotators, greaterThan(0));
    expect(paramsFor(45).feat.portals, greaterThan(0));
    expect(paramsFor(85).feat.sparks, greaterThan(0));
    final big = getLevel(levelCount);
    expect(big.w * big.h, greaterThanOrEqualTo(150));
  });

  test('daily levels are deterministic and solvable', () {
    for (final key in ['2026-09-01', '2026-09-24', '2026-12-31', '2027-02-14']) {
      final a = getDailyLevel(key);
      checkLevel(a);
      expect(encodeLevel(a), encodeLevel(getDailyLevel(key)));
    }
  });

  test('an arrow is blocked by another arrow in its lane, then freed', () {
    final l = make(4, 3, [const ArrowSpec((0, 1), p: 'R'), const ArrowSpec((3, 2), p: 'U')]);
    final st = initialState(l);
    expect(move(l, st, 0).result, MoveResult.blocked);
    final r = move(l, st, 1);
    expect(r.result, MoveResult.cleared);
    expect(move(l, r.st, 0).result, MoveResult.cleared);
  });

  test('stone blocks forever; one-way gates only pass in their direction', () {
    final l = make(5, 2, [const ArrowSpec((0, 0), p: 'R'), const ArrowSpec((0, 1), p: 'R'), const ArrowSpec((4, 1), p: 'L')],
        walls: [(4, 0)], gates: [const Gate(2, 1, 1)]);
    final st = initialState(l);
    expect(move(l, st, 0).result, MoveResult.blocked);
    expect(move(l, st, 2).result, MoveResult.blocked);
    expect(move(l, st, 1).result, MoveResult.blocked);
  });

  test('portals continue the lane out of the twin', () {
    final l = make(5, 5, [const ArrowSpec((2, 3), p: 'U'), const ArrowSpec((4, 2), p: 'U')], portals: [((2, 0), (4, 3))]);
    final st = initialState(l);
    expect(move(l, st, 0).result, MoveResult.blocked);
    final r = move(l, st, 1);
    final r2 = move(l, r.st, 0);
    expect(r2.result, MoveResult.cleared);
    expect(r2.trace!.pts.any((p) => p.$3), isTrue);
  });

  test('locks open after N launches', () {
    final l = make(3, 3, [const ArrowSpec((0, 0), p: 'R', lock: 1), const ArrowSpec((0, 2), p: 'R')]);
    final st = initialState(l);
    expect(move(l, st, 0).result, MoveResult.locked);
    final r = move(l, st, 1);
    expect(r.events.whereType<UnlockEvent>().map((e) => e.i), [0]);
    expect(move(l, r.st, 0).result, MoveResult.cleared);
  });

  test('rotators turn clockwise; drifters step along their track', () {
    final l = make(5, 5, [const ArrowSpec((2, 2), d: 'U', kind: 'rotator'), const ArrowSpec((4, 0), p: 'D')],
        blockers: [const Blocker([(0, 4), (1, 4), (2, 4)])]);
    final r = move(l, initialState(l), 1);
    expect(r.st.dirs[0], 1);
    expect(r.st.bIdx[0], 1);
  });

  test('switch arrows flip which colour barrier is raised', () {
    final l = make(4, 3, [const ArrowSpec((0, 0), p: 'R'), const ArrowSpec((0, 2), p: 'R', kind: 'switch')],
        cwalls: [const ColorWall(2, 0, 0)]);
    final st = initialState(l);
    expect(move(l, st, 0).result, MoveResult.blocked);
    final r = move(l, st, 1);
    expect(r.st.color, 1);
    expect(move(l, r.st, 0).result, MoveResult.cleared);
  });

  test('spark arrows chain-launch once their lane opens', () {
    final l = make(4, 4, [
      const ArrowSpec((3, 0), p: 'DDD'),
      const ArrowSpec((0, 1), p: 'R', kind: 'spark'),
      const ArrowSpec((2, 3), p: 'U', kind: 'spark'),
    ]);
    final r = move(l, initialState(l), 0);
    expect(r.chain, 2);
    expect(r.st.remaining, 0);
  });

  test('phantoms pass through arrows but not stone', () {
    final open = make(5, 1, [const ArrowSpec((0, 0), p: 'R', kind: 'ghost'), const ArrowSpec((3, 0), d: 'U')]);
    expect(move(open, initialState(open), 0).result, MoveResult.cleared);
    final normal = make(5, 1, [const ArrowSpec((0, 0), p: 'R'), const ArrowSpec((3, 0), d: 'U')]);
    expect(move(normal, initialState(normal), 0).result, MoveResult.blocked);
    final stone = make(5, 1, [const ArrowSpec((0, 0), p: 'R', kind: 'ghost')], walls: [(3, 0)]);
    expect(move(stone, initialState(stone), 0).result, MoveResult.blocked);
  });

  test('stuck detection', () {
    final l = make(3, 1, [const ArrowSpec((0, 0), d: 'R'), const ArrowSpec((2, 0), d: 'L')]);
    expect(isStuck(l, buildStatic(l), initialState(l)), isTrue);
  });

  test('session: hearts, combos, undo, hints, zen never fails, stars', () {
    final level = getLevel(2);
    final s = Session(level);
    expect(s.tap(0, 0).result, MoveResult.blocked);
    expect(s.hearts, 2);
    var t = 0;
    for (var k = 0; k < 20 && s.status == SessionStatus.playing; k++) {
      s.tap(s.findHint().move!, t += 100);
    }
    expect(s.status, SessionStatus.won);
    expect(s.maxMultReached, greaterThanOrEqualTo(2));
    expect(s.results().stars, 2);

    final z = Session(level, mode: GameMode.zen);
    for (var k = 0; k < 5; k++) {
      z.tap(0, 0);
    }
    expect(z.status, SessionStatus.playing);
    z.tap(z.findHint().move!, 0);
    expect(z.undo(), isTrue);
    expect(z.left, level.arrows.length);

    final c = Session(level);
    for (var k = 0; k < 3; k++) {
      c.tap(0, 0);
    }
    expect(c.status, SessionStatus.failed);
    c.continueRun(2);
    expect([c.status, c.hearts], [SessionStatus.playing, 2]);
  });

  test('codec round-trips levels', () {
    for (final n in [5, 47, 88, 150]) {
      final l = getLevel(n);
      expect(encodeLevel(decodeLevel(encodeLevel(l), n)), encodeLevel(l));
    }
  });
}
