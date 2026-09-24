// Result / fail / stuck / tip / out-of-hints dialogs (port of js/ui/gameModals.js).
// Each returns the action the player chose.
import 'dart:async';

import 'package:flutter/material.dart';

import '../game/session.dart';
import '../services/progress.dart';
import '../services/services.dart';
import 'theme.dart';
import 'widgets.dart';

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

Future<String?> _show(BuildContext context, Widget child, {bool blocking = true}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: !blocking,
    barrierLabel: 'Close',
    barrierColor: const Color(0x730A0814),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => PopScope(
      canPop: !blocking,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: context.pal.surface,
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), child: child),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(c), child: child),
      );
    },
  );
}

Widget _bigIcon(BuildContext context, IconData icon, {bool danger = false}) {
  final p = context.pal;
  return Container(
    width: 64,
    height: 64,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: danger ? p.danger.withValues(alpha: 0.12) : p.accentSoft,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Icon(icon, size: 32, color: danger ? p.danger : p.accent),
  );
}

Widget _title(BuildContext context, String text) =>
    Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: context.pal.text));

Widget _body(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted, height: 1.45)),
    );

Widget _gap([double h = 10]) => SizedBox(height: h);

Future<String?> showWinDialog(BuildContext context,
    {required Results res, required WinRecord rec, required bool isDaily, required int streak, required bool hasNext}) {
  return _show(context, Builder(builder: (context) {
    final p = context.pal;
    Widget row(String label, String value, {bool total = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: total ? p.text : p.muted, fontSize: total ? 17 : 15))),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: total ? 17 : 15)),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _AnimatedStars(stars: res.stars),
      _title(context, res.perfect ? 'Perfect Weave!' : 'Woven!'),
      if (isDaily)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_outlined, color: p.muted, size: 18),
            const SizedBox(width: 4),
            Text('Daily streak: $streak', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      _gap(14),
      row('Launch points', _fmt(res.base)),
      if (res.perfectBonus > 0) row('Perfect clear', '+${_fmt(res.perfectBonus)}'),
      if (res.heartBonus > 0) row('Hearts left', '+${_fmt(res.heartBonus)}'),
      Divider(color: p.line),
      row('Total', _fmt(res.total), total: true),
      if (rec.hints > 0 || rec.achievements.isNotEmpty) ...[
        _gap(12),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          if (rec.hints > 0) _Chip(icon: Icons.lightbulb_outline_rounded, label: '+${rec.hints} hint${rec.hints > 1 ? 's' : ''}', color: p.good),
          for (final a in rec.achievements)
            _Chip(icon: Icons.emoji_events_outlined, label: '${a.name} · +${a.reward}', color: p.gold),
        ]),
      ],
      _gap(18),
      if (hasNext) ArcButton(label: 'Next level', icon: Icons.play_arrow_rounded, primary: true, big: true, onPressed: () => Navigator.pop(context, 'next')),
      if (isDaily) ArcButton(label: 'Calendar', icon: Icons.calendar_today_rounded, primary: true, big: true, onPressed: () => Navigator.pop(context, 'calendar')),
      _gap(),
      Row(children: [
        Expanded(child: ArcButton(label: 'Replay', icon: Icons.refresh_rounded, onPressed: () => Navigator.pop(context, 'replay'))),
        const SizedBox(width: 10),
        Expanded(child: ArcButton(label: isDaily ? 'Home' : 'Levels', icon: Icons.grid_view_rounded, onPressed: () => Navigator.pop(context, 'menu'))),
      ]),
    ]);
  }));
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
      );
}

class _AnimatedStars extends StatefulWidget {
  const _AnimatedStars({required this.stars});
  final int stars;
  @override
  State<_AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<_AnimatedStars> {
  int _shown = 0;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.stars; i++) {
      _timers.add(Timer(Duration(milliseconds: 350 + i * 260), () {
        if (!mounted) return;
        setState(() => _shown = i + 1);
        Services.I.audio.star(i);
      }));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 3; i++)
          AnimatedScale(
            scale: i < _shown ? 1 : 0.85,
            duration: const Duration(milliseconds: 380),
            curve: Curves.elasticOut,
            child: Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? 8 : 0),
              child: Icon(i < _shown ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: i == 1 ? 60 : 48, color: i < _shown ? p.gold : p.peg),
            ),
          ),
      ]),
    );
  }
}

/// [adLabel] is null when the player is ad-free (continue is instant).
Future<String?> showFailDialog(BuildContext context, {required bool canContinue, required bool adFree}) {
  return _show(context, Builder(builder: (context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _bigIcon(context, Icons.favorite_border_rounded, danger: true),
      _title(context, 'Out of hearts'),
      _body(context, 'Keep your progress on the board and carry on, or start fresh.'),
      _gap(18),
      ArcButton(
        label: adFree ? 'Continue with +2 hearts' : 'Continue with +2 hearts · watch ad',
        icon: adFree ? Icons.favorite_rounded : Icons.ondemand_video_rounded,
        primary: true,
        big: true,
        onPressed: canContinue ? () => Navigator.pop(context, 'continue') : null,
      ),
      _gap(),
      ArcButton(label: 'Retry level', icon: Icons.refresh_rounded, onPressed: () => Navigator.pop(context, 'retry')),
      _gap(),
      ArcButton(label: 'Switch to Zen mode', icon: Icons.eco_outlined, onPressed: () => Navigator.pop(context, 'zen')),
      if (!canContinue) _body(context, 'No ad is available right now — retry, or switch to Zen for unlimited tries.'),
    ]);
  }));
}

Future<String?> showStuckDialog(BuildContext context) {
  return _show(context, Builder(builder: (context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _bigIcon(context, Icons.lock_outline_rounded),
      _title(context, 'No moves left'),
      _body(context, 'Every remaining arrow is blocked. Step back and try another order.'),
      _gap(18),
      ArcButton(label: 'Undo last launch', icon: Icons.undo_rounded, primary: true, big: true, onPressed: () => Navigator.pop(context, 'undo')),
      _gap(),
      ArcButton(label: 'Restart', icon: Icons.refresh_rounded, onPressed: () => Navigator.pop(context, 'restart')),
    ]);
  }));
}

IconData _tipIcon(String? mech) => switch (mech) {
      'walls' => Icons.grid_view_rounded,
      'rotators' => Icons.refresh_rounded,
      'locks' => Icons.lock_outline_rounded,
      'portals' => Icons.blur_circular_rounded,
      'gates' => Icons.double_arrow_rounded,
      'cwalls' => Icons.contrast_rounded,
      'blockers' => Icons.hexagon_outlined,
      'sparks' => Icons.bolt_rounded,
      'ghosts' => Icons.all_inclusive_rounded,
      _ => Icons.play_arrow_rounded,
    };

Future<void> showTipDialog(BuildContext context, {required String title, required String text, String? mech}) {
  return _show(
    context,
    Builder(builder: (context) {
      final p = context.pal;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: p.accentSoft, borderRadius: BorderRadius.circular(24)),
          child: Icon(_tipIcon(mech), size: 40, color: p.accent),
        ),
        _title(context, title),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(height: 1.5, color: p.text, fontSize: 15.5)),
        ),
        ArcButton(label: 'Got it', primary: true, big: true, onPressed: () => Navigator.pop(context, 'ok')),
      ]);
    }),
    blocking: false,
  );
}

Future<String?> showNoHintsDialog(BuildContext context, {required bool canWatch, required bool adFree, required String price}) {
  return _show(
    context,
    Builder(builder: (context) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _bigIcon(context, Icons.lightbulb_outline_rounded),
        _title(context, 'Out of hints'),
        _body(context, 'Earn hints with perfect clears, daily challenges and achievements — or grab one now.'),
        _gap(18),
        ArcButton(
          label: adFree ? 'Claim +1 hint' : 'Watch ad · +1 hint',
          icon: adFree ? Icons.lightbulb_outline_rounded : Icons.ondemand_video_rounded,
          primary: true,
          big: true,
          onPressed: canWatch ? () => Navigator.pop(context, 'ad') : null,
        ),
        if (!adFree) ...[
          _gap(),
          ArcButton(label: 'Go ad-free · $price', icon: Icons.diamond_outlined, onPressed: () => Navigator.pop(context, 'shop')),
        ],
        _gap(),
        ArcButton(label: 'Not now', onPressed: () => Navigator.pop(context, 'close')),
        if (!canWatch) _body(context, 'No ad is available right now — try again later.'),
      ]);
    }),
    blocking: false,
  );
}
