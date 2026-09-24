import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LEVEL_COUNT, getLevel, getDailyLevel, paramsFor } from '../js/core/levels.js';
import { buildStatic, initialState, KIND } from '../js/core/model.js';
import { applyMove, legalMoves } from '../js/core/rules.js';
import { solve } from '../js/core/solver.js';

function checkLevel(level) {
  const S = buildStatic(level);
  const st = initialState(level);
  // No overlapping cells between arrows / statics.
  const seen = new Set();
  const mark = (x, y, what) => {
    assert.ok(x >= 0 && y >= 0 && x < level.w && y < level.h, `${what} out of bounds in ${level.id}`);
    const k = y * level.w + x;
    assert.ok(!seen.has(k), `overlap at ${x},${y} (${what}) in level ${level.id}`);
    seen.add(k);
  };
  level.arrows.forEach((a) => a.cells.forEach(([x, y]) => mark(x, y, 'arrow')));
  level.walls.forEach(([x, y]) => mark(x, y, 'wall'));
  level.portals.forEach(([a, b]) => { mark(a[0], a[1], 'portal'); mark(b[0], b[1], 'portal'); });
  level.gates.forEach((g) => mark(g.x, g.y, 'gate'));
  level.cwalls.forEach((c) => mark(c.x, c.y, 'cwall'));
  level.blockers.forEach((b) => b.track.forEach(([x, y]) => mark(x, y, 'track')));
  // Sparks never fire before the first move.
  for (const i of legalMoves(level, S, st)) {
    assert.notEqual(level.arrows[i].kind, KIND.SPARK, `spark free at start in ${level.id}`);
  }
  const r = solve(level, S, st, { maxNodes: 200000 });
  assert.ok(r.solved, `level ${level.id} unsolvable (nodes ${r.nodes})`);
  // Replay the solution through the rules to be sure it clears the board.
  let s = st;
  for (const m of r.moves) {
    const res = applyMove(level, S, s, m);
    assert.equal(res.result, 'cleared');
    s = res.st;
  }
  assert.equal(s.alive.reduce((a, b) => a + b, 0), 0);
}

test(`all ${LEVEL_COUNT} campaign levels are valid and solvable`, () => {
  const t0 = Date.now();
  let slowest = 0;
  let slowestId = 0;
  for (let n = 1; n <= LEVEL_COUNT; n++) {
    const t = Date.now();
    const level = getLevel(n);
    const dt = Date.now() - t;
    if (dt > slowest) { slowest = dt; slowestId = n; }
    checkLevel(level);
  }
  console.log(`generated+verified ${LEVEL_COUNT} levels in ${Date.now() - t0}ms (slowest gen: L${slowestId} ${slowest}ms)`);
});

test('mechanics are introduced progressively', () => {
  assert.deepEqual(Object.keys(paramsFor(5).feat), []);
  assert.ok(paramsFor(25).feat.rotators > 0);
  assert.ok(paramsFor(45).feat.portals > 0);
  assert.ok(paramsFor(85).feat.sparks > 0);
  const big = getLevel(LEVEL_COUNT);
  assert.ok(big.w * big.h >= 150, 'late levels are large');
});

test('daily levels are deterministic and solvable', () => {
  for (const key of ['2026-09-01', '2026-09-23', '2026-12-31', '2027-02-14']) {
    const a = getDailyLevel(key);
    checkLevel(a);
    assert.equal(JSON.stringify(a.arrows), JSON.stringify(getDailyLevel(key).arrows));
  }
});
