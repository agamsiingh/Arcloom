// arcloom — entry point. Wires production services, then starts the UI.
// Audio, store and ads initialise without blocking the first frame; the game is
// fully playable offline and without ads.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/ad_config.dart';
import 'services/ads/ad_service.dart';
import 'services/ads/admob_backend.dart';
import 'services/audio.dart';
import 'services/haptics.dart';
import 'services/purchases.dart';
import 'services/services.dart';
import 'services/storage.dart';

/// Creates the production service graph (real AdMob, SoLoud, store, IAP).
/// Shared by [main] and the on-device integration test.
Future<Services> bootstrap() async {
  final store = await Store.open();
  final audio = GameAudio(SoloudBackend());
  final ads = AdService(backend: AdMobBackend(), config: await AdConfig.load(), store: store);
  final purchases = PurchaseService(store)..onEntitlementGranted = ads.onAdFreeUnlocked;
  Services.I = Services(store: store, audio: audio, haptics: Haptics(), ads: ads, purchases: purchases)..applySettings();
  return Services.I;
}

/// Starts the non-blocking background services after the UI is up.
void startBackgroundServices(Services sv) {
  unawaited(sv.audio.backend.init().then((_) => sv.applySettings()));
  unawaited(sv.purchases.init());
  // Consent (UMP) + SDK start happen after the first frame and never block play.
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(sv.ads.start()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final sv = await bootstrap();
  runApp(const ArcloomApp());
  startBackgroundServices(sv);
}
