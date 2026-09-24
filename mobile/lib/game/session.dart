// One play-through of a level: moves, undo history, hearts, combos, scoring, hints.
// Port of js/game/session.js (UI-free, unit tested).
import 'dart:math' as math;

import '../core/model.dart';
import '../core/rules.dart';
import '../core/solver.dart';

const int comboWindowMs = 2600;
const int maxMult = 5;
const int _basePoints = 100;
const int _chainPoints = 150;

enum GameMode { challenge, zen }

enum SessionStatus { playing, won, failed }

class TapOutcome {
  TapOutcome(this.result, {this.move, this.gained = 0, this.mult = 1, this.multUp = false, this.heartsLeft});
  final MoveResult result;
  final MoveOutcome? move;
  final int gained;
  final int mult;
  final bool multUp;
  final int? heartsLeft;

  List<GameEvent> get events => move?.events ?? const [];
  Ray? get trace => move?.trace;
  int get chain => move?.chain ?? 0;
}

class Results {
  Results(this.stars, this.perfect, this.base, this.perfectBonus, this.heartBonus, this.maxMult, this.maxChain);
  final int stars;
  final bool perfect;
  final int base, perfectBonus, heartBonus, maxMult, maxChain;
  int get total => base + perfectBonus + heartBonus;

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'perfect': perfect,
        'base': base,
        'perfectBonus': perfectBonus,
        'heartBonus': heartBonus,
        'total': total,
        'maxMult': maxMult,
        'maxChain': maxChain,
      };
}

/// Hint answer: a move index, or [HintResult.dead] when unsolvable from here.
class HintResult {
  const HintResult._(this.move);
  const HintResult.move(int m) : this._(m);
  static const dead = HintResult._(null);
  final int? move;
  bool get isDead => move == null;
}

class Session {
  Session(this.level, {this.mode = GameMode.challenge, this.maxHearts = 3})
      : s = buildStatic(level),
        st = initialState(level),
        hearts = maxHearts;

  final Level level;
  final StaticBoard s;
  PlayState st;
  final GameMode mode;
  final int maxHearts;
  int hearts;
  final List<(PlayState, int)> _history = [];
  int score = 0;
  int combo = 0;
  int mult = 1;
  int _lastClearAt = -1 << 40;
  int mistakes = 0;
  int hintsUsed = 0;
  int undos = 0;
  int continues = 0;
  int maxMultReached = 1;
  int maxChain = 0;
  int moves = 0;
  SessionStatus status = SessionStatus.playing;
  bool statsRecorded = false;

  int get total => level.arrows.length;
  int get left => st.remaining;

  TapOutcome tap(int i, int now) {
    if (status != SessionStatus.playing) return TapOutcome(MoveResult.invalid);
    final r = applyMove(level, s, st, i);
    if (r.result == MoveResult.blocked) {
      mistakes++;
      combo = 0;
      mult = 1;
      if (mode == GameMode.challenge) {
        hearts = math.max(0, hearts - 1);
        if (hearts == 0) status = SessionStatus.failed;
      }
      return TapOutcome(MoveResult.blocked, move: r, heartsLeft: hearts);
    }
    if (r.result != MoveResult.cleared) return TapOutcome(r.result, move: r);

    _history.add((st, score));
    st = r.st;
    moves++;
    combo = now - _lastClearAt <= comboWindowMs ? combo + 1 : 1;
    _lastClearAt = now;
    final prevMult = mult;
    mult = math.min(maxMult, 1 + (combo - 1) ~/ 3);
    maxMultReached = math.max(maxMultReached, mult);
    maxChain = math.max(maxChain, r.chain);

    var gained = _basePoints * mult;
    for (final e in r.events) {
      if (e is ClearEvent && e.chain > 0) gained += _chainPoints * e.chain * mult;
    }
    score += gained;
    if (st.remaining == 0) status = SessionStatus.won;
    return TapOutcome(MoveResult.cleared, move: r, gained: gained, mult: mult, multUp: mult > prevMult);
  }

  bool get canUndo => _history.isNotEmpty && status == SessionStatus.playing;

  bool undo() {
    if (!canUndo) return false;
    final (prev, prevScore) = _history.removeLast();
    st = prev;
    score = prevScore;
    combo = 0;
    mult = 1;
    _lastClearAt = -1 << 40;
    undos++;
    return true;
  }

  HintResult findHint() {
    final r = solve(level, s, st, maxNodes: 30000);
    if (r.solved) return HintResult.move(r.moves.first);
    if (r.exhausted) {
      final legal = legalMoves(level, s, st);
      return legal.isNotEmpty ? HintResult.move(legal.first) : HintResult.dead;
    }
    return HintResult.dead;
  }

  void useHint() => hintsUsed++;

  bool get stuck => status == SessionStatus.playing && isStuck(level, s, st);

  void continueRun([int newHearts = 2]) {
    hearts = newHearts;
    status = SessionStatus.playing;
    continues++;
  }

  Results results() {
    final perfect = mistakes == 0 && hintsUsed == 0;
    final slips = mistakes + hintsUsed;
    final stars = perfect ? 3 : (slips <= 1 ? 2 : 1);
    return Results(
      stars,
      perfect,
      score,
      perfect ? 500 + 25 * total : 0,
      mode == GameMode.challenge ? hearts * 100 : 0,
      maxMultReached,
      maxChain,
    );
  }
}
