// Subtle haptics via the platform haptic engine (no VIBRATE permission needed).
// Same feedback vocabulary as the PWA's js/services/haptics.js.
import 'dart:async';

import 'package:flutter/services.dart';

enum Haptic { light, select, medium, error, success, chain }

class Haptics {
  bool enabled = true;
  final List<Haptic> log = []; // inspected by tests

  void buzz(Haptic kind) {
    if (!enabled) return;
    log.add(kind);
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.select:
        HapticFeedback.selectionClick();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.error:
        HapticFeedback.heavyImpact();
        Timer(const Duration(milliseconds: 70), HapticFeedback.mediumImpact);
      case Haptic.success:
        HapticFeedback.mediumImpact();
        Timer(const Duration(milliseconds: 60), HapticFeedback.lightImpact);
        Timer(const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
      case Haptic.chain:
        HapticFeedback.lightImpact();
        Timer(const Duration(milliseconds: 40), HapticFeedback.lightImpact);
    }
  }
}
