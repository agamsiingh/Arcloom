// On-device integration test with the REAL plugins: SoLoud audio, shared_preferences,
// and the Google Mobile Ads SDK using Google's test ad units (debug build).
// Run: flutter test integration_test -d <device>
import 'dart:convert';

import 'package:arcloom/app.dart';
import 'package:arcloom/game/board_widget.dart';
import 'package:arcloom/game/game_screen.dart';
import 'package:arcloom/game/session.dart';
import 'package:arcloom/main.dart';
import 'package:arcloom/services/storage.dart';
import 'package:arcloom/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> step(WidgetTester t, int ms) async {
  for (var e = 0; e < ms; e += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<bool> waitFor(WidgetTester t, bool Function() cond, {int seconds = 60}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (cond()) return true;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump();
  }
  return cond();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real device: play level 1, persist, audio + test ads work, back navigation', (t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final sv = await bootstrap();
    sv.store.data = SaveData();
    await t.pumpWidget(const ArcloomApp());
    startBackgroundServices(sv);
    await step(t, 500);
    expect(find.text('ARCLOOM'), findsOneWidget);

    // Audio engine (SoLoud) initialises with all assets.
    expect(await waitFor(t, () => SoLoud.instance.isInitialized, seconds: 20), isTrue, reason: 'SoLoud init');

    // Play level 1 through the UI.
    await t.tap(find.text('Play'));
    await step(t, 600);
    if (find.text('Got it').evaluate().isNotEmpty) {
      await t.tap(find.text('Got it'));
      await step(t, 400);
    }
    final g = t.state<GameScreenState>(find.byType(GameScreen));
    await step(t, 3000); // leave time for an external screenshot of the board
    while (g.session.status == SessionStatus.playing) {
      final m = g.session.findHint().move!;
      final a = g.level.arrows[m];
      final (x, y) = a.cells[(a.cells.length - 1) ~/ 2];
      await t.tapAt(t.getTopLeft(find.byType(BoardWidget)) + g.view.cellCenter(x, y));
      await step(t, 700);
    }
    await step(t, 2000);
    expect(find.text('Perfect Weave!'), findsOneWidget);

    // Progress is on disk (survives restarts).
    final saved = jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>;
    expect((saved['levels'] as Map)['1']['stars'], 3);
    expect(saved['unlocked'], 2);

    // Google Mobile Ads SDK: consent + init, then Google test units fill.
    final ads = sv.ads;
    expect(ads.config!.isTest, isTrue, reason: 'debug builds must use test IDs');
    expect(await waitFor(t, () => ads.sdkReady, seconds: 60), isTrue, reason: 'SDK ready');
    final rewarded = await t.runAsync(() => ads.backend.loadRewarded(ads.config!.units.rewarded));
    final interstitial = await t.runAsync(() => ads.backend.loadInterstitial(ads.config!.units.interstitial));
    debugPrint('INTEGRATION: rewarded loaded=${rewarded != null} interstitial loaded=${interstitial != null}');
    expect(rewarded, isNotNull, reason: 'test rewarded ad should fill (needs network)');
    expect(interstitial, isNotNull, reason: 'test interstitial should fill (needs network)');
    rewarded?.dispose();
    interstitial?.dispose();

    // Leave the result screen via "Levels", then Android back returns home.
    await t.tap(find.text('Levels'));
    await step(t, 800);
    await t.binding.handlePopRoute();
    await step(t, 800);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
