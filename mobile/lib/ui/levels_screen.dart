// Level select: 15 chapters × 10 levels (port of the PWA's levelsScreen).
import 'package:flutter/material.dart';

import '../core/levels.dart';
import '../game/game_screen.dart';
import '../services/services.dart';
import 'routes.dart';
import 'theme.dart';
import 'widgets.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, this.focus});
  final int? focus;
  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  final _keys = List.generate(chapters.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focus = widget.focus ?? Services.I.data.unlocked;
      final ctx = _keys[chapterOf(focus)].currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.3);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Services.I.store,
      builder: (context, _) {
        final s = Services.I.data;
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              TopBar(title: 'Levels', subtitle: '${s.completedCount} / $levelCount woven'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(children: [
                        for (var c = 0; c < chapters.length; c++) _chapter(context, c),
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

  Widget _chapter(BuildContext context, int c) {
    final p = context.pal;
    final s = Services.I.data;
    final first = c * 10 + 1;
    final last = first + 9 > levelCount ? levelCount : first + 9;
    final locked = first > s.unlocked;
    var got = 0;
    for (var n = first; n <= last; n++) {
      got += s.levels[n]?.stars ?? 0;
    }
    return Padding(
      key: _keys[c],
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(chapters[c].name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: locked ? p.muted : p.text)),
                Text(chapters[c].blurb, style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ),
            Icon(Icons.star_outline_rounded, size: 16, color: p.gold),
            const SizedBox(width: 3),
            Text('$got/30', style: TextStyle(fontWeight: FontWeight.w700, color: p.muted, fontSize: 13)),
          ]),
        ),
        GridView.count(
          crossAxisCount: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [for (var n = first; n <= last; n++) _levelCell(context, n)],
        ),
      ]),
    );
  }

  Widget _levelCell(BuildContext context, int n) {
    final p = context.pal;
    final s = Services.I.data;
    final rec = s.levels[n];
    final open = n <= s.unlocked;
    return Semantics(
      button: open,
      label: 'Level $n${rec != null ? ', ${rec.stars} stars' : open ? '' : ', locked'}',
      excludeSemantics: true,
      child: Material(
        color: !open ? p.surface2 : (rec?.perfect ?? false) ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open
              ? () {
                  uiClick();
                  openGame(context, GameArgs.level(n));
                }
              : null,
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
            alignment: Alignment.center,
            child: open
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.text)),
                    Stars(count: rec?.stars ?? 0, size: 11),
                  ])
                : Icon(Icons.lock_outline_rounded, size: 20, color: p.muted),
          ),
        ),
      ),
    );
  }
}
