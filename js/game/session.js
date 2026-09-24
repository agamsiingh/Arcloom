// One play-through of a level: moves, undo history, hearts, combos, scoring, hints.
// DOM-free so it can be unit tested.
import { buildStatic, initialState, remaining } from '../core/model.js';
import { applyMove, isStuck, legalMoves } from '../core/rules.js';
import { solve } from '../core/solver.js';

export const COMBO_WINDOW_MS = 2600;
export const MAX_MULT = 5;
const BASE_POINTS = 100;
const CHAIN_POINTS = 150;

export class Session {
  constructor(level, { mode = 'challenge', maxHearts = 3 } = {}) {
    this.level = level;
    this.S = buildStatic(level);
    this.st = initialState(level);
    this.mode = mode;
    this.maxHearts = maxHearts;
    this.hearts = maxHearts;
    this.history = [];
    this.score = 0;
    this.combo = 0;
    this.mult = 1;
    this.lastClearAt = -Infinity;
    this.mistakes = 0;
    this.hintsUsed = 0;
    this.undos = 0;
    this.continues = 0;
    this.maxMult = 1;
    this.maxChain = 0;
    this.moves = 0;
    this.status = 'playing'; // playing | won | failed
  }

  get total() {
    return this.level.arrows.length;
  }

  get left() {
    return remaining(this.st);
  }

  tap(i, now = Date.now()) {
    if (this.status !== 'playing') return { result: 'invalid', events: [] };
    const r = applyMove(this.level, this.S, this.st, i);
    if (r.result === 'blocked') {
      this.mistakes++;
      this.combo = 0;
      this.mult = 1;
      if (this.mode === 'challenge') {
        this.hearts = Math.max(0, this.hearts - 1);
        if (this.hearts === 0) this.status = 'failed';
      }
      return { ...r, heartsLeft: this.hearts };
    }
    if (r.result !== 'cleared') return r;

    this.history.push({ st: this.st, score: this.score });
    this.st = r.st;
    this.moves++;
    this.combo = now - this.lastClearAt <= COMBO_WINDOW_MS ? this.combo + 1 : 1;
    this.lastClearAt = now;
    const prevMult = this.mult;
    this.mult = Math.min(MAX_MULT, 1 + Math.floor((this.combo - 1) / 3));
    this.maxMult = Math.max(this.maxMult, this.mult);
    this.maxChain = Math.max(this.maxChain, r.chain);

    let gained = BASE_POINTS * this.mult;
    for (const e of r.events) if (e.type === 'clear' && e.chain > 0) gained += CHAIN_POINTS * e.chain * this.mult;
    this.score += gained;
    if (remaining(this.st) === 0) this.status = 'won';
    return { ...r, gained, mult: this.mult, multUp: this.mult > prevMult };
  }

  canUndo() {
    return this.history.length > 0 && this.status === 'playing';
  }

  undo() {
    if (!this.canUndo()) return false;
    const h = this.history.pop();
    this.st = h.st;
    this.score = h.score;
    this.combo = 0;
    this.mult = 1;
    this.lastClearAt = -Infinity;
    this.undos++;
    return true;
  }

  /** Next move toward a solution: arrow index, 'dead' if unsolvable from here, or null if unknown. */
  findHint() {
    const r = solve(this.level, this.S, this.st, { maxNodes: 30000 });
    if (r.solved) return r.moves[0];
    if (r.exhausted) {
      const legal = legalMoves(this.level, this.S, this.st);
      return legal.length ? legal[0] : 'dead';
    }
    return 'dead';
  }

  useHint() {
    this.hintsUsed++;
  }

  stuck() {
    return this.status === 'playing' && isStuck(this.level, this.S, this.st);
  }

  continueRun(hearts = 2) {
    this.hearts = hearts;
    this.status = 'playing';
    this.continues++;
  }

  results() {
    const perfect = this.mistakes === 0 && this.hintsUsed === 0;
    const slips = this.mistakes + this.hintsUsed;
    const stars = perfect ? 3 : slips <= 1 ? 2 : 1;
    const perfectBonus = perfect ? 500 + 25 * this.total : 0;
    const heartBonus = this.mode === 'challenge' ? this.hearts * 100 : 0;
    return {
      stars,
      perfect,
      base: this.score,
      perfectBonus,
      heartBonus,
      total: this.score + perfectBonus + heartBonus,
      maxMult: this.maxMult,
      maxChain: this.maxChain,
    };
  }
}
