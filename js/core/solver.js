// Depth-first solver with transposition memo. Used for level verification and hints.
import { KIND, remaining, stateKey } from './model.js';
import { applyMove, legalMoves } from './rules.js';

const PRIORITY = {
  [KIND.NORMAL]: 0,
  [KIND.GHOST]: 0,
  [KIND.SPARK]: 1,
  [KIND.ROTATOR]: 2,
  [KIND.SWITCH]: 3,
};

/**
 * @returns {{ solved: boolean, moves: number[], exhausted: boolean, nodes: number }}
 * exhausted=true means the node budget ran out before a verdict.
 */
export function solve(level, S, st, { maxNodes = 40000 } = {}) {
  const dead = new Set();
  const moves = [];
  let nodes = 0;
  let exhausted = false;

  const order = (list) =>
    list.sort((a, b) => PRIORITY[level.arrows[a].kind] - PRIORITY[level.arrows[b].kind]);

  function dfs(s) {
    if (remaining(s) === 0) return true;
    if (++nodes > maxNodes) {
      exhausted = true;
      return false;
    }
    const key = stateKey(s);
    if (dead.has(key)) return false;
    for (const m of order(legalMoves(level, S, s))) {
      const r = applyMove(level, S, s, m);
      moves.push(m);
      if (dfs(r.st)) return true;
      moves.pop();
      if (exhausted) return false;
    }
    dead.add(key);
    return false;
  }

  const solved = dfs(st);
  return { solved, moves: solved ? moves.slice() : [], exhausted, nodes };
}
