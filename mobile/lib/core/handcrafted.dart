// Hand-authored tutorial levels — verbatim port of js/core/handcrafted.js.
import 'model.dart';

class HandLevel {
  const HandLevel({
    required this.w,
    required this.h,
    required this.tip,
    required this.arrows,
    this.walls = const [],
    this.portals = const [],
    this.gates = const [],
    this.cwalls = const [],
    this.blockers = const [],
  });

  final int w, h;
  final String tip;
  final List<ArrowSpec> arrows;
  final List<Cell> walls;
  final List<(Cell, Cell)> portals;
  final List<Gate> gates;
  final List<ColorWall> cwalls;
  final List<Blocker> blockers;

  Level build(Object id) => Level(
        id: id,
        w: w,
        h: h,
        tip: tip,
        arrows: [for (final a in arrows) a.build()],
        walls: List.of(walls),
        portals: List.of(portals),
        gates: List.of(gates),
        cwalls: List.of(cwalls),
        blockers: List.of(blockers),
      );
}

const Map<int, HandLevel> handcrafted = {
  1: HandLevel(
    w: 4,
    h: 5,
    tip: 'Tap an arrow to launch it. It flies off the loom in the direction its head points.',
    arrows: [ArrowSpec((0, 3), p: 'UU'), ArrowSpec((1, 1), p: 'DD'), ArrowSpec((3, 4), p: 'UUU')],
  ),
  2: HandLevel(
    w: 5,
    h: 5,
    tip: 'An arrow can only leave when its whole lane is clear. Find the right order.',
    arrows: [ArrowSpec((0, 2), p: 'RRR'), ArrowSpec((4, 4), p: 'UU'), ArrowSpec((1, 0), p: 'D'), ArrowSpec((3, 0), p: 'L')],
  ),
  3: HandLevel(
    w: 5,
    h: 5,
    tip: 'Threads bend and weave — only the head decides where an arrow goes.',
    arrows: [
      ArrowSpec((0, 4), p: 'UUUR'),
      ArrowSpec((3, 0), p: 'DDRD'),
      ArrowSpec((1, 3), p: 'RR'),
      ArrowSpec((1, 4), p: 'RRR'),
      ArrowSpec((2, 0), p: 'L'),
    ],
  ),
  11: HandLevel(
    w: 5,
    h: 5,
    tip: 'Stone blocks never move. Weave your lanes around them.',
    walls: [(2, 2), (1, 0)],
    arrows: [
      ArrowSpec((1, 3), p: 'UUR'),
      ArrowSpec((3, 3), p: 'UU'),
      ArrowSpec((4, 0), p: 'DDDD'),
      ArrowSpec((0, 4), p: 'RRR'),
      ArrowSpec((0, 1), p: 'U'),
      ArrowSpec((0, 2), p: 'D'),
    ],
  ),
  21: HandLevel(
    w: 5,
    h: 5,
    tip: 'Spinners turn a quarter clockwise every time you launch another arrow. Time them well.',
    arrows: [
      ArrowSpec((2, 2), d: 'U', kind: 'rotator'),
      ArrowSpec((0, 0), p: 'RRRR'),
      ArrowSpec((4, 4), p: 'LLLL'),
      ArrowSpec((4, 1), p: 'DD'),
    ],
  ),
  31: HandLevel(
    w: 5,
    h: 5,
    tip: 'Locked arrows open after the number of launches shown on their padlock.',
    arrows: [
      ArrowSpec((0, 0), p: 'DDD'),
      ArrowSpec((2, 4), p: 'UUU', lock: 2),
      ArrowSpec((4, 0), p: 'DDDD'),
      ArrowSpec((3, 1), p: 'DD', lock: 3),
    ],
  ),
  41: HandLevel(
    w: 6,
    h: 6,
    tip: 'Portals are linked in pairs. A lane that enters one continues out of its twin.',
    portals: [((1, 1), (4, 4))],
    arrows: [
      ArrowSpec((1, 4), p: 'UU'),
      ArrowSpec((4, 3), p: 'UUU'),
      ArrowSpec((5, 5), p: 'LLL'),
      ArrowSpec((0, 0), p: 'RRR'),
      ArrowSpec((3, 3), p: 'L'),
    ],
  ),
  51: HandLevel(
    w: 5,
    h: 5,
    tip: 'Gates only let arrows through in the direction of their chevrons.',
    gates: [Gate(2, 2, 1), Gate(2, 1, 3)],
    arrows: [ArrowSpec((0, 2), p: 'R'), ArrowSpec((4, 4), p: 'UU'), ArrowSpec((4, 1), p: 'L'), ArrowSpec((3, 4), p: 'U')],
  ),
  61: HandLevel(
    w: 5,
    h: 5,
    tip: 'Colour barriers rise and fall. Launching a switch arrow flips which colour is raised.',
    cwalls: [ColorWall(2, 2, 0), ColorWall(2, 1, 1)],
    arrows: [
      ArrowSpec((0, 2), p: 'R'),
      ArrowSpec((4, 4), p: 'LL', kind: 'switch'),
      ArrowSpec((0, 1), p: 'R'),
      ArrowSpec((3, 0), p: 'L'),
    ],
  ),
  71: HandLevel(
    w: 6,
    h: 5,
    tip: 'Drifters glide one step along their track every time you launch an arrow.',
    blockers: [Blocker([(2, 2), (3, 2), (4, 2)])],
    arrows: [ArrowSpec((2, 4), p: 'U'), ArrowSpec((0, 0), p: 'RRR'), ArrowSpec((5, 4), p: 'UUU'), ArrowSpec((4, 4), p: 'U')],
  ),
  81: HandLevel(
    w: 5,
    h: 5,
    tip: 'Spark arrows launch themselves the instant their lane opens. Set off chain reactions!',
    arrows: [
      ArrowSpec((4, 0), p: 'DDDD'),
      ArrowSpec((0, 1), p: 'RR', kind: 'spark'),
      ArrowSpec((2, 3), p: 'U', kind: 'spark'),
      ArrowSpec((0, 3), p: 'R', kind: 'spark'),
      ArrowSpec((1, 4), p: 'RR'),
    ],
  ),
  91: HandLevel(
    w: 5,
    h: 5,
    tip: 'Phantom arrows glide straight through other arrows — but never through stone.',
    walls: [(2, 4)],
    arrows: [
      ArrowSpec((0, 2), p: 'RR', kind: 'ghost'),
      ArrowSpec((3, 0), p: 'DDDD'),
      ArrowSpec((4, 4), p: 'UUUU'),
      ArrowSpec((0, 0), p: 'D'),
      ArrowSpec((1, 4), p: 'U'),
    ],
  ),
};
