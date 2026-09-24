// Compact string encoding for levels — same format as js/core/codec.js, so the
// PWA's baked campaign data is reused verbatim.
import 'model.dart';

const _dch = 'URDL';
const _k2c = {
  Kind.normal: 'n',
  Kind.rotator: 'r',
  Kind.spark: 's',
  Kind.switcher: 'w',
  Kind.ghost: 'g',
};
final _c2k = {for (final e in _k2c.entries) e.value: e.key};

String _moveChar(Cell a, Cell b) {
  for (var d = 0; d < 4; d++) {
    if (a.$1 + dx[d] == b.$1 && a.$2 + dy[d] == b.$2) return _dch[d];
  }
  throw StateError('non-adjacent arrow cells');
}

String encodeLevel(Level level) {
  final arrows = level.arrows.map((a) {
    final path = StringBuffer();
    for (var i = 1; i < a.cells.length; i++) {
      path.write(_moveChar(a.cells[i - 1], a.cells[i]));
    }
    final (x, y) = a.cells.first;
    return '$x,$y,$path,${_dch[a.dir]},${_k2c[a.kind]},${a.lock}';
  }).join(';');
  String pts(List<Cell> list) => list.map((c) => '${c.$1},${c.$2}').join(';');
  return [
    '${level.w},${level.h}',
    arrows,
    pts(level.walls),
    level.portals.map((p) => '${p.$1.$1},${p.$1.$2},${p.$2.$1},${p.$2.$2}').join(';'),
    level.gates.map((g) => '${g.x},${g.y},${g.dir}').join(';'),
    level.cwalls.map((c) => '${c.x},${c.y},${c.c}').join(';'),
    level.blockers.map((b) => b.track.map((c) => '${c.$1},${c.$2}').join(',')).join(';'),
  ].join('|');
}

Level decodeLevel(String str, Object id) {
  final parts = str.split('|');
  List<List<String>> list(String s) => s.isEmpty ? [] : s.split(';').map((p) => p.split(',')).toList();
  final size = parts[0].split(',').map(int.parse).toList();
  return Level(
    id: id,
    w: size[0],
    h: size[1],
    arrows: [
      for (final a in list(parts[1]))
        ArrowSpec(
          (int.parse(a[0]), int.parse(a[1])),
          p: a[2],
          d: a[3],
          kind: switch (_c2k[a[4]]) {
            Kind.rotator => 'rotator',
            Kind.spark => 'spark',
            Kind.switcher => 'switch',
            Kind.ghost => 'ghost',
            _ => 'normal',
          },
          lock: int.parse(a[5]),
        ).build(),
    ],
    walls: [for (final c in list(parts[2])) (int.parse(c[0]), int.parse(c[1]))],
    portals: [
      for (final p in list(parts[3]))
        ((int.parse(p[0]), int.parse(p[1])), (int.parse(p[2]), int.parse(p[3]))),
    ],
    gates: [for (final g in list(parts[4])) Gate(int.parse(g[0]), int.parse(g[1]), int.parse(g[2]))],
    cwalls: [for (final c in list(parts[5])) ColorWall(int.parse(c[0]), int.parse(c[1]), int.parse(c[2]))],
    blockers: [
      for (final nums in list(parts[6]))
        Blocker([for (var i = 0; i < nums.length; i += 2) (int.parse(nums[i]), int.parse(nums[i + 1]))]),
    ],
  );
}
