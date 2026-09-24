// HUD, toolbar, banner and quick-settings sheet for the game screen.
// Fixed heights keep the board completely stable while playing.
import 'package:flutter/material.dart';

import '../services/services.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'game_screen.dart';
import 'session.dart';

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _Pulse extends StatelessWidget {
  const _Pulse({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(trigger),
        tween: Tween(begin: trigger == 0 ? 1 : 1.18, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (_, s, c) => Transform.scale(scale: s, child: c),
        child: child,
      );
}

class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.state});
  final GameScreenState state;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = state.session;
    Widget left;
    if (s.mode == GameMode.zen) {
      left = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: p.good.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.eco_outlined, size: 16, color: p.good),
          const SizedBox(width: 5),
          Text('Zen', style: TextStyle(color: p.good, fontWeight: FontWeight.w800)),
        ]),
      );
    } else {
      left = Semantics(
        label: '${s.hearts} hearts left',
        child: _Pulse(
          trigger: state.heartsPulse,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < s.maxHearts; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(i < s.hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 24, color: i < s.hearts ? p.danger : p.peg),
              ),
          ]),
        ),
      );
    }
    final hot = s.mult > 1;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: left)),
          Text(_thousands(s.score), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: p.text, fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 8),
          _Pulse(
            trigger: state.comboPulse,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: hot ? p.accent : p.surface2, borderRadius: BorderRadius.circular(99)),
              child: Text('×${s.mult}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: hot ? p.accentInk : p.muted)),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${s.left} ', style: TextStyle(fontWeight: FontWeight.w900, color: p.text)),
                TextSpan(text: 'left', style: TextStyle(fontWeight: FontWeight.w600, color: p.muted)),
              ])),
            ),
          ),
        ]),
      ),
    );
  }
}

class BannerPill extends StatelessWidget {
  const BannerPill({super.key, required this.text});
  final String? text;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: text == null ? 0 : 0.92,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(99)),
              child: Text(text ?? '', style: TextStyle(color: p.bg, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ),
        ),
      ),
    );
  }
}

class ZoomFitButton extends StatelessWidget {
  const ZoomFitButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          uiClick();
          onPressed();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.zoom_out_map_rounded, size: 18, color: p.text),
            const SizedBox(width: 6),
            Text('Fit', style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
          ]),
        ),
      ),
    );
  }
}

class GameToolbar extends StatelessWidget {
  const GameToolbar({super.key, required this.state});
  final GameScreenState state;

  @override
  Widget build(BuildContext context) {
    final hints = Services.I.data.hints;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Tool(icon: Icons.undo_rounded, label: 'Undo', onTap: state.session.canUndo ? state.undo : null),
        const SizedBox(width: 22),
        _Tool(icon: Icons.refresh_rounded, label: 'Restart', onTap: state.restart),
        const SizedBox(width: 22),
        _Tool(icon: Icons.lightbulb_outline_rounded, label: 'Hint', badge: '$hints', onTap: state.hint),
      ]),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap, this.badge});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: badge != null ? '$label, $badge available' : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Stack(clipBehavior: Clip.none, children: [
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap == null
                  ? null
                  : () {
                      uiClick();
                      onTap!();
                    },
              child: Container(
                width: 72,
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
                child: Column(children: [
                  Icon(icon, size: 24, color: p.text),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.muted)),
                ]),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -6,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.bg, width: 2)),
                child: Text(badge!, style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
        ]),
      ),
    );
  }
}

void showQuickSettings(GameScreenState state) {
  final sv = Services.I;
  showModalBottomSheet<void>(
    context: state.context,
    backgroundColor: state.context.pal.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(builder: (context, setSheet) {
      final st = sv.data.settings;
      void set(void Function() f) {
        f();
        sv.applySettings();
        sv.store.save();
        setSheet(() {});
        state.refresh();
      }

      final zen = state.session.mode == GameMode.zen;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Quick settings'),
            ToggleTile(title: 'Sound effects', subtitle: 'Taps, slides, chains and chimes', value: st.sound, onChanged: (v) => set(() => st.sound = v)),
            ToggleTile(title: 'Music', subtitle: 'Calm generative ambience', value: st.music, onChanged: (v) => set(() => st.music = v)),
            ToggleTile(title: 'Haptics', subtitle: 'Subtle vibration feedback', value: st.haptics, onChanged: (v) => set(() => st.haptics = v)),
            ToggleTile(
                title: 'Tap to confirm',
                subtitle: 'First tap selects and previews the lane, second tap launches',
                value: st.tapConfirm,
                onChanged: (v) => set(() => st.tapConfirm = v)),
            ToggleTile(
                title: 'Large touch targets', subtitle: 'Even more generous invisible hitboxes', value: st.largeHitboxes, onChanged: (v) => set(() => st.largeHitboxes = v)),
            ToggleTile(title: 'Reduce motion', subtitle: 'Shorter animations, fewer particles', value: st.reducedMotion, onChanged: (v) => set(() => st.reducedMotion = v)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ArcButton(
                  label: 'Restart in ${zen ? 'Challenge' : 'Zen'}',
                  icon: zen ? Icons.favorite_rounded : Icons.eco_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                    state.setMode(zen ? 'challenge' : 'zen');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: ArcButton(label: 'Done', primary: true, onPressed: () => Navigator.pop(context))),
            ]),
          ]),
        ),
      );
    }),
  );
}
