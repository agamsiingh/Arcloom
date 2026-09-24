// Migration regression: the Dart engine must reproduce the PWA's JS engine exactly.
// Fixtures are produced by `node scripts/export_parity_fixtures.mjs` (repo root).
import 'dart:convert';
import 'dart:io';

import 'package:arcloom/core/codec.dart';
import 'package:arcloom/core/generator.dart';
import 'package:arcloom/core/levels.dart';
import 'package:arcloom/core/model.dart';
import 'package:arcloom/core/rng.dart';
import 'package:arcloom/core/solver.dart';
import 'package:arcloom/game/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync()) as Map<String, dynamic>;

  test('RNG streams are bit-identical to JS', () {
    (fx['rng'] as Map).forEach((seed, values) {
      final r = Rng(int.parse(seed as String));
      for (final v in values as List) {
        expect(r.float(), (v as num).toDouble(), reason: 'seed $seed');
      }
    });
    (fx['hash'] as Map).forEach((s, h) => expect(hashString(s as String), h, reason: s));
  });

  test('level parameters match for all 150 levels', () {
    (fx['params'] as Map).forEach((n, p) {
      final d = paramsFor(int.parse(n as String));
      final m = p as Map;
      expect([d.w, d.h, d.seed, d.minLen, d.maxLen], [m['w'], m['h'], m['seed'], m['minLen'], m['maxLen']], reason: 'L$n');
      expect(d.density, closeTo((m['density'] as num).toDouble(), 0), reason: 'L$n density');
      expect(d.turn, closeTo((m['turn'] as num).toDouble(), 0), reason: 'L$n turn');
      expect(d.feat.toJson(), Map<String, int>.from((m['feat'] as Map).map((k, v) => MapEntry(k as String, v as int)))
        ..removeWhere((_, v) => v == 0), reason: 'L$n feat');
    });
  });

  test('all 150 campaign levels are identical to the PWA', () {
    (fx['levels'] as Map).forEach((n, enc) {
      expect(encodeLevel(getLevel(int.parse(n as String))), enc, reason: 'L$n');
    });
  });

  test('the Dart generator reproduces baked levels from their seeds', () {
    (fx['generated'] as Map).forEach((n, enc) {
      expect(encodeLevel(generateLevel(paramsFor(int.parse(n as String)))), enc, reason: 'L$n');
    });
  });

  test('daily puzzles are identical to the PWA for 45 dates', () {
    (fx['dailies'] as Map).forEach((key, enc) {
      expect(encodeLevel(getDailyLevel(key as String)), enc, reason: key);
    });
  });

  test('solver explores identically (same moves, same node count)', () {
    (fx['solver'] as Map).forEach((n, r) {
      final l = getLevel(int.parse(n as String));
      final res = solve(l, buildStatic(l), initialState(l), maxNodes: 200000);
      final m = r as Map;
      expect(res.solved, m['solved'], reason: 'L$n');
      expect(res.moves, List<int>.from(m['moves'] as List), reason: 'L$n');
      expect(res.nodes, m['nodes'], reason: 'L$n nodes');
    });
  });

  test('session scoring, combos, hearts and results match', () {
    (fx['sessions'] as Map).forEach((key, rec) {
      final parts = (key as String).split('-');
      final l = getLevel(int.parse(parts[0]));
      final s = Session(l, mode: parts[1] == 'zen' ? GameMode.zen : GameMode.challenge);
      final r = rec as Map;
      var t = 1000;
      for (final step in r['log'] as List) {
        final e = step as List;
        final i = e[1] as int;
        if (e[0] == 'blocked') {
          expect(s.tap(i, t).result.name, 'blocked', reason: key);
          expect(s.hearts, e[2], reason: '$key hearts');
          continue;
        }
        t += (i % 3) * 1400 + 300;
        final out = s.tap(i, t);
        expect([out.result.name, out.gained, s.mult, s.score, out.chain], [e[0], e[2], e[3], e[4], e[5]],
            reason: '$key arrow $i');
      }
      expect(s.status.name, r['status'], reason: key);
      expect(s.hearts, r['hearts'], reason: key);
      expect(s.results().toJson(), Map<String, dynamic>.from(r['results'] as Map), reason: key);
    });
  });
}
