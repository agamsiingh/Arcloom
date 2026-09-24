// Test doubles and service wiring shared by the Flutter test suite.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arcloom/config/ad_config.dart';
import 'package:arcloom/services/ads/ad_service.dart';
import 'package:arcloom/services/audio.dart';
import 'package:arcloom/services/haptics.dart';
import 'package:arcloom/services/purchases.dart';
import 'package:arcloom/services/services.dart';
import 'package:arcloom/services/storage.dart';

/// Scriptable ad backend: controls init, fill, reward and failures.
class FakeAdBackend implements AdBackend {
  bool initResult = true;
  bool initThrows = false;
  bool fill = true;
  bool earnReward = true;
  bool hangLoads = false;
  bool showFails = false;
  int initCalls = 0;
  final List<String> loads = [];
  final List<String> shown = [];

  @override
  Future<bool> initialize() async {
    initCalls++;
    if (initThrows) throw StateError('SDK exploded');
    return initResult;
  }

  Future<LoadedAd?> _load(String kind, String unit) {
    loads.add('$kind:$unit');
    if (hangLoads) return Completer<LoadedAd?>().future; // never completes (offline stall)
    return Future.value(fill ? _FakeAd(this, kind) : null);
  }

  @override
  Future<LoadedAd?> loadRewarded(String unitId) => _load('rewarded', unitId);
  @override
  Future<LoadedAd?> loadInterstitial(String unitId) => _load('interstitial', unitId);
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
}

class _FakeAd implements LoadedAd {
  _FakeAd(this.backend, this.kind);
  final FakeAdBackend backend;
  final String kind;
  bool disposed = false;

  @override
  Future<bool> show() async {
    if (backend.showFails) throw StateError('failed to show');
    backend.shown.add(kind);
    return kind == 'rewarded' ? backend.earnReward : true;
  }

  @override
  void dispose() => disposed = true;
}

Map<String, dynamic> loadAdJson() =>
    jsonDecode(File('config/admob.json').readAsStringSync()) as Map<String, dynamic>;

AdConfig testAdConfig({String platform = 'android', bool release = false}) =>
    AdConfig.resolve(loadAdJson(), platform: platform, release: release);

class TestServices {
  TestServices({SaveData? data, AdConfig? config, DateTime Function()? clock})
      : store = Store.memory(data),
        backend = FakeAdBackend(),
        audioBackend = SilentAudioBackend() {
    haptics = Haptics()..enabled = false;
    ads = AdService(
      backend: backend,
      config: config ?? testAdConfig(),
      store: store,
      clock: clock,
      loadTimeout: const Duration(milliseconds: 200),
    );
    purchases = PurchaseService(store);
    services = Services(store: store, audio: GameAudio(audioBackend), haptics: haptics, ads: ads, purchases: purchases);
    Services.I = services;
    services.applySettings();
    haptics.enabled = false; // platform haptic timers are irrelevant in tests
  }

  final Store store;
  final FakeAdBackend backend;
  final SilentAudioBackend audioBackend;
  late final Haptics haptics;
  late final AdService ads;
  late final PurchaseService purchases;
  late final Services services;
}
