// Offline local progress. The whole save is one versioned JSON document (same
// schema as the PWA's localStorage save) persisted with shared_preferences.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String saveKey = 'arcloom.save.v1';

class Settings {
  String theme = 'system'; // system | light | dark | amoled
  bool sound = true;
  double soundVolume = 0.8;
  bool music = true;
  double musicVolume = 0.35;
  bool haptics = true;
  bool tapConfirm = false;
  bool largeHitboxes = false;
  bool reducedMotion = false;
  bool highContrast = false;
  double textScale = 1;
  String mode = 'challenge'; // challenge | zen

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'sound': sound,
        'soundVolume': soundVolume,
        'music': music,
        'musicVolume': musicVolume,
        'haptics': haptics,
        'tapConfirm': tapConfirm,
        'largeHitboxes': largeHitboxes,
        'reducedMotion': reducedMotion,
        'highContrast': highContrast,
        'textScale': textScale,
        'mode': mode,
      };

  void fromJson(Map<String, dynamic> j) {
    theme = _str(j['theme'], theme, const ['system', 'light', 'dark', 'amoled']);
    sound = _bool(j['sound'], sound);
    soundVolume = _num(j['soundVolume'], soundVolume, 0, 1);
    music = _bool(j['music'], music);
    musicVolume = _num(j['musicVolume'], musicVolume, 0, 1);
    haptics = _bool(j['haptics'], haptics);
    tapConfirm = _bool(j['tapConfirm'], tapConfirm);
    largeHitboxes = _bool(j['largeHitboxes'], largeHitboxes);
    reducedMotion = _bool(j['reducedMotion'], reducedMotion);
    highContrast = _bool(j['highContrast'], highContrast);
    textScale = _num(j['textScale'], textScale, 1, 1.3);
    mode = _str(j['mode'], mode, const ['challenge', 'zen']);
  }
}

class LevelRecord {
  LevelRecord(this.stars, this.best, this.perfect);
  int stars;
  int best;
  bool perfect;
  Map<String, dynamic> toJson() => {'stars': stars, 'best': best, 'perfect': perfect};
  static LevelRecord fromJson(Map<String, dynamic> j) =>
      LevelRecord(_int(j['stars'], 0).clamp(0, 3), _int(j['best'], 0), _bool(j['perfect'], false));
}

class Stats {
  int totalScore = 0, perfect = 0, zenWins = 0, challengeWins = 0, noHintWins = 0;
  int maxCombo = 1, maxChain = 0, dailyCount = 0, mistakes = 0, launches = 0;

  Map<String, dynamic> toJson() => {
        'totalScore': totalScore,
        'perfect': perfect,
        'zenWins': zenWins,
        'challengeWins': challengeWins,
        'noHintWins': noHintWins,
        'maxCombo': maxCombo,
        'maxChain': maxChain,
        'dailyCount': dailyCount,
        'mistakes': mistakes,
        'launches': launches,
      };

  void fromJson(Map<String, dynamic> j) {
    totalScore = _int(j['totalScore'], 0);
    perfect = _int(j['perfect'], 0);
    zenWins = _int(j['zenWins'], 0);
    challengeWins = _int(j['challengeWins'], 0);
    noHintWins = _int(j['noHintWins'], 0);
    maxCombo = _int(j['maxCombo'], 1);
    maxChain = _int(j['maxChain'], 0);
    dailyCount = _int(j['dailyCount'], 0);
    mistakes = _int(j['mistakes'], 0);
    launches = _int(j['launches'], 0);
  }
}

class DailyProgress {
  Map<String, LevelRecord> done = {};
  int streak = 0;
  int best = 0;
  String? last;
}

/// Ad pacing state (persisted so the cadence survives app restarts).
class AdPacing {
  int levelsSinceInterstitial = 0;
  int interstitialTarget = 4; // re-rolled in 3..5 after every interstitial
  int lastInterstitialMs = 0;
  String? rewardedDate;
  int rewardedCount = 0;
}

class SaveData {
  Map<int, LevelRecord> levels = {};
  int unlocked = 1;
  int hints = 3;
  bool adFree = false;
  final Settings settings = Settings();
  final Stats stats = Stats();
  final DailyProgress daily = DailyProgress();
  Map<String, int> achievements = {};
  Set<int> seenTips = {};
  final AdPacing ads = AdPacing();

  int get completedCount => levels.length;
  int get totalStars => levels.values.fold(0, (s, l) => s + l.stars);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'levels': {for (final e in levels.entries) '${e.key}': e.value.toJson()},
        'unlocked': unlocked,
        'hints': hints,
        'adFree': adFree,
        'settings': settings.toJson(),
        'stats': stats.toJson(),
        'daily': {
          'done': {for (final e in daily.done.entries) e.key: e.value.toJson()},
          'streak': daily.streak,
          'best': daily.best,
          'last': daily.last,
        },
        'achievements': achievements,
        'seenTips': {for (final t in seenTips) '$t': 1},
        'rewardedToday': {'date': ads.rewardedDate, 'count': ads.rewardedCount},
        'adPacing': {
          'since': ads.levelsSinceInterstitial,
          'target': ads.interstitialTarget,
          'last': ads.lastInterstitialMs,
        },
      };

  /// Tolerant of missing / malformed fields: anything unreadable falls back to defaults.
  static SaveData fromJson(Map<String, dynamic> j) {
    final d = SaveData();
    final lv = j['levels'];
    if (lv is Map) {
      lv.forEach((k, v) {
        final n = int.tryParse('$k');
        if (n != null && v is Map) d.levels[n] = LevelRecord.fromJson(v.cast<String, dynamic>());
      });
    }
    d.unlocked = _int(j['unlocked'], 1).clamp(1, 150);
    d.hints = _int(j['hints'], 3).clamp(0, 9999);
    d.adFree = _bool(j['adFree'], false);
    if (j['settings'] is Map) d.settings.fromJson((j['settings'] as Map).cast<String, dynamic>());
    if (j['stats'] is Map) d.stats.fromJson((j['stats'] as Map).cast<String, dynamic>());
    final daily = j['daily'];
    if (daily is Map) {
      final done = daily['done'];
      if (done is Map) {
        done.forEach((k, v) {
          if (v is Map) d.daily.done['$k'] = LevelRecord.fromJson(v.cast<String, dynamic>());
        });
      }
      d.daily.streak = _int(daily['streak'], 0);
      d.daily.best = _int(daily['best'], 0);
      d.daily.last = daily['last'] is String ? daily['last'] as String : null;
    }
    final ach = j['achievements'];
    if (ach is Map) ach.forEach((k, v) => d.achievements['$k'] = _int(v, 1));
    final tips = j['seenTips'];
    if (tips is Map) {
      for (final k in tips.keys) {
        final n = int.tryParse('$k');
        if (n != null) d.seenTips.add(n);
      }
    }
    final rt = j['rewardedToday'];
    if (rt is Map) {
      d.ads.rewardedDate = rt['date'] is String ? rt['date'] as String : null;
      d.ads.rewardedCount = _int(rt['count'], 0);
    }
    final ap = j['adPacing'];
    if (ap is Map) {
      d.ads.levelsSinceInterstitial = _int(ap['since'], 0);
      d.ads.interstitialTarget = _int(ap['target'], 4).clamp(3, 5);
      d.ads.lastInterstitialMs = _int(ap['last'], 0);
    }
    return d;
  }
}

/// Owns the save document and notifies listeners after every change.
class Store extends ChangeNotifier {
  Store(this._prefs, this.data);

  final SharedPreferences? _prefs;
  SaveData data;

  static Future<Store> open() async {
    final prefs = await SharedPreferences.getInstance();
    return Store(prefs, decode(prefs.getString(saveKey)));
  }

  /// In-memory store (tests).
  factory Store.memory([SaveData? data]) => Store(null, data ?? SaveData());

  static SaveData decode(String? raw) {
    if (raw == null) return SaveData();
    try {
      final j = jsonDecode(raw);
      return j is Map ? SaveData.fromJson(j.cast<String, dynamic>()) : SaveData();
    } catch (_) {
      return SaveData(); // corrupted save: start fresh rather than crash
    }
  }

  Future<void> save() async {
    notifyListeners();
    await persist();
  }

  /// Writes to disk without notifying listeners (safe during widget disposal).
  Future<void> persist() async {
    try {
      await _prefs?.setString(saveKey, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  /// Re-render listeners without writing (e.g. the date changed while backgrounded).
  void touch() => notifyListeners();

  Future<void> resetProgress() {
    final keepSettings = data.settings.toJson();
    final adFree = data.adFree;
    data = SaveData()
      ..adFree = adFree
      ..settings.fromJson(keepSettings);
    return save();
  }
}

bool _bool(Object? v, bool d) => v is bool ? v : d;
int _int(Object? v, int d) => v is num && v.isFinite ? v.toInt() : d;
double _num(Object? v, double d, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : d;
String _str(Object? v, String d, List<String> allowed) => v is String && allowed.contains(v) ? v : d;
