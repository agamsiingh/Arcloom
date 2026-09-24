// Ad flow regression tests (policy + orchestration, with a fake SDK backend).
import 'dart:convert';

import 'package:arcloom/services/ads/ad_service.dart';
import 'package:arcloom/services/storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime(2026, 9, 24, 12));

  group('rewarded', () {
    test('grants the reward only when the SDK reports it was earned', () async {
      final t = TestServices(clock: clock);
      await t.ads.start();
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.earned);
      expect(t.backend.shown, ['rewarded']);
      expect(t.store.data.ads.rewardedCount, 1);

      t.backend.earnReward = false; // player closed the ad early
      expect(await t.ads.showRewarded(RewardPlacement.continueRun), RewardOutcome.dismissed);
      expect(t.store.data.ads.rewardedCount, 1, reason: 'no reward, no cap usage');
    });

    test('uses the configured (test) rewarded unit and preloads the next ad', () async {
      final t = TestServices(clock: clock);
      await t.ads.start();
      await t.ads.showRewarded(RewardPlacement.hint);
      await Future<void>.delayed(Duration.zero);
      final rewardedLoads = t.backend.loads.where((l) => l.startsWith('rewarded:')).toList();
      expect(rewardedLoads.length, greaterThanOrEqualTo(2), reason: 'reload after show');
      expect(rewardedLoads.first, 'rewarded:${testAdConfig().units.rewarded}');
    });

    test('no fill / offline resolves as unavailable without blocking', () async {
      final t = TestServices(clock: clock);
      t.backend.fill = false;
      await t.ads.start();
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.unavailable);
    });

    test('a stalled load times out instead of hanging the game', () async {
      final t = TestServices(clock: clock);
      t.backend.hangLoads = true;
      await t.ads.start();
      final sw = Stopwatch()..start();
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.unavailable);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('SDK init failure or denied consent never throws', () async {
      final a = TestServices(clock: clock)..backend.initThrows = true;
      await a.ads.start();
      expect(await a.ads.showRewarded(RewardPlacement.hint), RewardOutcome.unavailable);
      final b = TestServices(clock: clock)..backend.initResult = false;
      await b.ads.start();
      expect(b.ads.sdkReady, isFalse);
      expect(await b.ads.showRewarded(RewardPlacement.continueRun), RewardOutcome.unavailable);
    });

    test('show failure is reported as dismissed and the ad is not reused', () async {
      final t = TestServices(clock: clock)..backend.showFails = true;
      await t.ads.start();
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.dismissed);
    });

    test('daily cap of rewarded ads resets the next day', () async {
      final t = TestServices(clock: clock);
      await t.ads.start();
      for (var i = 0; i < AdService.rewardedDailyCap; i++) {
        expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.earned);
      }
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.unavailable);
      now = now.add(const Duration(days: 1));
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.earned);
    });
  });

  group('ad-free purchasers', () {
    test('never see any ad; rewarded perks are instant', () async {
      final t = TestServices(data: SaveData()..adFree = true, clock: clock);
      await t.ads.start();
      expect(t.backend.initCalls, 0, reason: 'SDK is not even initialised');
      expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.earned);
      expect(await t.ads.showRewarded(RewardPlacement.continueRun), RewardOutcome.earned);
      for (var i = 0; i < 10; i++) {
        await t.ads.onLevelCompleted();
      }
      now = now.add(const Duration(hours: 1));
      expect(await t.ads.maybeShowInterstitial(), isFalse);
      expect(t.backend.shown, isEmpty);
      expect(t.backend.loads, isEmpty);
    });

    test('buying ad-free mid-session stops ads immediately', () async {
      final t = TestServices(clock: clock);
      await t.ads.start();
      await t.purchases.grantAdFree();
      t.ads.onAdFreeUnlocked();
      for (var i = 0; i < 6; i++) {
        await t.ads.onLevelCompleted();
      }
      now = now.add(const Duration(minutes: 5));
      expect(await t.ads.maybeShowInterstitial(), isFalse);
      expect(t.store.data.hints, 3 + 10, reason: 'supporter bonus hints');
    });
  });

  test('unconfigured platform (iOS placeholders) disables ads entirely', () async {
    final t = TestServices(config: testAdConfig(platform: 'ios', release: true), clock: clock);
    expect(t.ads.canOfferRewarded, isFalse);
    await t.ads.start();
    expect(t.backend.initCalls, 0);
    expect(await t.ads.showRewarded(RewardPlacement.hint), RewardOutcome.unavailable);
    expect(await t.ads.maybeShowInterstitial(), isFalse);
  });

  group('interstitial pacing', () {
    Future<TestServices> ready() async {
      final t = TestServices(clock: clock);
      await t.ads.start();
      await Future<void>.delayed(Duration.zero); // let preloads land
      return t;
    }

    test('only after the target number (3–5) of completed levels', () async {
      final t = await ready();
      t.store.data.ads.interstitialTarget = 4;
      now = now.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        await t.ads.onLevelCompleted();
        expect(await t.ads.maybeShowInterstitial(), isFalse, reason: 'after ${i + 1} levels');
      }
      await t.ads.onLevelCompleted();
      expect(await t.ads.maybeShowInterstitial(), isTrue);
      expect(t.backend.shown, ['interstitial']);
      final a = t.store.data.ads;
      expect(a.levelsSinceInterstitial, 0);
      expect(a.interstitialTarget, inInclusiveRange(3, 5));
    });

    test('never twice within the minimum gap', () async {
      final t = await ready();
      t.store.data.ads.interstitialTarget = 3;
      now = now.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        await t.ads.onLevelCompleted();
      }
      expect(await t.ads.maybeShowInterstitial(), isTrue);
      await Future<void>.delayed(Duration.zero);
      t.store.data.ads.interstitialTarget = 3;
      for (var i = 0; i < 3; i++) {
        await t.ads.onLevelCompleted();
      }
      now = now.add(const Duration(seconds: 30));
      expect(await t.ads.maybeShowInterstitial(), isFalse, reason: 'too soon');
      now = now.add(AdService.minInterstitialGap);
      expect(await t.ads.maybeShowInterstitial(), isTrue);
    });

    test('never immediately after a mistake', () async {
      final t = await ready();
      t.store.data.ads.interstitialTarget = 3;
      now = now.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        await t.ads.onLevelCompleted();
      }
      expect(await t.ads.maybeShowInterstitial(lastMistakeAt: now.subtract(const Duration(seconds: 2))), isFalse);
      expect(await t.ads.maybeShowInterstitial(lastMistakeAt: now.subtract(const Duration(seconds: 30))), isTrue);
    });

    test('an unloaded interstitial is skipped, never waited for', () async {
      final t = TestServices(clock: clock)..backend.fill = false;
      await t.ads.start();
      t.store.data.ads.interstitialTarget = 3;
      now = now.add(const Duration(minutes: 10));
      for (var i = 0; i < 3; i++) {
        await t.ads.onLevelCompleted();
      }
      final sw = Stopwatch()..start();
      expect(await t.ads.maybeShowInterstitial(), isFalse);
      expect(sw.elapsedMilliseconds, lessThan(100));
      expect(t.store.data.ads.levelsSinceInterstitial, 3, reason: 'still due at the next break');
    });

    test('pacing survives an app restart (persisted in the save)', () async {
      final t = await ready();
      await t.ads.onLevelCompleted();
      await t.ads.onLevelCompleted();
      final reloaded = Store.decode(jsonEncode(t.store.data.toJson()));
      expect(reloaded.ads.levelsSinceInterstitial, 2);
    });
  });
}
