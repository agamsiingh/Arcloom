// End-to-end widget tests: real UI + real engine, fake ad/audio backends.
// Plays levels by tapping arrows on the board and checks ad placement rules.
import 'package:arcloom/app.dart';
import 'package:arcloom/core/levels.dart';
import 'package:arcloom/game/board_widget.dart';
import 'package:arcloom/game/game_screen.dart';
import 'package:arcloom/game/session.dart';
import 'package:arcloom/services/storage.dart';
import 'package:arcloom/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Advances time frame-by-frame (50 ms frames) so routes, dialogs and timers settle.
Future<void> step(WidgetTester t, int ms) async {
  for (var e = 0; e < ms; e += 50) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

GameScreenState game(WidgetTester t) => t.state<GameScreenState>(find.byType(GameScreen));

/// Taps an arrow's middle cell on screen, exactly as a player would.
Future<void> tapArrow(WidgetTester t, int i) async {
  final g = game(t);
  final a = g.level.arrows[i];
  final (x, y) = a.cells[(a.cells.length - 1) ~/ 2];
  final origin = t.getTopLeft(find.byType(BoardWidget));
  await t.tapAt(origin + g.view.cellCenter(x, y));
  await step(t, 50);
}

/// Plays the current level to completion with solver hints (no hint cost), via taps.
Future<void> solveByTapping(WidgetTester t) async {
  for (var guard = 0; guard < 80 && game(t).session.status == SessionStatus.playing; guard++) {
    final m = game(t).session.findHint().move!;
    await tapArrow(t, m);
    await step(t, 900); // > combo window keeps scoring simple
  }
  await step(t, 700); // win dialog delay
  await step(t, 1200); // star animation
}

Future<void> boot(WidgetTester t, TestServices s) async {
  t.view.physicalSize = const Size(1080, 2220);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  await s.ads.start();
  await t.pumpWidget(const ArcloomApp());
  await step(t, 300);
}

Future<void> closeTip(WidgetTester t) async {
  if (find.text('Got it').evaluate().isNotEmpty) {
    await t.tap(find.text('Got it'));
    await step(t, 400);
  }
}

void main() {
  testWidgets('home → level 1 → win by tapping → next level; no interstitial yet', (t) async {
    final s = TestServices();
    await boot(t, s);
    expect(find.text('ARCLOOM'), findsOneWidget);
    await t.tap(find.text('Play'));
    await step(t, 400);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Welcome to Arcloom'), findsOneWidget);
    await closeTip(t);

    await solveByTapping(t);
    expect(find.text('Perfect Weave!'), findsOneWidget);
    expect(s.store.data.levels[1]!.stars, 3);
    expect(s.store.data.unlocked, 2);
    expect(s.audioBackend.played, containsAll(['slide_0', 'complete']));

    await t.tap(find.text('Next level'));
    await step(t, 500);
    expect(game(t).widget.args.levelId, 2);
    expect(s.backend.shown, isEmpty, reason: 'first interstitial only after 3–5 levels');
  });

  testWidgets('interstitial appears only when leaving a win screen after enough levels', (t) async {
    final s = TestServices(data: SaveData()..seenTips.addAll({1, 2, 3, 11}));
    s.store.data.ads
      ..interstitialTarget = 3
      ..levelsSinceInterstitial = 2;
    await boot(t, s);
    await t.tap(find.text('Play'));
    await step(t, 400);
    await solveByTapping(t);
    expect(find.text('Next level'), findsOneWidget);
    expect(s.backend.shown, isEmpty, reason: 'never over gameplay or the result screen itself');
    await t.tap(find.text('Next level'));
    await step(t, 500);
    expect(s.backend.shown, ['interstitial'], reason: 'shown at the natural break');
    expect(s.store.data.ads.levelsSinceInterstitial, 0);
    expect(game(t).widget.args.levelId, 2);
  });

  testWidgets('no ads for ad-free players even at a due break', (t) async {
    final s = TestServices(data: SaveData()..adFree = true..seenTips.add(1));
    s.store.data.ads
      ..interstitialTarget = 3
      ..levelsSinceInterstitial = 5;
    await boot(t, s);
    await t.tap(find.text('Play'));
    await step(t, 400);
    await solveByTapping(t);
    await t.tap(find.text('Next level'));
    await step(t, 500);
    expect(s.backend.shown, isEmpty);
    expect(s.backend.initCalls, 0);
  });

  testWidgets('out of hints → rewarded ad grants exactly 1 hint; unavailable ad never blocks', (t) async {
    final s = TestServices(data: SaveData()..hints = 0..seenTips.add(2)..unlocked = 2);
    await boot(t, s);
    await t.tap(find.text('Levels'));
    await step(t, 400);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Level 2$')));
    await step(t, 400);
    await t.tap(find.text('Hint'));
    await step(t, 400);
    expect(find.text('Out of hints'), findsOneWidget);
    await t.tap(find.text('Watch ad · +1 hint'));
    await step(t, 400);
    expect(s.backend.shown, ['rewarded']);
    expect(s.store.data.hints, 1);
    await step(t, 2500); // let the toast expire
  });

  testWidgets('offline: rewarded ad unavailable → message, no reward, gameplay continues', (t) async {
    final s = TestServices(data: SaveData()..hints = 0..seenTips.add(2)..unlocked = 2);
    s.backend.fill = false; // no network / no fill from the start
    await boot(t, s);
    await t.tap(find.text('Levels'));
    await step(t, 400);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Level 2$')));
    await step(t, 400);
    await t.tap(find.text('Hint'));
    await step(t, 400);
    await t.tap(find.text('Watch ad · +1 hint'));
    await step(t, 600);
    expect(s.store.data.hints, 0);
    expect(s.backend.shown, isEmpty);
    expect(find.textContaining('No ad available'), findsOneWidget);
    expect(game(t).session.status, SessionStatus.playing);
    await tapArrow(t, game(t).session.findHint().move!); // the board still responds
    expect(game(t).session.moves, 1);
    await step(t, 2500);
  });

  testWidgets('failing in Challenge → continue via rewarded ad (+2 hearts); mistakes never trigger interstitials', (t) async {
    final s = TestServices(data: SaveData()..seenTips.add(2)..unlocked = 2);
    s.store.data.ads
      ..interstitialTarget = 3
      ..levelsSinceInterstitial = 9;
    await boot(t, s);
    await t.tap(find.text('Levels'));
    await step(t, 400);
    await t.tap(find.bySemanticsLabel(RegExp(r'^Level 2$')));
    await step(t, 400);
    for (var k = 0; k < 3; k++) {
      await tapArrow(t, 0); // arrow 0 is blocked at the start of level 2
      await step(t, 400);
    }
    await step(t, 600);
    expect(find.text('Out of hearts'), findsOneWidget);
    expect(s.backend.shown, isEmpty, reason: 'no interstitial after mistakes / failure');
    await t.tap(find.text('Continue with +2 hearts · watch ad'));
    await step(t, 500);
    expect(s.backend.shown, ['rewarded']);
    expect(game(t).session.status, SessionStatus.playing);
    expect(game(t).session.hearts, 2);
    await step(t, 2500);
  });

  testWidgets('system back button returns from the game to home', (t) async {
    final s = TestServices(data: SaveData()..seenTips.add(1));
    await boot(t, s);
    await t.tap(find.text('Play'));
    await step(t, 400);
    expect(find.byType(GameScreen), findsOneWidget);
    await t.binding.handlePopRoute();
    await step(t, 400);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(s.store.data.stats.launches, 0);
  });

  testWidgets('daily puzzle opens from the calendar', (t) async {
    final s = TestServices();
    await boot(t, s);
    await t.tap(find.text('Daily Weave'));
    await step(t, 400);
    await t.tap(find.text('Play today'));
    await step(t, 400);
    expect(game(t).widget.args.dailyKey, dateKey());
    expect(find.text('Daily Weave'), findsOneWidget);
  });
}
