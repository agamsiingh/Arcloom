// Google Mobile Ads (official SDK) implementation of AdBackend, including the
// User Messaging Platform (UMP) consent flow required for EEA/UK/CH users.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

class AdMobBackend implements AdBackend {
  @override
  Future<bool> initialize() async {
    await _gatherConsent();
    final can = await ConsentInformation.instance.canRequestAds();
    if (!can) return false;
    await MobileAds.instance.initialize();
    return true;
  }

  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        // Offline or misconfigured: fall back to any previously stored consent.
        debugPrint('Consent info update failed: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  @override
  Future<LoadedAd?> loadRewarded(String unitId) {
    final c = Completer<LoadedAd?>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => c.complete(_Rewarded(ad)),
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded failed to load: ${err.code} ${err.message}');
          c.complete(null);
        },
      ),
    );
    return c.future;
  }

  @override
  Future<LoadedAd?> loadInterstitial(String unitId) {
    final c = Completer<LoadedAd?>();
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => c.complete(_Interstitial(ad)),
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed to load: ${err.code} ${err.message}');
          c.complete(null);
        },
      ),
    );
    return c.future;
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() {
    final c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) => c.complete());
    return c.future;
  }
}

class _Rewarded implements LoadedAd {
  _Rewarded(this.ad);
  final RewardedAd ad;

  @override
  Future<bool> show() {
    final c = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!c.isCompleted) c.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (_, err) {
        debugPrint('Rewarded failed to show: ${err.message}');
        if (!c.isCompleted) c.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return c.future;
  }

  @override
  void dispose() => ad.dispose();
}

class _Interstitial implements LoadedAd {
  _Interstitial(this.ad);
  final InterstitialAd ad;

  @override
  Future<bool> show() {
    final c = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!c.isCompleted) c.complete(true);
      },
      onAdFailedToShowFullScreenContent: (_, err) {
        debugPrint('Interstitial failed to show: ${err.message}');
        if (!c.isCompleted) c.complete(false);
      },
    );
    ad.show();
    return c.future;
  }

  @override
  void dispose() => ad.dispose();
}
