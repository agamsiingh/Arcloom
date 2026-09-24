// Game screen controller: wires session + board view + input + HUD + audio/haptics/ads.
// Port of js/game/controller.js.
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../core/model.dart';
import '../core/rules.dart';
import '../services/ads/ad_service.dart';
import '../services/haptics.dart';
import '../services/progress.dart';
import '../services/services.dart';
import '../ui/game_dialogs.dart';
import '../ui/routes.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'board_view.dart';
import 'board_widget.dart';
import 'game_hud.dart';
import 'session.dart';

class GameArgs {
  const GameArgs.level(int this.levelId) : dailyKey = null;
  const GameArgs.daily(String this.dailyKey) : levelId = null;
  final int? levelId;
  final String? dailyKey;
  bool get isDaily => dailyKey != null;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.args});
  final GameArgs args;
  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  late Session session;
  late BoardView view;
  String? banner;
  Timer? _bannerTimer;
  int heartsPulse = 0, comboPulse = 0;
  DateTime? _lastMistakeAt;
  bool _busyDialog = false;

  Services get sv => Services.I;
  Level get level => widget.args.isDaily ? getDailyLevel(widget.args.dailyKey!) : getLevel(widget.args.levelId!);

  @override
  void initState() {
    super.initState();
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTip());
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _finalizeStats(quiet: true);
    super.dispose();
  }

  void _start() {
    session = Session(level, mode: sv.data.settings.mode == 'zen' ? GameMode.zen : GameMode.challenge);
    view = BoardView(session, boardNow);
    _lastMistakeAt = null;
  }

  void _finalizeStats({bool quiet = false}) {
    if (session.statsRecorded) return;
    session.statsRecorded = true;
    recordStats(sv.data, session);
    // During dispose the widget tree is locked, so persist without notifying listeners.
    quiet ? sv.store.persist() : sv.store.save();
  }

  /// Rebuild after external changes (quick settings, purchases).
  void refresh() => setState(() {});

  void restart() {
    _finalizeStats();
    setState(_start);
  }

  void _maybeTip() {
    final l = level;
    if (widget.args.isDaily || l.tip == null || sv.data.seenTips.contains(l.id)) return;
    final ch = chapters[l.chapter];
    showTipDialog(context, title: l.id == 1 ? 'Welcome to Arcloom' : ch.name, text: l.tip!, mech: ch.mech).then((_) {
      sv.data.seenTips.add(l.id as int);
      sv.store.save();
    });
  }

  void showBanner(String text) {
    setState(() => banner = text);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => banner = null);
    });
  }

  // ---- input --------------------------------------------------------------------------
  void onBoardTap(Offset p) {
    if (session.status != SessionStatus.playing || _busyDialog) return;
    final s = sv.data.settings;
    final hit = view.hitTest(p, large: s.largeHitboxes);
    if (hit == null) {
      if (view.selected >= 0) setState(() => view.selected = -1);
      return;
    }
    if (hit.ambiguous && view.selected >= 0 && (view.selected == hit.i || view.selected == hit.alt)) {
      launch(view.selected);
      return;
    }
    final needsConfirm = s.tapConfirm || hit.ambiguous;
    if (needsConfirm && view.selected != hit.i) {
      view.selected = hit.i;
      sv.audio.select();
      sv.haptics.buzz(Haptic.select);
      showBanner(hit.ambiguous && !s.tapConfirm ? 'Two arrows here — tap again to launch' : 'Tap again to launch');
      return;
    }
    launch(hit.i);
  }

  void launch(int i) {
    view.selected = -1;
    final res = session.tap(i, DateTime.now().millisecondsSinceEpoch);
    switch (res.result) {
      case MoveResult.locked:
        view.shake(i);
        sv.audio.locked();
        sv.haptics.buzz(Haptic.light);
        final need = level.arrows[i].lock - session.st.cleared;
        showBanner('Locked — $need more launch${need > 1 ? 'es' : ''} to open');
        return;
      case MoveResult.blocked:
        view.addBump(i, res.trace!, session.st.dirs[i]);
        sv.audio.bump();
        sv.haptics.buzz(Haptic.error);
        _lastMistakeAt = DateTime.now();
        setState(() => heartsPulse++);
        if (session.status == SessionStatus.failed) Timer(const Duration(milliseconds: 480), _fail);
        return;
      case MoveResult.invalid:
        return;
      case MoveResult.cleared:
        break;
    }

    view.hint = -1;
    var rotated = false;
    var chainDepth = 0;
    for (final e in res.events) {
      switch (e) {
        case ClearEvent():
          view.addSlide(e.i, e.trace, e.dir);
          if (e.trace.pts.any((q) => q.$3)) Timer(const Duration(milliseconds: 80), sv.audio.portal);
          if (e.chain > 0) {
            chainDepth = e.chain;
            final (hx, hy) = view.headOf(e.i);
            Timer(Duration(milliseconds: 110 * e.chain), () {
              sv.audio.chain(e.chain);
              sv.haptics.buzz(Haptic.chain);
              view.floatText(hx.toDouble(), hy - 0.3, 'Chain ×${e.chain}', view.pal.spark);
            });
          }
        case SwitchEvent():
          sv.audio.toggle();
        case UnlockEvent():
          view.unlock(e.i);
          Timer(const Duration(milliseconds: 120), sv.audio.unlock);
        case RotateEvent():
          view.rotate(e.i);
          rotated = true;
        case DriftEvent():
          break;
      }
    }
    if (rotated) Timer(const Duration(milliseconds: 140), sv.audio.rotate);
    sv.audio.slide(session.combo - 1 < 0 ? 0 : session.combo - 1);
    sv.haptics.buzz(Haptic.light);
    final (hx, hy) = view.headOf(i);
    view.floatText(hx.toDouble(), hy.toDouble(), '+${res.gained}', view.pal.accent);
    if (res.multUp) {
      sv.audio.combo(res.mult);
      sv.haptics.buzz(Haptic.medium);
      showBanner('Combo ×${res.mult}!');
      comboPulse++;
    } else if (chainDepth >= 2) {
      showBanner('Chain reaction ×$chainDepth!');
    }
    setState(() {});
    if (session.status == SessionStatus.won) {
      Timer(const Duration(milliseconds: 520), _win);
    } else if (session.stuck) {
      Timer(const Duration(milliseconds: 650), () {
        if (mounted && session.stuck) _stuck();
      });
    }
  }

  // ---- tools --------------------------------------------------------------------------
  void undo() {
    if (!session.undo()) return;
    view.syncToState();
    sv.haptics.buzz(Haptic.light);
    setState(() {});
  }

  Future<void> hint() async {
    if (session.status != SessionStatus.playing) return;
    if (view.hint >= 0 && session.st.alive[view.hint] != 0) return;
    if (sv.data.hints <= 0) {
      final choice = await showNoHintsDialog(context,
          canWatch: sv.ads.canOfferRewarded, adFree: sv.data.adFree, price: sv.purchases.price);
      if (!mounted) return;
      if (choice == 'ad') {
        await _rewardedHint();
      } else if (choice == 'shop') {
        await openShop(context);
        if (mounted) setState(() {});
      }
      return;
    }
    final h = session.findHint();
    if (h.isDead) {
      showToast(context, 'Dead end from here — try Undo', icon: Icons.undo_rounded);
      return;
    }
    sv.data.hints--;
    await sv.store.save();
    session.useHint();
    view.hint = h.move!;
    sv.audio.hint();
    sv.haptics.buzz(Haptic.select);
    if (mounted) setState(() {});
  }

  Future<void> _rewardedHint() async {
    _busyDialog = true;
    final out = await sv.ads.showRewarded(RewardPlacement.hint);
    _busyDialog = false;
    if (!mounted) return;
    switch (out) {
      case RewardOutcome.earned:
        sv.data.hints += 1;
        await sv.store.save();
        if (mounted) showToast(context, '+1 hint', icon: Icons.lightbulb_outline_rounded);
      case RewardOutcome.dismissed:
        showToast(context, 'Ad closed early — no hint this time');
      case RewardOutcome.unavailable:
        showToast(context, 'No ad available right now. Keep playing and try again later.');
    }
    if (mounted) setState(() {});
  }

  void setMode(String mode) {
    sv.data.settings.mode = mode;
    sv.store.save();
    restart();
  }

  // ---- outcomes -----------------------------------------------------------------------
  Future<void> _fail({bool adFailed = false}) async {
    if (!mounted) return;
    sv.audio.fail();
    _busyDialog = true;
    final choice = await showFailDialog(context, canContinue: !adFailed && sv.ads.canOfferRewarded, adFree: sv.data.adFree);
    _busyDialog = false;
    if (!mounted) return;
    switch (choice) {
      case 'continue':
        _busyDialog = true;
        final out = await sv.ads.showRewarded(RewardPlacement.continueRun);
        _busyDialog = false;
        if (!mounted) return;
        if (out == RewardOutcome.earned) {
          session.continueRun(2);
          setState(() {});
          showToast(context, '+2 hearts — keep weaving!', icon: Icons.favorite_rounded);
        } else {
          if (out == RewardOutcome.unavailable) showToast(context, 'No ad available right now.');
          await _fail(adFailed: out == RewardOutcome.unavailable);
        }
      case 'zen':
        setMode('zen');
        showToast(context, 'Zen mode: unlimited retries', icon: Icons.eco_outlined);
      default:
        restart();
    }
  }

  Future<void> _stuck() async {
    _busyDialog = true;
    final choice = await showStuckDialog(context);
    _busyDialog = false;
    if (!mounted) return;
    choice == 'undo' ? undo() : restart();
  }

  Future<void> _win() async {
    if (!mounted) return;
    final res = session.results();
    _finalizeStats();
    final rec = recordWin(sv.data,
        levelId: widget.args.levelId, dailyKey: widget.args.dailyKey, res: res, session: session);
    await sv.store.save();
    await sv.ads.onLevelCompleted();
    view.celebrate();
    sv.audio.complete();
    sv.haptics.buzz(Haptic.success);
    if (!mounted) return;
    setState(() {});
    final hasNext = !widget.args.isDaily && widget.args.levelId! < levelCount;
    _busyDialog = true;
    final choice = await showWinDialog(context,
        res: res, rec: rec, isDaily: widget.args.isDaily, streak: currentStreak(sv.data), hasNext: hasNext);
    _busyDialog = false;
    if (!mounted) return;
    if (choice == 'replay') {
      restart();
      return;
    }
    // Leaving the level-complete screen is a natural break: the only place an
    // interstitial may appear (never during play, never right after a mistake).
    await sv.ads.maybeShowInterstitial(lastMistakeAt: _lastMistakeAt);
    if (!mounted) return;
    switch (choice) {
      case 'next':
        await openGame(context, GameArgs.level(widget.args.levelId! + 1), replace: true);
      case 'calendar':
        await openDaily(context, resetStack: true);
      default:
        widget.args.isDaily ? goHome(context) : await openLevels(context, focus: widget.args.levelId, resetStack: true);
    }
  }

  // ---- build --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    view
      ..pal = context.pal
      ..reducedMotion = sv.data.settings.reducedMotion;
    final args = widget.args;
    final title = args.isDaily ? 'Daily Weave' : 'Level ${args.levelId}';
    final sub = args.isDaily ? formatDayTitle(args.dailyKey!) : level.name;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(
            title: title,
            subtitle: sub,
            trailing: ArcIconButton(icon: Icons.settings_rounded, tooltip: 'Quick settings', onPressed: () => showQuickSettings(this)),
          ),
          GameHud(state: this),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: BoardWidget(view: view, onTap: onBoardTap, onZoomChanged: () => setState(() {})),
              ),
              BannerPill(text: banner),
              if (view.scale > 1.01)
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: ZoomFitButton(onPressed: () => setState(view.resetZoom)),
                ),
            ]),
          ),
          GameToolbar(state: this),
        ]),
      ),
    );
  }
}
