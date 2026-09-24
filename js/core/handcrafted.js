// Hand-authored tutorial levels. Each arrow: tail cell `at`, path of moves `p`
// (the head points along the final move) or explicit `d` for single-cell arrows.

export const HANDCRAFTED = {
  1: {
    w: 4, h: 5,
    tip: 'Tap an arrow to launch it. It flies off the loom in the direction its head points.',
    arrows: [
      { at: [0, 3], p: 'UU' },
      { at: [1, 1], p: 'DD' },
      { at: [3, 4], p: 'UUU' },
    ],
  },
  2: {
    w: 5, h: 5,
    tip: 'An arrow can only leave when its whole lane is clear. Find the right order.',
    arrows: [
      { at: [0, 2], p: 'RRR' },
      { at: [4, 4], p: 'UU' },
      { at: [1, 0], p: 'D' },
      { at: [3, 0], p: 'L' },
    ],
  },
  3: {
    w: 5, h: 5,
    tip: 'Threads bend and weave — only the head decides where an arrow goes.',
    arrows: [
      { at: [0, 4], p: 'UUUR' },
      { at: [3, 0], p: 'DDRD' },
      { at: [1, 3], p: 'RR' },
      { at: [1, 4], p: 'RRR' },
      { at: [2, 0], p: 'L' },
    ],
  },
  11: {
    w: 5, h: 5,
    tip: 'Stone blocks never move. Weave your lanes around them.',
    walls: [[2, 2], [1, 0]],
    arrows: [
      { at: [1, 3], p: 'UUR' },
      { at: [3, 3], p: 'UU' },
      { at: [4, 0], p: 'DDDD' },
      { at: [0, 4], p: 'RRR' },
      { at: [0, 1], p: 'U' },
      { at: [0, 2], p: 'D' },
    ],
  },
  21: {
    w: 5, h: 5,
    tip: 'Spinners turn a quarter clockwise every time you launch another arrow. Time them well.',
    arrows: [
      { at: [2, 2], d: 'U', kind: 'rotator' },
      { at: [0, 0], p: 'RRRR' },
      { at: [4, 4], p: 'LLLL' },
      { at: [4, 1], p: 'DD' },
    ],
  },
  31: {
    w: 5, h: 5,
    tip: 'Locked arrows open after the number of launches shown on their padlock.',
    arrows: [
      { at: [0, 0], p: 'DDD' },
      { at: [2, 4], p: 'UUU', lock: 2 },
      { at: [4, 0], p: 'DDDD' },
      { at: [3, 1], p: 'DD', lock: 3 },
    ],
  },
  41: {
    w: 6, h: 6,
    tip: 'Portals are linked in pairs. A lane that enters one continues out of its twin.',
    portals: [[[1, 1], [4, 4]]],
    arrows: [
      { at: [1, 4], p: 'UU' },
      { at: [4, 3], p: 'UUU' },
      { at: [5, 5], p: 'LLL' },
      { at: [0, 0], p: 'RRR' },
      { at: [3, 3], p: 'L' },
    ],
  },
  51: {
    w: 5, h: 5,
    tip: 'Gates only let arrows through in the direction of their chevrons.',
    gates: [{ x: 2, y: 2, dir: 'R' }, { x: 2, y: 1, dir: 'L' }],
    arrows: [
      { at: [0, 2], p: 'R' },
      { at: [4, 4], p: 'UU' },
      { at: [4, 1], p: 'L' },
      { at: [3, 4], p: 'U' },
    ],
  },
  61: {
    w: 5, h: 5,
    tip: 'Colour barriers rise and fall. Launching a switch arrow flips which colour is raised.',
    cwalls: [{ x: 2, y: 2, c: 0 }, { x: 2, y: 1, c: 1 }],
    arrows: [
      { at: [0, 2], p: 'R' },
      { at: [4, 4], p: 'LL', kind: 'switch' },
      { at: [0, 1], p: 'R' },
      { at: [3, 0], p: 'L' },
    ],
  },
  71: {
    w: 6, h: 5,
    tip: 'Drifters glide one step along their track every time you launch an arrow.',
    blockers: [{ track: [[2, 2], [3, 2], [4, 2]] }],
    arrows: [
      { at: [2, 4], p: 'U' },
      { at: [0, 0], p: 'RRR' },
      { at: [5, 4], p: 'UUU' },
      { at: [4, 4], p: 'U' },
    ],
  },
  81: {
    w: 5, h: 5,
    tip: 'Spark arrows launch themselves the instant their lane opens. Set off chain reactions!',
    arrows: [
      { at: [4, 0], p: 'DDDD' },
      { at: [0, 1], p: 'RR', kind: 'spark' },
      { at: [2, 3], p: 'U', kind: 'spark' },
      { at: [0, 3], p: 'R', kind: 'spark' },
      { at: [1, 4], p: 'RR' },
    ],
  },
  91: {
    w: 5, h: 5,
    tip: 'Phantom arrows glide straight through other arrows — but never through stone.',
    walls: [[2, 4]],
    arrows: [
      { at: [0, 2], p: 'RR', kind: 'ghost' },
      { at: [3, 0], p: 'DDDD' },
      { at: [4, 4], p: 'UUUU' },
      { at: [0, 0], p: 'D' },
      { at: [1, 4], p: 'U' },
    ],
  },
};
