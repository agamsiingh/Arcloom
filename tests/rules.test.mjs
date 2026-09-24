import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeLevel, buildStatic, initialState, KIND } from '../js/core/model.js';
import { applyMove, isStuck } from '../js/core/rules.js';
import { Session } from '../js/game/session.js';
import { getLevel } from '../js/core/levels.js';
import { encodeLevel, decodeLevel } from '../js/core/codec.js';

function setup(def) {
  const level = normalizeLevel({ id: 't', ...def });
  return { level, S: buildStatic(level), st: initialState(level) };
}

test('an arrow is blocked by another arrow in its lane, then freed', () => {
  const { level, S, st } = setup({
    w: 4, h: 3,
    arrows: [{ at: [0, 1], p: 'R' }, { at: [3, 2], p: 'U' }],
  });
  assert.equal(applyMove(level, S, st, 0).result, 'blocked');
  const r = applyMove(level, S, st, 1);
  assert.equal(r.result, 'cleared');
  assert.equal(applyMove(level, S, r.st, 0).result, 'cleared');
});

test('stone blocks forever; one-way gates only pass in their direction', () => {
  const { level, S, st } = setup({
    w: 5, h: 2, walls: [[4, 0]], gates: [{ x: 2, y: 1, dir: 'R' }],
    arrows: [{ at: [0, 0], p: 'R' }, { at: [0, 1], p: 'R' }, { at: [4, 1], p: 'L' }],
  });
  assert.equal(applyMove(level, S, st, 0).result, 'blocked');
  assert.equal(applyMove(level, S, st, 2).result, 'blocked', 'gate faces the other way');
  assert.equal(applyMove(level, S, st, 1).result, 'blocked', 'lane still has arrow 2 in it');
});

test('portals continue the lane out of the twin', () => {
  const { level, S, st } = setup({
    w: 5, h: 5, portals: [[[2, 0], [4, 3]]],
    arrows: [{ at: [2, 3], p: 'U' }, { at: [4, 2], p: 'U' }],
  });
  assert.equal(applyMove(level, S, st, 0).result, 'blocked', 'lane exits the twin at (4,3) into arrow 1');
  const r = applyMove(level, S, st, 1);
  assert.equal(r.result, 'cleared');
  const r2 = applyMove(level, S, r.st, 0);
  assert.equal(r2.result, 'cleared');
  assert.ok(r2.trace.pts.some((p) => p[2]), 'trace records the portal jump');
});

test('locks open after N launches', () => {
  const { level, S, st } = setup({
    w: 3, h: 3, arrows: [{ at: [0, 0], p: 'R', lock: 1 }, { at: [0, 2], p: 'R' }],
  });
  assert.equal(applyMove(level, S, st, 0).result, 'locked');
  const r = applyMove(level, S, st, 1);
  assert.ok(r.events.some((e) => e.type === 'unlock' && e.i === 0));
  assert.equal(applyMove(level, S, r.st, 0).result, 'cleared');
});

test('rotators turn clockwise after every launch; drifters step along their track', () => {
  const { level, S, st } = setup({
    w: 5, h: 5, blockers: [{ track: [[0, 4], [1, 4], [2, 4]] }],
    arrows: [{ at: [2, 2], d: 'U', kind: 'rotator' }, { at: [4, 0], p: 'D' }],
  });
  const r = applyMove(level, S, st, 1);
  assert.equal(r.st.dirs[0], 1);
  assert.equal(r.st.bIdx[0], 1);
});

test('switch arrows flip which colour barrier is raised', () => {
  const { level, S, st } = setup({
    w: 4, h: 3, cwalls: [{ x: 2, y: 0, c: 0 }],
    arrows: [{ at: [0, 0], p: 'R' }, { at: [0, 2], p: 'R', kind: 'switch' }],
  });
  assert.equal(applyMove(level, S, st, 0).result, 'blocked');
  const r = applyMove(level, S, st, 1);
  assert.equal(r.st.color, 1);
  assert.equal(applyMove(level, S, r.st, 0).result, 'cleared');
});

test('spark arrows chain-launch once their lane opens', () => {
  const { level, S, st } = setup({
    w: 4, h: 4,
    arrows: [
      { at: [3, 0], p: 'DDD' },
      { at: [0, 1], p: 'R', kind: 'spark' },
      { at: [2, 3], p: 'U', kind: 'spark' },
    ],
  });
  const r = applyMove(level, S, st, 0);
  assert.equal(r.chain, 2);
  assert.equal(r.st.alive.reduce((a, b) => a + b, 0), 0);
});

test('phantoms pass through arrows but not stone', () => {
  const open = setup({ w: 5, h: 1, arrows: [{ at: [0, 0], p: 'R', kind: 'ghost' }, { at: [3, 0], d: 'U' }] });
  assert.equal(applyMove(open.level, open.S, open.st, 0).result, 'cleared');
  const normal = setup({ w: 5, h: 1, arrows: [{ at: [0, 0], p: 'R' }, { at: [3, 0], d: 'U' }] });
  assert.equal(applyMove(normal.level, normal.S, normal.st, 0).result, 'blocked');
  const stone = setup({ w: 5, h: 1, walls: [[3, 0]], arrows: [{ at: [0, 0], p: 'R', kind: 'ghost' }] });
  assert.equal(applyMove(stone.level, stone.S, stone.st, 0).result, 'blocked');
});

test('stuck detection', () => {
  const { level, S, st } = setup({
    w: 3, h: 1, arrows: [{ at: [0, 0], d: 'R' }, { at: [2, 0], d: 'L' }],
  });
  assert.ok(isStuck(level, S, st));
});

test('session: hearts, combo multiplier, undo, hints and stars', () => {
  const level = getLevel(2);
  const s = new Session(level, { mode: 'challenge' });
  assert.equal(s.tap(0, 0).result, 'blocked');
  assert.equal(s.hearts, 2);
  const hint = s.findHint();
  assert.equal(typeof hint, 'number');
  let t = 0;
  for (let k = 0; k < 20 && s.status === 'playing'; k++) s.tap(s.findHint(), (t += 100));
  assert.equal(s.status, 'won');
  assert.ok(s.maxMult >= 2);
  const res = s.results();
  assert.equal(res.stars, 2);
  assert.equal(res.perfect, false);

  const z = new Session(level, { mode: 'zen' });
  for (let k = 0; k < 5; k++) z.tap(0, 0);
  assert.equal(z.status, 'playing', 'zen never fails');
  z.tap(z.findHint(), 0);
  assert.ok(z.undo());
  assert.equal(z.left, level.arrows.length);
});

test('codec round-trips levels', () => {
  for (const n of [5, 47, 88, 150]) {
    const l = getLevel(n);
    const d = decodeLevel(encodeLevel(l), n);
    assert.equal(encodeLevel(d), encodeLevel(l));
    assert.ok(d.arrows.every((a) => Object.values(KIND).includes(a.kind)));
  }
});
