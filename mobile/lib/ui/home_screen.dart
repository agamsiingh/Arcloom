// Home screen (port of the PWA's homeScreen).
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../game/game_screen.dart';
import '../services/progress.dart';
import '../services/services.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

int nextLevel() {
  final s = Services.I.data;
  final max = s.unlocked < levelCount ? s.unlocked : levelCount;
  for (var n = 1; n <= max; n++) {
    if (!s.levels.containsKey(n)) return n;
  }
  return max;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.I.store,
      builder: (context, _) {
        final p = context.pal;
        final s = Services.I.data;
        final n = nextLevel();
        final ch = chapters[chapterOf(n)];
        final done = s.completedCount;
        final dailyDone = s.daily.done.containsKey(dateKey());
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(builder: (context, c) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 28),
                      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [
                          Pill(icon: Icons.local_fire_department_outlined, label: '${currentStreak(s)}', semantic: 'Daily streak'),
                          const SizedBox(width: 8),
                          Pill(icon: Icons.star_outline_rounded, label: '${s.totalStars}', semantic: 'Stars'),
                          const SizedBox(width: 8),
                          Pill(icon: Icons.lightbulb_outline_rounded, label: '${s.hints}', semantic: 'Hints'),
                          const Spacer(),
                          ArcIconButton(icon: Icons.settings_rounded, tooltip: 'Settings', onPressed: () => openSettings(context)),
                        ]),
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(children: [
                            const LogoMark(),
                            const SizedBox(height: 14),
                            Text('ARCLOOM',
                                style: TextStyle(fontSize: 37, fontWeight: FontWeight.w900, letterSpacing: 8, color: p.text)),
                            const SizedBox(height: 4),
                            Text('weave · launch · unravel', style: TextStyle(color: p.muted, letterSpacing: 1.3)),
                          ]),
                        ),
                        Column(children: [
                          const SizedBox(height: 26),
                          _ModeSeg(mode: s.settings.mode),
                          const SizedBox(height: 14),
                          ArcButton(
                            label: done >= levelCount ? 'Replay' : 'Play',
                            subtitle: 'Level $n · ${ch.name}',
                            primary: true,
                            big: true,
                            onPressed: () => openGame(context, GameArgs.level(n)),
                          ),
                          const SizedBox(height: 14),
                          // Rows of equal-height tiles that grow with the text size (no fixed aspect ratio).
                          _TileRow(
                            _Tile(
                              icon: Icons.calendar_today_rounded,
                              title: 'Daily Weave',
                              sub: dailyDone ? 'Completed today' : 'New puzzle today',
                              highlight: !dailyDone,
                              done: dailyDone,
                              onTap: () => openDaily(context),
                            ),
                            _Tile(icon: Icons.grid_view_rounded, title: 'Levels', sub: '$done / $levelCount', onTap: () => openLevels(context, focus: n)),
                          ),
                          const SizedBox(height: 10),
                          _TileRow(
                            _Tile(
                              icon: Icons.emoji_events_outlined,
                              title: 'Trophies',
                              sub: '${s.achievements.length} / ${achievements.length}',
                              onTap: () => openTrophies(context),
                            ),
                            _Tile(
                              icon: Icons.diamond_outlined,
                              title: s.adFree ? 'Supporter' : 'Go ad-free',
                              sub: s.adFree ? 'Thank you!' : 'Hints & perks',
                              onTap: () => openShop(context),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeSeg extends StatelessWidget {
  const _ModeSeg({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget btn(String m, IconData icon, String label) {
      final on = mode == m;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: GestureDetector(
            onTap: () {
              uiClick();
              Services.I.data.settings.mode = m;
              Services.I.store.save();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(color: on ? p.surface : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 19, color: on ? p.accent : p.muted),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: on ? p.text : p.muted)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [btn('challenge', Icons.favorite_border_rounded, 'Challenge'), btn('zen', Icons.eco_outlined, 'Zen')]),
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow(this.a, this.b);
  final Widget a, b;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.sub, required this.onTap, this.highlight = false, this.done = false});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  final bool highlight, done;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          uiClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: highlight ? p.accent : p.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 26, color: done ? p.good : p.accent),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
            Text(sub, style: TextStyle(fontSize: 12.5, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
