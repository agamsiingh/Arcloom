// Level catalog: chapters, difficulty curve, handcrafted + procedural levels, dailies.
// Port of js/core/levels.js. Campaign levels come from the PWA's baked data.
import 'dart:math' as math;

import 'baked_levels.dart';
import 'codec.dart';
import 'generator.dart';
import 'handcrafted.dart';
import 'model.dart';
import 'rng.dart';

const int levelCount = 150;

class Chapter {
  const Chapter(this.name, this.mech, this.blurb);
  final String name;
  final String? mech;
  final String blurb;
}

const List<Chapter> chapters = [
  Chapter('First Threads', null, 'Launch arrows in the right order'),
  Chapter('Stone', 'walls', 'Stone blocks that never move'),
  Chapter('Spin', 'rotators', 'Spinners turn after every launch'),
  Chapter('Locks', 'locks', 'Padlocks open after N launches'),
  Chapter('Portals', 'portals', 'Linked portals bend your lanes'),
  Chapter('Gates', 'gates', 'One-way gates'),
  Chapter('Tides', 'cwalls', 'Colour barriers & switches'),
  Chapter('Drifters', 'blockers', 'Drifting blockers on tracks'),
  Chapter('Sparks', 'sparks', 'Self-launching sparks & chains'),
  Chapter('Phantoms', 'ghosts', 'Phantoms pass through arrows'),
  Chapter('Grand Loom I', 'mix', 'Every mechanic, woven together'),
  Chapter('Grand Loom II', 'mix', 'Every mechanic, woven together'),
  Chapter('Grand Loom III', 'mix', 'Every mechanic, woven together'),
  Chapter('Grand Loom IV', 'mix', 'Every mechanic, woven together'),
  Chapter('Grand Loom V', 'mix', 'Every mechanic, woven together'),
];

const List<String> _mechOrder = [
  'walls', 'rotators', 'locks', 'portals', 'gates', 'cwalls', 'blockers', 'sparks', 'ghosts',
];

int chapterOf(int n) => math.min(chapters.length - 1, (n - 1) ~/ 10);

int _featureAmount(String mech, int area, int k, bool main) {
  final s = main ? 1 : 0.5;
  final scale = area / 49;
  final sq = math.sqrt(scale);
  switch (mech) {
    case 'walls':
      return ((2 + k / 3) * scale * s).round();
    case 'rotators':
      return math.max(1, ((1 + k / 4) * sq * s).round());
    case 'locks':
      return math.max(1, ((2 + k / 3) * sq * s).round());
    case 'portals':
      return math.max(1, ((1 + (area > 90 ? 1 : 0) + k / 6) * s).round());
    case 'gates':
      return math.max(1, ((2 + k / 3) * sq * s).round());
    case 'cwalls':
      return math.max(2, ((3 + k / 3) * sq * s).round());
    case 'blockers':
      return math.max(1, ((1 + (area > 100 ? 1 : 0)) * s).round());
    case 'sparks':
      return math.max(1, ((3 + k / 2) * sq * s).round());
    case 'ghosts':
      return math.max(1, ((1 + k / 4) * sq * s).round());
    default:
      return 0;
  }
}

void _applyMech(Feat feat, String mech, int area, int k, bool main) {
  final amt = _featureAmount(mech, area, k, main);
  feat[mech] = math.max(feat[mech], amt);
  if (mech == 'cwalls') feat.switches = math.max(feat.switches, main ? 1 + (k > 5 ? 1 : 0) : 1);
}

GenParams paramsFor(int n) {
  final ch = chapterOf(n);
  final k = (n - 1) % 10;
  final t = (n - 1) / (levelCount - 1);
  final rng = Rng(hashString('arcloom-params-$n'));
  final base = 5 + n ~/ 13 + (k >= 6 ? 1 : 0) - (k == 0 ? 1 : 0);
  final w = math.max(5, math.min(13, base));
  final h = math.max(5, math.min(17, base + 1 + n ~/ 35));
  final area = w * h;
  final feat = Feat();
  final chapter = chapters[ch];
  if (chapter.mech == 'mix') {
    final pool = rng.shuffle(List.of(_mechOrder));
    final count = 2 + math.min<int>(2, ((n - 100) / 18).floor()) + (k >= 8 ? 1 : 0);
    final chosen = pool.sublist(0, count);
    for (var i = 0; i < chosen.length; i++) {
      _applyMech(feat, chosen[i], area, k, i < 2);
    }
  } else if (chapter.mech != null) {
    _applyMech(feat, chapter.mech!, area, k, true);
    final learned = _mechOrder.sublist(0, _mechOrder.indexOf(chapter.mech!));
    for (final m in learned) {
      if (rng.chance(0.18 + k * 0.02)) _applyMech(feat, m, area, k, false);
    }
  }
  return GenParams(
    id: n,
    seed: hashString('arcloom-level-$n'),
    w: w,
    h: h,
    density: math.min(0.94, 0.74 + 0.18 * t + k * 0.004),
    minLen: n > 70 ? 3 : 2,
    maxLen: math.min(9, 3 + n ~/ 20),
    turn: 0.18 + 0.32 * t,
    feat: feat,
  );
}

final Map<Object, Level> _cache = {};

/// Campaign level n (1-based). Instances are cached and shared — callers must not mutate them.
Level getLevel(int n) {
  final cached = _cache[n];
  if (cached != null) return cached;
  final ch = chapterOf(n);
  final Level level;
  final hand = handcrafted[n];
  final baked = bakedLevels[n];
  if (hand != null) {
    level = hand.build(n);
  } else if (baked != null) {
    level = decodeLevel(baked, n);
  } else {
    level = generateLevel(paramsFor(n));
  }
  level
    ..id = n
    ..chapter = ch
    ..name = chapters[ch].name;
  _cache[n] = level;
  return level;
}

String dateKey([DateTime? d]) {
  d ??= DateTime.now();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

Level getDailyLevel(String key) {
  final cacheKey = 'daily-$key';
  final cached = _cache[cacheKey];
  if (cached != null) return cached;
  final seed = hashString('arcloom-daily-$key');
  final rng = Rng(seed);
  final w = rng.nextInt(7, 9);
  final h = w + rng.nextInt(1, 3);
  final feat = Feat();
  final shuffled = rng.shuffle(List.of(_mechOrder));
  final mechs = shuffled.sublist(0, rng.nextInt(2, 3));
  for (var i = 0; i < mechs.length; i++) {
    _applyMech(feat, mechs[i], w * h, 5, i == 0);
  }
  final level = generateLevel(GenParams(
    id: cacheKey,
    seed: seed,
    w: w,
    h: h,
    density: 0.86,
    minLen: 2,
    maxLen: 6,
    turn: 0.35,
    feat: feat,
  ));
  level
    ..id = cacheKey
    ..chapter = -1
    ..name = 'Daily Weave';
  _cache[cacheKey] = level;
  return level;
}
