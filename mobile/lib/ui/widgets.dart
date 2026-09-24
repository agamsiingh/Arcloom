// Shared UI building blocks (ports of the PWA's buttons, pills, cards, toggles…).
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/services.dart';
import 'theme.dart';

void uiClick() => Services.I.audio.ui();

class ArcButton extends StatelessWidget {
  const ArcButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.big = false,
    this.subtitle,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary, danger, big;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = primary ? p.accent : (danger ? p.danger : p.surface2);
    final fg = primary || danger ? p.accentInk : p.text;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(big ? 20 : 14),
        elevation: primary && enabled ? 3 : 0,
        shadowColor: p.accentSoft,
        child: InkWell(
          borderRadius: BorderRadius.circular(big ? 20 : 14),
          onTap: enabled
              ? () {
                  uiClick();
                  onPressed!();
                }
              : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle != null ? 68 : (big ? 56 : 48)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: subtitle != null ? 19 : (big ? 17 : 15))),
                    ),
                  ]),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArcIconButton extends StatelessWidget {
  const ArcIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: context.pal.text,
        onPressed: onPressed == null
            ? null
            : () {
                uiClick();
                onPressed!();
              },
      );
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.subtitle, this.trailing, this.onBack});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: 56,
      child: Row(children: [
        const SizedBox(width: 4),
        ArcIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.text)),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.muted)),
          ]),
        ),
        trailing ?? const SizedBox(width: 48),
        const SizedBox(width: 4),
      ]),
    );
  }
}

class ArcCard extends StatelessWidget {
  const ArcCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
        boxShadow: p.dark ? null : const [BoxShadow(color: Color(0x17281E14), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.icon, required this.label, this.semantic});
  final IconData icon;
  final String label;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      label: semantic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: p.accent),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
        ]),
      ),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars({super.key, required this.count, this.size = 14, this.total = 3});
  final int count, total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < total; i++)
        Icon(i < count ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < count ? p.gold : p.peg),
    ]);
  }
}

class ToggleTile extends StatelessWidget {
  const ToggleTile({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MergeSemantics(
      child: InkWell(
        onTap: () {
          uiClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: p.muted)),
              ]),
            ),
            Switch(
              value: value,
              activeTrackColor: p.accent,
              onChanged: (v) {
                uiClick();
                onChanged(v);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (v, label) in options)
          Semantics(
            selected: v == value,
            button: true,
            child: GestureDetector(
              onTap: () {
                uiClick();
                onChanged(v);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: v == value ? p.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: v == value ? p.text : p.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: context.pal.text)),
      );
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// Top-anchored toast that never intercepts taps (like the PWA), so it can't
/// swallow a tap on the game toolbar the way a bottom SnackBar would.
void showToast(BuildContext context, String text, {IconData? icon}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final pal = context.pal;
  _toastEntry?.remove();
  _toastTimer?.cancel();
  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * -10), child: child)),
              child: Material(
                color: pal.text,
                shape: const StadiumBorder(),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: pal.bg), const SizedBox(width: 8)],
                    Flexible(child: Text(text, style: TextStyle(color: pal.bg, fontWeight: FontWeight.w700))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  _toastEntry = entry;
  _toastTimer = Timer(const Duration(milliseconds: 2200), () {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  });
}

/// The ARCLOOM logo mark displayed on the home screen.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 116});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/logo/arcloom_logo.jpeg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
}
