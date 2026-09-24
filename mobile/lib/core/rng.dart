// Deterministic seeded RNG — a bit-exact port of js/core/rng.js so procedural
// levels and daily puzzles are identical to the PWA on every device.

const int _m32 = 0xFFFFFFFF;

/// 32-bit integer multiply (low 32 bits), identical to JavaScript's Math.imul.
int imul32(int a, int b) {
  a &= _m32;
  b &= _m32;
  final ah = a >> 16;
  final al = a & 0xFFFF;
  return ((al * b) + (((ah * b) & 0xFFFF) << 16)) & _m32;
}

int hashString(String str) {
  var h = 2166136261;
  for (var i = 0; i < str.length; i++) {
    h = imul32(h ^ str.codeUnitAt(i), 16777619);
  }
  return h;
}

class Rng {
  Rng(int seed) : _a = seed & _m32;

  int _a;

  double float() {
    _a = (_a + 0x6d2b79f5) & _m32;
    var t = imul32(_a ^ (_a >> 15), 1 | _a);
    t = ((t + imul32(t ^ (t >> 7), 61 | t)) & _m32) ^ t;
    return ((t ^ (t >> 14)) & _m32) / 4294967296;
  }

  int nextInt(int min, int max) => min + (float() * (max - min + 1)).floor();

  bool chance(double p) => float() < p;

  T pick<T>(List<T> list) => list[(float() * list.length).floor()];

  List<T> shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = (float() * (i + 1)).floor();
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }
}
