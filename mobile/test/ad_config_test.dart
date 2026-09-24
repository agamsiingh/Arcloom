// AdMob configuration regression tests: debug uses Google test IDs, release uses the
// production IDs, iOS never reuses Android IDs, and no ID is hard-coded elsewhere.
import 'dart:io';

import 'package:arcloom/config/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _googleTestPublisher = 'ca-app-pub-3940256099942544';

/// A concrete AdMob app / ad-unit ID (not just the prefix).
final adIdPattern = RegExp(r'ca-app-pub-\d+[~/]\d+');

void main() {
  final json = loadAdJson();

  test('debug / profile builds use Google test ad IDs on both platforms', () {
    for (final platform in ['android', 'ios']) {
      final c = AdConfig.resolve(json, platform: platform, release: false);
      expect(c.isTest, isTrue);
      expect(c.enabled, isTrue);
      for (final id in [c.units.appId, c.units.rewarded, c.units.interstitial]) {
        expect(id, startsWith(_googleTestPublisher), reason: '$platform $id');
      }
    }
  });

  test('Android release uses the production IDs', () {
    final c = AdConfig.resolve(json, platform: 'android', release: true);
    expect(c.isTest, isFalse);
    expect(c.enabled, isTrue);
    expect(c.units.appId, 'ca-app-pub-4549935803099292~2218226887');
    expect(c.units.rewarded, 'ca-app-pub-4549935803099292/4053963447');
    expect(c.units.interstitial, 'ca-app-pub-4549935803099292/4719257986');
  });

  test('release build can be forced onto test units for QA', () {
    final c = AdConfig.resolve(json, platform: 'android', release: true, useTestAds: true);
    expect(c.isTest, isTrue);
    expect(c.units.rewarded, startsWith(_googleTestPublisher));
  });

  test('iOS release IDs are separate placeholders — never the Android IDs', () {
    final ios = AdConfig.resolve(json, platform: 'ios', release: true);
    final android = AdConfig.resolve(json, platform: 'android', release: true);
    expect(ios.enabled, isFalse, reason: 'placeholders disable ads until real iOS IDs are set');
    for (final id in [ios.units.appId, ios.units.rewarded, ios.units.interstitial]) {
      expect([android.units.appId, android.units.rewarded, android.units.interstitial], isNot(contains(id)));
    }
  });

  test('the hard-coding guard really detects IDs', () {
    expect(adIdPattern.hasMatch("const x = 'ca-app-pub-4549935803099292/4053963447';"), isTrue);
    expect(adIdPattern.hasMatch('android:value="ca-app-pub-3940256099942544~3347511713"'), isTrue);
    expect(adIdPattern.hasMatch("id.startsWith('ca-app-pub-')"), isFalse);
  });

  test('ad IDs are not hard-coded anywhere outside config/admob.json', () {
    final offenders = <String>[];
    final roots = [
      Directory('lib'),
      Directory('android/app/src'),
      Directory('ios/Runner'),
    ];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final f in root.listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll('\\', '/');
        if (!RegExp(r'\.(dart|kt|java|xml|plist|swift|m|h)$').hasMatch(p)) continue;
        if (adIdPattern.hasMatch(f.readAsStringSync())) offenders.add(p);
      }
    }
    expect(offenders, isEmpty);
  });

  test('Android Gradle injects the app ID from the central config', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('config/admob.json'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains(r'${admobAppId}'));
  });

  test('iOS xcconfigs are in sync with the central config', () {
    final debug = File('ios/Flutter/AdMob-Debug.xcconfig').readAsStringSync();
    final release = File('ios/Flutter/AdMob-Release.xcconfig').readAsStringSync();
    expect(debug, contains('ADMOB_APP_ID = ${AdConfig.resolve(json, platform: 'ios', release: false).units.appId}'));
    expect(release, contains('ADMOB_APP_ID = ${AdConfig.resolve(json, platform: 'ios', release: true).units.appId}'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains(r'$(ADMOB_APP_ID)'));
  });
}
