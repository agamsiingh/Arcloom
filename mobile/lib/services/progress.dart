// Achievements + level/daily result recording. Port of js/services/achievements.js
// and js/services/progress.js.
import 'dart:math' as math;

import '../core/levels.dart';
import '../game/session.dart';
import 'storage.dart';

const int perfectHintReward = 1;
const int dailyHintReward = 2;

class Achievement {
  const Achievement(this.id, this.name, this.desc, this.reward, this.goal, this.value);
  final String id, name, desc;
  final int reward, goal;
  final int Function(SaveData) value;

  double progress(SaveData s) => math.min(1, value(s) / goal);
}

int _done(SaveData s) => s.completedCount;

final List<Achievement> achievements = [
  const Achievement('first', 'First Thread', 'Clear your first level', 1, 1, _done),
  const Achievement('ten', 'Apprentice Weaver', 'Clear 10 levels', 2, 10, _done),
  const Achievement('fifty', 'Journeyman', 'Clear 50 levels', 3, 50, _done),
  const Achievement('hundred', 'Master Weaver', 'Clear 100 levels', 5, 100, _done),
  const Achievement('all', 'The Grand Loom', 'Clear all 150 levels', 10, 150, _done),
  Achievement('perfect1', 'Flawless', 'Get a perfect clear', 1, 1, (s) => s.stats.perfect),
  Achievement('perfect25', 'Perfectionist', '25 perfect clears', 3, 25, (s) => s.stats.perfect),
  Achievement('combo5', 'In the Flow', 'Reach a x5 combo', 2, 5, (s) => s.stats.maxCombo),
  Achievement('chain3', 'Chain Reaction', 'Trigger a 3-spark chain', 2, 3, (s) => s.stats.maxChain),
  Achievement('daily1', 'Daily Weave', 'Complete a daily challenge', 1, 1, (s) => s.stats.dailyCount),
  Achievement('streak3', 'Warm Streak', 'Reach a 3-day daily streak', 2, 3, (s) => s.daily.best),
  Achievement('streak7', 'Week of Weaving', 'Reach a 7-day daily streak', 5, 7, (s) => s.daily.best),
  Achievement('zen', 'Zen Garden', 'Clear 20 levels in Zen mode', 2, 20, (s) => s.stats.zenWins),
  Achievement('challenger', 'Challenger', 'Clear 20 levels in Challenge mode', 2, 20, (s) => s.stats.challengeWins),
  Achievement('selfmade', 'Self-Reliant', 'Clear 25 levels without hints', 3, 25, (s) => s.stats.noHintWins),
  Achievement('score', 'High Tension', 'Earn 250,000 total points', 3, 250000, (s) => s.stats.totalScore),
  Achievement('explorer', 'Explorer', 'Reach the Phantoms chapter', 3, 91, (s) => s.unlocked),
];

/// Unlocks anything newly earned (awarding hints). Returns the new unlocks.
List<Achievement> evaluateAchievements(SaveData s, {DateTime? now}) {
  final fresh = <Achievement>[];
  for (final a in achievements) {
    if (s.achievements.containsKey(a.id)) continue;
    if (a.value(s) >= a.goal) {
      s.achievements[a.id] = (now ?? DateTime.now()).millisecondsSinceEpoch;
      s.hints += a.reward;
      fresh.add(a);
    }
  }
  return fresh;
}

String yesterdayKey([DateTime? from]) {
  final d = from ?? DateTime.now();
  return dateKey(DateTime(d.year, d.month, d.day - 1));
}

int currentStreak(SaveData s, [DateTime? now]) {
  final today = dateKey(now);
  if (s.daily.last == today || s.daily.last == yesterdayKey(now)) return s.daily.streak;
  return 0;
}

class WinRecord {
  WinRecord(this.hints, this.firstClear, this.achievements);
  final int hints;
  final bool firstClear;
  final List<Achievement> achievements;
}

/// Records a win for a campaign level (`levelId`) or a daily (`dailyKey`).
WinRecord recordWin(SaveData s, {int? levelId, String? dailyKey, required Results res, required Session session, DateTime? now}) {
  var hints = 0;
  var firstClear = false;
  if (levelId != null) {
    final prev = s.levels[levelId];
    firstClear = prev == null;
    s.levels[levelId] = LevelRecord(
      math.max(prev?.stars ?? 0, res.stars),
      math.max(prev?.best ?? 0, res.total),
      (prev?.perfect ?? false) || res.perfect,
    );
    s.unlocked = math.min(levelCount, math.max(s.unlocked, levelId + 1));
    if (res.perfect && !(prev?.perfect ?? false)) hints += perfectHintReward;
  } else if (dailyKey != null) {
    final prev = s.daily.done[dailyKey];
    firstClear = prev == null;
    s.daily.done[dailyKey] = LevelRecord(math.max(prev?.stars ?? 0, res.stars), math.max(prev?.best ?? 0, res.total), false);
    if (firstClear) {
      hints += dailyHintReward;
      s.stats.dailyCount++;
      if (dailyKey == dateKey(now)) {
        s.daily.streak = s.daily.last == yesterdayKey(now)
            ? s.daily.streak + 1
            : s.daily.last == dailyKey
                ? s.daily.streak
                : 1;
        s.daily.last = dailyKey;
        s.daily.best = math.max(s.daily.best, s.daily.streak);
      }
    }
  }
  final st = s.stats;
  st.totalScore += res.total;
  if (res.perfect) st.perfect++;
  if (session.mode == GameMode.zen) {
    st.zenWins++;
  } else {
    st.challengeWins++;
  }
  if (session.hintsUsed == 0) st.noHintWins++;
  st.maxCombo = math.max(st.maxCombo, res.maxMult);
  st.maxChain = math.max(st.maxChain, res.maxChain);
  s.hints += hints;
  return WinRecord(hints, firstClear, evaluateAchievements(s, now: now));
}

void recordStats(SaveData s, Session session) {
  s.stats.mistakes += session.mistakes;
  s.stats.launches += session.moves;
}
