// Resolves which AdMob IDs to use. IDs live only in config/admob.json.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Force Google's test ad units even in a release build (internal QA builds):
/// flutter build appbundle --release --dart-define=ARCLOOM_TEST_ADS=true
const bool forceTestAds = bool.fromEnvironment('ARCLOOM_TEST_ADS');

class AdUnits {
  const AdUnits({required this.appId, required this.rewarded, required this.interstitial});

  final String appId;
  final String rewarded;
  final String interstitial;

  static bool _valid(String id) => id.startsWith('ca-app-pub-') && !id.contains('REPLACE');

  bool get isConfigured => _valid(appId) && _valid(rewarded) && _valid(interstitial);

  static AdUnits fromJson(Map<String, dynamic> j) => AdUnits(
        appId: '${j['appId'] ?? ''}',
        rewarded: '${j['rewarded'] ?? ''}',
        interstitial: '${j['interstitial'] ?? ''}',
      );
}

class AdConfig {
  const AdConfig({required this.units, required this.isTest, required this.platform});

  final AdUnits units;
  final bool isTest;
  final String platform; // android | ios

  bool get enabled => units.isConfigured;

  /// Pure resolution logic (unit tested): release builds get production IDs unless
  /// [useTestAds] is set; every other build gets Google's test IDs.
  static AdConfig resolve(Map<String, dynamic> json, {required String platform, required bool release, bool useTestAds = false}) {
    final test = !release || useTestAds;
    final section = (json[test ? 'test' : 'release'] as Map?)?.cast<String, dynamic>() ?? const {};
    final p = (section[platform] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdConfig(units: AdUnits.fromJson(p), isTest: test, platform: platform);
  }

  static Future<AdConfig?> load() async {
    final String platform;
    if (defaultTargetPlatform == TargetPlatform.android) {
      platform = 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = 'ios';
    } else {
      return null; // ads only on mobile
    }
    try {
      final json = jsonDecode(await rootBundle.loadString('config/admob.json')) as Map<String, dynamic>;
      return resolve(json, platform: platform, release: kReleaseMode, useTestAds: forceTestAds);
    } catch (e) {
      debugPrint('AdMob config unavailable: $e');
      return null;
    }
  }
}
