// Design tokens — ported 1:1 from the PWA's css/base.css (light / dark / AMOLED
// themes plus the high-contrast overrides).
import 'package:flutter/material.dart';

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.good,
    required this.gold,
    required this.ink,
    required this.board,
    required this.peg,
    required this.warp,
    required this.danger,
    required this.stone,
    required this.stoneHi,
    required this.gate,
    required this.gateFrame,
    required this.c0,
    required this.c1,
    required this.onColor,
    required this.spark,
    required this.ghost,
    required this.rot,
    required this.rotRing,
    required this.lock,
    required this.drift,
    required this.driftTrack,
    required this.hint,
    required this.portals,
    required this.dark,
  });

  final Color bg, surface, surface2, text, muted, line, accent, accentInk, accentSoft, good, gold;
  final Color ink, board, peg, warp, danger, stone, stoneHi, gate, gateFrame, c0, c1, onColor;
  final Color spark, ghost, rot, rotRing, lock, drift, driftTrack, hint;
  final List<Color> portals;
  final bool dark;

  static const light = Palette(
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEE9E1),
    text: Color(0xFF1D1B2C),
    muted: Color(0xFF777386),
    line: Color(0x171D1B2C),
    accent: Color(0xFFFF6B3D),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x1FFF6B3D),
    good: Color(0xFF1FA99A),
    gold: Color(0xFFF0A020),
    ink: Color(0xFF1D1B2C),
    board: Color(0xFFFBFAF7),
    peg: Color(0xFFD4CDC1),
    warp: Color(0x0B1D1B2C),
    danger: Color(0xFFE5484D),
    stone: Color(0xFF9C958B),
    stoneHi: Color(0xFFB5AFA5),
    gate: Color(0xFF5061F0),
    gateFrame: Color(0x385061F0),
    c0: Color(0xFFE2557A),
    c1: Color(0xFF1FA99A),
    onColor: Color(0xFFFFFFFF),
    spark: Color(0xFFEF9A0F),
    ghost: Color(0xFF8B7FD6),
    rot: Color(0xFF2F6FE8),
    rotRing: Color(0x732F6FE8),
    lock: Color(0xFF6F6A7D),
    drift: Color(0xFF7A3E9D),
    driftTrack: Color(0x597A3E9D),
    hint: Color(0xFFFFB020),
    portals: [Color(0xFF8B5CF6), Color(0xFF06A6C4), Color(0xFFE0479E), Color(0xFF6FB313)],
    dark: false,
  );

  static const darkTheme = Palette(
    bg: Color(0xFF121220),
    surface: Color(0xFF201F34),
    surface2: Color(0xFF161527),
    text: Color(0xFFEFEAF6),
    muted: Color(0xFF9B97B0),
    line: Color(0x14FFFFFF),
    accent: Color(0xFFFF6B3D),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0x29FF6B3D),
    good: Color(0xFF1FA99A),
    gold: Color(0xFFF0A020),
    ink: Color(0xFFECE8F5),
    board: Color(0xFF17162A),
    peg: Color(0xFF3B3957),
    warp: Color(0x09FFFFFF),
    danger: Color(0xFFE5484D),
    stone: Color(0xFF5D5A74),
    stoneHi: Color(0xFF6E6B87),
    gate: Color(0xFF8A96FF),
    gateFrame: Color(0x408A96FF),
    c0: Color(0xFFF0668C),
    c1: Color(0xFF2FC4B3),
    onColor: Color(0xFF13121F),
    spark: Color(0xFFFFB52E),
    ghost: Color(0xFFA99FF0),
    rot: Color(0xFF6A9BFF),
    rotRing: Color(0x736A9BFF),
    lock: Color(0xFFA39FB6),
    drift: Color(0xFFC07AE6),
    driftTrack: Color(0x59C07AE6),
    hint: Color(0xFFFFB020),
    portals: [Color(0xFF8B5CF6), Color(0xFF06A6C4), Color(0xFFE0479E), Color(0xFF6FB313)],
    dark: true,
  );

  static final amoled = darkTheme.copyWith(
    bg: const Color(0xFF000000),
    surface: const Color(0xFF121219),
    surface2: const Color(0xFF060609),
    text: const Color(0xFFF2F0F7),
    muted: const Color(0xFF8E8AA0),
    accentSoft: const Color(0x2EFF6B3D),
    ink: const Color(0xFFF2F0F7),
    board: const Color(0xFF000000),
    peg: const Color(0xFF2B2A36),
    warp: const Color(0x08FFFFFF),
    stone: const Color(0xFF4C4A5C),
    stoneHi: const Color(0xFF5C5A6E),
    onColor: const Color(0xFF000000),
  );

  Palette withHighContrast() => copyWith(
        muted: text,
        line: const Color(0x80808080),
        peg: const Color(0xFF8C8C8C),
        ink: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        text: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        board: dark ? board : const Color(0xFFFFFFFF),
      );

  static Palette resolve(String theme, {required bool systemDark, required bool highContrast}) {
    final base = switch (theme) {
      'light' => light,
      'dark' => darkTheme,
      'amoled' => amoled,
      _ => systemDark ? darkTheme : light,
    };
    return highContrast ? base.withHighContrast() : base;
  }

  @override
  Palette copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? text,
    Color? muted,
    Color? line,
    Color? accentSoft,
    Color? ink,
    Color? board,
    Color? peg,
    Color? warp,
    Color? stone,
    Color? stoneHi,
    Color? onColor,
  }) =>
      Palette(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surface2: surface2 ?? this.surface2,
        text: text ?? this.text,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        accent: accent,
        accentInk: accentInk,
        accentSoft: accentSoft ?? this.accentSoft,
        good: good,
        gold: gold,
        ink: ink ?? this.ink,
        board: board ?? this.board,
        peg: peg ?? this.peg,
        warp: warp ?? this.warp,
        danger: danger,
        stone: stone ?? this.stone,
        stoneHi: stoneHi ?? this.stoneHi,
        gate: gate,
        gateFrame: gateFrame,
        c0: c0,
        c1: c1,
        onColor: onColor ?? this.onColor,
        spark: spark,
        ghost: ghost,
        rot: rot,
        rotRing: rotRing,
        lock: lock,
        drift: drift,
        driftTrack: driftTrack,
        hint: hint,
        portals: portals,
        dark: dark,
      );

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 || other == null ? this : other;

  ThemeData toTheme(double textScale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: accentInk,
      surface: surface,
      onSurface: text,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: TextStyle(color: bg, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
      splashFactory: InkSparkle.splashFactory,
      extensions: [this],
    );
  }
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}
