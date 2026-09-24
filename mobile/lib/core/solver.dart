// Depth-first solver with transposition memo. Used for level verification and hints.
// Port of js/core/solver.js (move ordering is kept identical so results match).
import 'model.dart';
import 'rules.dart';

int _priority(Kind k) => switch (k) {
      Kind.normal || Kind.ghost => 0,
      Kind.spark => 1,
      Kind.rotator => 2,
      Kind.switcher => 3,
    };

class SolveResult {
  SolveResult(this.solved, this.moves, this.exhausted, this.nodes);
  final bool solved;
  final List<int> moves;

  /// true when the node budget ran out before a verdict.
  final bool exhausted;
  final int nodes;
}

SolveResult solve(Level level, StaticBoard s, PlayState st, {int maxNodes = 40000}) {
  final dead = <String>{};
  final moves = <int>[];
  var nodes = 0;
  var exhausted = false;

  // legalMoves is ascending, so (priority, index) ordering == JS's stable sort.
  List<int> order(List<int> list) => list
    ..sort((a, b) {
      final p = _priority(level.arrows[a].kind) - _priority(level.arrows[b].kind);
      return p != 0 ? p : a - b;
    });

  bool dfs(PlayState cur) {
    if (cur.remaining == 0) return true;
    if (++nodes > maxNodes) {
      exhausted = true;
      return false;
    }
    final key = cur.key;
    if (dead.contains(key)) return false;
    for (final m in order(legalMoves(level, s, cur))) {
      final r = applyMove(level, s, cur, m);
      moves.add(m);
      if (dfs(r.st)) return true;
      moves.removeLast();
      if (exhausted) return false;
    }
    dead.add(key);
    return false;
  }

  final solved = dfs(st);
  return SolveResult(solved, solved ? List.of(moves) : const [], exhausted, nodes);
}
