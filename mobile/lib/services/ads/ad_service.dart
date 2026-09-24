// Ad orchestration + pacing policy. SDK-agnostic (see AdBackend) so every rule
// here is unit tested with a fake backend.
//
// Rules:
//  * Rewarded: only when the player asks (hint or continue). Reward is granted
//    only if the SDK reports the reward was earned.
//  * Interstitial: only at natural breaks (leaving a level-complete screen),
//    after 3–5 completed levels, at most once per [minInterstitialGap], never
//    within [mistakeCooldown] of a mistake, never during gameplay.
//  * Ad-free purchasers never see any ad; rewarded perks are granted instantly.
//  * Any load/show failure (offline, no fill, SDK error) resolves quickly and
//    never blocks gameplay.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../config/ad_config.dart';
import '../storage.dart';

abstract class LoadedAd {
  /// Shows the ad. Rewarded: completes with true iff the reward was earned.
  /// Interstitial: completes with true once shown and dismissed.
  Future<bool> show();
  void dispose();
}

abstract class AdBackend {
  /// Gathers consent (UMP) and starts the SDK. Returns false if ads may not be requested.
  Future<bool> initialize();
  Future<LoadedAd?> loadRewarded(String unitId);
  Future<LoadedAd?> loadInterstitial(String unitId);
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

enum RewardPlacement { hint, continueRun }

enum RewardOutcome {
  /// Reward granted (ad watched to completion, or ad-free player).
  earned,

  /// Player closed the ad early — no reward.
  dismissed,

  /// No ad could be loaded/shown (offline, no fill, disabled, daily cap).
  unavailable,
}

class AdService extends ChangeNotifier {
  AdService({
    required this.backend,
    required this.config,
    required this.store,
    DateTime Function()? clock,
    math.Random? random,
    this.loadTimeout = const Duration(seconds: 8),
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? math.Random();

  static const int rewardedDailyCap = 10;
  static const Duration minInterstitialGap = Duration(seconds: 90);
  static const Duration mistakeCooldown = Duration(seconds: 5);

  final AdBackend backend;
  final AdConfig? config;
  final Store store;
  final DateTime Function() _clock;
  final math.Random _random;
  final Duration loadTimeout;

  bool _ready = false;
  bool _starting = false;
  LoadedAd? _rewarded;
  LoadedAd? _interstitial;
  Future<LoadedAd?>? _rewardedLoading;
  Future<LoadedAd?>? _interstitialLoading;
  bool _showing = false;

  bool get adFree => store.data.adFree;
  bool get sdkReady => _ready;
  bool get isShowing => _showing;
  bool get _configured => config?.enabled ?? false;

  /// Consent + SDK init + preload. Safe to call repeatedly; never throws.
  Future<void> start() async {
    if (_ready || _starting || adFree || !_configured) return;
    _starting = true;
    try {
      _ready = await backend.initialize();
      if (_ready) {
        unawaited(_preloadRewarded());
        unawaited(_preloadInterstitial());
      }
    } catch (e) {
      debugPrint('Ads init failed: $e');
      _ready = false;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  // ---- rewarded ------------------------------------------------------------------------

  String get _today {
    final d = _clock();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get rewardedLeftToday {
    final a = store.data.ads;
    if (a.rewardedDate != _today) return rewardedDailyCap;
    return math.max(0, rewardedDailyCap - a.rewardedCount);
  }

  bool get canOfferRewarded => adFree || (_configured && rewardedLeftToday > 0);

  Future<LoadedAd?> _preloadRewarded() {
    if (_rewarded != null) return Future.value(_rewarded);
    return _rewardedLoading ??= _load(() => backend.loadRewarded(config!.units.rewarded)).then((ad) {
      _rewarded = ad;
      _rewardedLoading = null;
      notifyListeners();
      return ad;
    });
  }

  Future<LoadedAd?> _preloadInterstitial() {
    if (_interstitial != null) return Future.value(_interstitial);
    return _interstitialLoading ??= _load(() => backend.loadInterstitial(config!.units.interstitial)).then((ad) {
      _interstitial = ad;
      _interstitialLoading = null;
      return ad;
    });
  }

  Future<LoadedAd?> _load(Future<LoadedAd?> Function() fn) async {
    try {
      return await fn().timeout(loadTimeout, onTimeout: () => null);
    } catch (e) {
      debugPrint('Ad load failed: $e');
      return null;
    }
  }

  /// Player-initiated rewarded ad. Never throws; completes quickly when no ad is available.
  Future<RewardOutcome> showRewarded(RewardPlacement placement) async {
    if (adFree) return RewardOutcome.earned;
    if (!_configured || rewardedLeftToday <= 0 || _showing) return RewardOutcome.unavailable;
    if (!_ready) await start();
    if (!_ready) return RewardOutcome.unavailable;
    final ad = _rewarded ?? await _preloadRewarded();
    if (ad == null) return RewardOutcome.unavailable;
    _rewarded = null;
    _showing = true;
    bool earned;
    try {
      earned = await ad.show();
    } catch (e) {
      debugPrint('Rewarded show failed: $e');
      earned = false;
    } finally {
      _showing = false;
      ad.dispose();
      unawaited(_preloadRewarded());
    }
    if (!earned) return RewardOutcome.dismissed;
    final a = store.data.ads;
    if (a.rewardedDate != _today) {
      a.rewardedDate = _today;
      a.rewardedCount = 0;
    }
    a.rewardedCount++;
    await store.save();
    return RewardOutcome.earned;
  }

  // ---- interstitial ------------------------------------------------------------------

  /// Call once per completed level (campaign or daily).
  Future<void> onLevelCompleted() async {
    store.data.ads.levelsSinceInterstitial++;
    await store.save();
    if (_ready && !adFree) unawaited(_preloadInterstitial());
  }

  /// Whether an interstitial may be shown right now at a natural break.
  bool interstitialDue({DateTime? lastMistakeAt}) {
    if (adFree || !_configured || !_ready || _showing) return false;
    final a = store.data.ads;
    if (a.levelsSinceInterstitial < a.interstitialTarget) return false;
    final now = _clock();
    if (now.millisecondsSinceEpoch - a.lastInterstitialMs < minInterstitialGap.inMilliseconds) return false;
    if (lastMistakeAt != null && now.difference(lastMistakeAt) < mistakeCooldown) return false;
    return true;
  }

  /// Shows an interstitial if one is due and loaded. Only call from a natural
  /// break (e.g. the player leaving the level-complete screen). Returns whether one was shown.
  Future<bool> maybeShowInterstitial({DateTime? lastMistakeAt}) async {
    if (!interstitialDue(lastMistakeAt: lastMistakeAt)) return false;
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_preloadInterstitial()); // not ready: skip this break, never wait
      return false;
    }
    _interstitial = null;
    _showing = true;
    var shown = false;
    try {
      shown = await ad.show();
    } catch (e) {
      debugPrint('Interstitial show failed: $e');
    } finally {
      _showing = false;
      ad.dispose();
    }
    if (shown) {
      final a = store.data.ads
        ..levelsSinceInterstitial = 0
        ..interstitialTarget = 3 + _random.nextInt(3)
        ..lastInterstitialMs = _clock().millisecondsSinceEpoch;
      debugPrint('Next interstitial after ${a.interstitialTarget} levels');
      await store.save();
    }
    unawaited(_preloadInterstitial());
    return shown;
  }

  /// Called after an ad-free purchase: drop anything preloaded.
  void onAdFreeUnlocked() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
    notifyListeners();
  }

  Future<bool> privacyOptionsRequired() async {
    if (!_configured) return false;
    try {
      return await backend.privacyOptionsRequired();
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    try {
      await backend.showPrivacyOptions();
    } catch (e) {
      debugPrint('Privacy options failed: $e');
    }
  }
}
