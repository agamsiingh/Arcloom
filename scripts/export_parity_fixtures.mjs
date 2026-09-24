// Exports reference outputs of the JS game engine so the Flutter (Dart) port can be
// regression-tested for bit-identical gameplay: RNG streams, every level, dailies,
// solver move sequences and session scoring.
// Usage: node scripts/export_parity_fixtures.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { Rng, hashString } from '../js/core/rng.js';
import { LEVEL_COUNT, getLevel, getDailyLevel, paramsFor } from '../js/core/levels.js';
import { generateLevel } from '../js/core/generator.js';
import { encodeLevel } from '../js/core/codec.js';
import { buildStatic, initialState } from '../js/core/model.js';
import { solve } from '../js/core/solver.js';
import { legalMoves } from '../js/core/rules.js';
import { Session } from '../js/game/session.js';

const out = { rng: {}, hash: {}, params: {}, levels: {}, generated: {}, dailies: {}, solver: {}, sessions: {} };

for (const seed of [0, 1, 42, 123456789, 4294967295, hashString('arcloom')]) {
  const r = new Rng(seed);
  out.rng[seed] = Array.from({ length: 24 }, () => r.float());
}
for (const s of ['', 'a', 'arcloom', 'arcloom-level-77', 'arcloom-daily-2026-09-24', 'ünïcødé']) out.hash[s] = hashString(s);

for (let n = 1; n <= LEVEL_COUNT; n++) {
  out.params[n] = paramsFor(n);
  out.levels[n] = encodeLevel(getLevel(n));
}
for (const n of [4, 17, 25, 38, 44, 57, 66, 73, 86, 99, 104, 121, 133, 142, 150]) {
  out.generated[n] = encodeLevel(generateLevel(paramsFor(n)));
}
const start = new Date(2026, 8, 1);
for (let i = 0; i < 45; i++) {
  const d = new Date(start);
  d.setDate(d.getDate() + i * 3);
  const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  out.dailies[key] = encodeLevel(getDailyLevel(key));
}
for (let n = 1; n <= LEVEL_COUNT; n += 3) {
  const l = getLevel(n);
  const r = solve(l, buildStatic(l), initialState(l), { maxNodes: 200000 });
  out.solver[n] = { moves: r.moves, nodes: r.nodes, solved: r.solved };
}
// Session scoring scenario: one deliberate mistake, then the solution with fixed timestamps.
for (const n of [2, 21, 81, 96]) {
  for (const mode of ['challenge', 'zen']) {
    const l = getLevel(n);
    const S = buildStatic(l);
    const s = new Session(l, { mode });
    const log = [];
    const legal = new Set(legalMoves(l, S, s.st));
    const bad = l.arrows.findIndex((a, i) => !legal.has(i) && a.lock <= 0);
    let t = 1000;
    if (bad >= 0) {
      const r = s.tap(bad, t);
      log.push([r.result, bad, s.hearts]);
    }
    const sol = solve(l, S, s.st, { maxNodes: 200000 }).moves;
    for (const m of sol) {
      if (!s.st.alive[m]) continue;
      t += (m % 3) * 1400 + 300;
      const r = s.tap(m, t);
      log.push([r.result, m, r.gained ?? 0, s.mult, s.score, r.chain ?? 0]);
    }
    out.sessions[`${n}-${mode}`] = { log, status: s.status, results: s.results(), hearts: s.hearts };
  }
}

const file = fileURLToPath(new URL('../mobile/test/fixtures/parity.json', import.meta.url));
mkdirSync(dirname(file), { recursive: true });
writeFileSync(file, JSON.stringify(out));
console.log('wrote', file);
