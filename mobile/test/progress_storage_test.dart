// Save persistence + progression regression tests.
import 'dart:convert';

import 'package:arcloom/core/levels.dart';
import 'package:arcloom/game/session.dart';
import 'package:arcloom/services/progress.dart';
import 'package:arcloom/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session wonSession(int n, {GameMode mode = GameMode.challenge}) {
  final s = Session(getLevel(n), mode: mode);
  var t = 0;
  while (s.status == SessionStatus.playing) {
    s.tap(s.findHint().move!, t += 5000);
  }
  return s;
}

void main() {
  test('save round-trips through JSON', () {
    final d = SaveData()
      ..unlocked = 12
      ..hints = 7
      ..adFree = true
      ..levels[3] = LevelRecord(3, 1200, true)
      ..seenTips.addAll({1, 11})
      ..achievements['first'] = 1;
    d.settings
      ..theme = 'amoled'
      ..mode = 'zen'
      ..textScale = 1.15;
    d.daily.done['2026-09-24'] = LevelRecord(2, 900, false);
    d.ads.levelsSinceInterstitial = 2;
    final back = Store.decode(jsonEncode(d.toJson()));
    expect(back.toJson(), d.toJson());
  });

  test('reads a save written by the PWA (same schema)', () {
    const pwa = '{"version":1,"levels":{"1":{"stars":3,"best":950,"perfect":true},"2":{"stars":2,"best":700,"perfect":false}},'
        '"unlocked":3,"hints":6,"adFree":false,"settings":{"theme":"dark","sound":false,"soundVolume":0.5,"music":true,'
        '"musicVolume":0.35,"haptics":true,"tapConfirm":true,"largeHitboxes":false,"reducedMotion":false,"highContrast":false,'
        '"textScale":1,"mode":"challenge"},"stats":{"totalScore":1650,"perfect":1,"zenWins":0,"challengeWins":2,"noHintWins":2,'
        '"maxCombo":2,"maxChain":0,"dailyCount":0,"mistakes":1,"launches":7},"daily":{"done":{},"streak":0,"best":0,"last":null},'
        '"achievements":{"first":1790000000000,"perfect1":1790000000001},"seenTips":{"1":1,"2":1},"rewardedToday":{"date":null,"count":0}}';
    final d = Store.decode(pwa);
    expect(d.levels[1]!.perfect, isTrue);
    expect(d.unlocked, 3);
    expect(d.settings.theme, 'dark');
    expect(d.settings.sound, isFalse);
    expect(d.settings.tapConfirm, isTrue);
    expect(d.stats.launches, 7);
    expect(d.seenTips, {1, 2});
  });

  test('corrupted or hostile saves fall back to safe defaults', () {
    expect(Store.decode('not json').unlocked, 1);
    expect(Store.decode('[1,2,3]').hints, 3);
    final d = Store.decode('{"unlocked":99999,"hints":-5,"settings":{"theme":"hacker","soundVolume":7},"levels":{"x":{},"4":"no"}}');
    expect(d.unlocked, 150);
    expect(d.hints, 0);
    expect(d.settings.theme, 'system');
    expect(d.settings.soundVolume, 1);
    expect(d.levels, isEmpty);
  });

  test('persists to and reloads from shared_preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await Store.open();
    store.data.hints = 42;
    store.data.levels[1] = LevelRecord(3, 800, true);
    await store.save();
    final reopened = await Store.open();
    expect(reopened.data.hints, 42);
    expect(reopened.data.levels[1]!.stars, 3);
  });

  test('winning a level unlocks the next, awards perfect hint + achievements', () {
    final d = SaveData();
    final s = wonSession(1);
    final rec = recordWin(d, levelId: 1, res: s.results(), session: s);
    expect(d.unlocked, 2);
    expect(d.levels[1]!.stars, 3);
    expect(rec.firstClear, isTrue);
    expect(rec.hints, perfectHintReward);
    expect(rec.achievements.map((a) => a.id), containsAll(['first', 'perfect1']));
    expect(d.hints, 3 + perfectHintReward + 1 + 1);
    final again = recordWin(d, levelId: 1, res: s.results(), session: s);
    expect(again.hints, 0, reason: 'perfect reward only once per level');
  });

  test('daily streak grows on consecutive days and resets after a gap', () {
    final d = SaveData();
    DateTime day(int n) => DateTime(2026, 9, n, 10);
    for (final n in [20, 21, 22]) {
      final s = wonSession(2);
      recordWin(d, dailyKey: dateKey(day(n)), res: s.results(), session: s, now: day(n));
    }
    expect(d.daily.streak, 3);
    expect(currentStreak(d, day(23)), 3, reason: 'still alive the next day');
    expect(currentStreak(d, day(25)), 0, reason: 'broken after a missed day');
    final s = wonSession(2);
    recordWin(d, dailyKey: dateKey(day(25)), res: s.results(), session: s, now: day(25));
    expect(d.daily.streak, 1);
    expect(d.daily.best, 3);
    expect(d.achievements.containsKey('streak3'), isTrue);
  });
}
