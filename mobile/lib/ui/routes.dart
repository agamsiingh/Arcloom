// Navigation helpers. Android back / iOS swipe-back pop these routes naturally.
import 'package:flutter/material.dart';

import '../game/game_screen.dart';
import 'daily_screen.dart';
import 'levels_screen.dart';
import 'meta_screens.dart';
import 'settings_screen.dart';

Route<T> arcRoute<T>(Widget page, {String? name}) => PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, anim, _, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(c), child: child),
        );
      },
    );

Future<void> openGame(BuildContext context, GameArgs args, {bool replace = false}) {
  final route = arcRoute<void>(GameScreen(key: UniqueKey(), args: args), name: 'game');
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

Future<void> _openFromHome(BuildContext context, Widget page, String name, bool resetStack) {
  final nav = Navigator.of(context);
  final route = arcRoute<void>(page, name: name);
  return resetStack ? nav.pushAndRemoveUntil(route, (r) => r.isFirst) : nav.push(route);
}

Future<void> openLevels(BuildContext context, {int? focus, bool resetStack = false}) =>
    _openFromHome(context, LevelsScreen(focus: focus), 'levels', resetStack);

Future<void> openDaily(BuildContext context, {bool resetStack = false}) =>
    _openFromHome(context, const DailyScreen(), 'daily', resetStack);

Future<void> openTrophies(BuildContext context) => _openFromHome(context, const TrophiesScreen(), 'trophies', false);

Future<void> openShop(BuildContext context) => _openFromHome(context, const ShopScreen(), 'shop', false);

Future<void> openSettings(BuildContext context) => _openFromHome(context, const SettingsScreen(), 'settings', false);

void goHome(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String monthName(int m) => _months[m - 1];

DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String formatDayTitle(String key) {
  final d = parseDayKey(key);
  return '${monthName(d.month)} ${d.day}';
}

String formatLongDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${monthName(d.month)} ${d.day}';
