// Daily challenge calendar + streaks (port of the PWA's dailyScreen).
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../game/game_screen.dart';
import '../services/progress.dart';
import '../services/services.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  int monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.I.store,
      builder: (context, _) {
        final p = context.pal;
        final s = Services.I.data;
        final today = DateTime.now();
        final todayKey = dateKey(today);
        final view = DateTime(today.year, today.month + monthOffset, 1);
        final daysIn = DateTime(view.year, view.month + 1, 0).day;
        final lead = view.weekday % 7; // Sunday-first grid
        var doneInMonth = 0;
        final cells = <Widget>[for (var i = 0; i < lead; i++) const SizedBox.shrink()];
        for (var d = 1; d <= daysIn; d++) {
          final key = dateKey(DateTime(view.year, view.month, d));
          final done = s.daily.done.containsKey(key);
          if (done) doneInMonth++;
          final future = key.compareTo(todayKey) > 0;
          final isToday = key == todayKey;
          cells.add(Semantics(
            button: !future,
            label: '$key${done ? ', completed' : ''}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: future
                  ? null
                  : () {
                      uiClick();
                      openGame(context, GameArgs.daily(key));
                    },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? p.accent : Colors.transparent,
                  border: isToday && !done ? Border.all(color: p.accent, width: 2) : null,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  if (done) Icon(Icons.star_rounded, color: p.accentInk.withValues(alpha: 0.25), size: 30),
                  Text('$d',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: done ? p.accentInk : future ? p.muted.withValues(alpha: 0.45) : p.text,
                      )),
                ]),
              ),
            ),
          ));
        }
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              const TopBar(title: 'Daily Weave', subtitle: 'A fresh puzzle every day'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ArcCard(
                          child: Row(children: [
                            Icon(Icons.local_fire_department_outlined, color: p.accent, size: 34),
                            const SizedBox(width: 8),
                            Text('${currentStreak(s)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: p.text)),
                            const SizedBox(width: 8),
                            Expanded(child: Text('day streak', style: TextStyle(color: p.muted))),
                            _stat(context, 'Best', s.daily.best),
                            const SizedBox(width: 16),
                            _stat(context, 'Total', s.daily.done.length),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        ArcCard(
                          child: Column(children: [
                            Row(children: [
                              ArcIconButton(
                                  icon: Icons.chevron_left_rounded, tooltip: 'Previous month', onPressed: () => setState(() => monthOffset--)),
                              Expanded(
                                child: Text('${monthName(view.month)} ${view.year}',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text)),
                              ),
                              Icon(Icons.star_outline_rounded, size: 17, color: p.gold),
                              const SizedBox(width: 3),
                              Text('$doneInMonth/$daysIn', style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                              ArcIconButton(
                                icon: Icons.chevron_right_rounded,
                                tooltip: 'Next month',
                                onPressed: monthOffset >= 0 ? null : () => setState(() => monthOffset++),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 2,
                              children: [
                                for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                                  Center(child: Text(w, style: TextStyle(fontSize: 12, color: p.muted))),
                              ],
                            ),
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              children: cells,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Past days can be replayed any time; only today's puzzle grows your streak. Each first clear earns 2 hints.",
                              style: TextStyle(fontSize: 12.5, color: p.muted),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        ArcButton(
                          label: s.daily.done.containsKey(todayKey) ? 'Replay today' : 'Play today',
                          subtitle: formatLongDay(today),
                          primary: true,
                          big: true,
                          onPressed: () => openGame(context, GameArgs.daily(todayKey)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, int v) {
    final p = context.pal;
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12.5, color: p.muted)),
      Text('$v', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.text)),
    ]);
  }
}
