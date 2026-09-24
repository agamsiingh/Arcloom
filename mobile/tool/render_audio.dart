// Offline renderer for ARCLOOM's original synthesized audio.
// Re-implements the PWA's Web Audio synth (js/services/audio.js): the same
// oscillators, exponential envelopes/glides, biquad filters, noise and delay,
// rendered to 16-bit WAV assets. Run from mobile/: dart run tool/render_audio.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:arcloom/core/rng.dart';

const int sfxRate = 44100;
const int musicRate = 22050;

class Buf {
  Buf(this.rate, double seconds) : data = Float64List((seconds * rate).ceil());
  final int rate;
  Float64List data;
}

class Biquad {
  Biquad(this.type, this.rate);
  final String type;
  final int rate;
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0, x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  void set(double freq, double q) {
    final f = freq.clamp(10, rate / 2 - 100).toDouble();
    final w0 = 2 * math.pi * f / rate;
    final cw = math.cos(w0), sw = math.sin(w0);
    // Web Audio: lowpass/highpass Q is in dB, bandpass Q is linear.
    final qLin = type == 'bandpass' ? q : math.pow(10, q / 20).toDouble();
    final alpha = sw / (2 * qLin);
    final a0 = 1 + alpha;
    switch (type) {
      case 'lowpass':
        b0 = (1 - cw) / 2 / a0;
        b1 = (1 - cw) / a0;
        b2 = b0;
      case 'highpass':
        b0 = (1 + cw) / 2 / a0;
        b1 = -(1 + cw) / a0;
        b2 = b0;
      default: // bandpass (constant 0 dB peak gain)
        b0 = alpha / a0;
        b1 = 0;
        b2 = -alpha / a0;
    }
    a1 = -2 * cw / a0;
    a2 = (1 - alpha) / a0;
  }

  double run(double x) {
    final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

double _env(double tau, double attack, double dur, double gain) {
  if (tau < attack) return 0.0001 * math.pow(gain / 0.0001, tau / attack);
  return gain * math.pow(0.0001 / gain, (tau - attack) / math.max(1e-6, dur - attack));
}

double _osc(String type, double p) {
  final ph = p - p.floorToDouble();
  switch (type) {
    case 'triangle':
      return 1 - 4 * (ph - 0.5).abs();
    case 'square':
      return ph < 0.5 ? 1 : -1;
    default:
      return math.sin(2 * math.pi * ph);
  }
}

void tone(Buf out, double freq,
    {String type = 'sine', double dur = 0.2, double attack = 0.005, double gain = 0.2, double when = 0,
    double? glide, double? filter, Buf? send, double sendGain = 0}) {
  final start = (when * out.rate).round();
  final n = ((dur + 0.05) * out.rate).round();
  final lp = filter != null ? (Biquad('lowpass', out.rate)..set(filter, 1)) : null;
  var phase = 0.0;
  for (var k = 0; k < n; k++) {
    final idx = start + k;
    if (idx >= out.data.length) break;
    final tau = k / out.rate;
    final f = glide != null && tau <= dur ? freq * math.pow(glide / freq, tau / dur) : (glide ?? freq);
    phase += f / out.rate;
    var v = _osc(type, phase);
    if (lp != null) v = lp.run(v);
    final g = tau <= dur ? _env(tau, attack, dur, gain) : 0.0001;
    out.data[idx] += v * g;
    if (send != null) send.data[idx] += v * g * sendGain;
  }
}

final _noiseRng = math.Random(7);

void noise(Buf out,
    {double dur = 0.1, String type = 'bandpass', double freq = 1000, double? to, double q = 1, double gain = 0.2, double when = 0}) {
  final start = (when * out.rate).round();
  final n = ((dur + 0.05) * out.rate).round();
  final flt = Biquad(type, out.rate)..set(freq, q);
  for (var k = 0; k < n; k++) {
    final idx = start + k;
    if (idx >= out.data.length) break;
    final tau = k / out.rate;
    if (to != null && k % 16 == 0) flt.set(tau <= dur ? freq * math.pow(to / freq, tau / dur) : to, q);
    final v = flt.run(_noiseRng.nextDouble() * 2 - 1);
    final g = tau <= dur ? _env(tau, 0.008, dur, gain) : 0.0001;
    out.data[idx] += v * g;
  }
}

double semis(double base, num n) => base * math.pow(2, n / 12);
const penta = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24];

void writeWav(String path, Buf b, {double normalizeTo = 0}) {
  final d = b.data;
  var peak = 0.0;
  for (final v in d) {
    peak = math.max(peak, v.abs());
  }
  // Web Audio's master compressor: here a gentle safety limit / optional normalize.
  final scale = normalizeTo > 0 && peak > 0 ? normalizeTo / peak : (peak > 0.98 ? 0.98 / peak : 1.0);
  final bytes = BytesBuilder();
  final dataLen = d.length * 2;
  void u32(int v) => bytes.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => bytes.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  bytes.add('RIFF'.codeUnits);
  u32(36 + dataLen);
  bytes.add('WAVEfmt '.codeUnits);
  u32(16);
  u16(1);
  u16(1);
  u32(b.rate);
  u32(b.rate * 2);
  u16(2);
  u16(16);
  bytes.add('data'.codeUnits);
  u32(dataLen);
  final pcm = ByteData(dataLen);
  for (var i = 0; i < d.length; i++) {
    pcm.setInt16(i * 2, (d[i] * scale * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());
  File(path).writeAsBytesSync(bytes.toBytes());
}

Buf sfx(double seconds, void Function(Buf b) fn) {
  final b = Buf(sfxRate, seconds);
  fn(b);
  return b;
}

Map<String, Buf> renderSfx() {
  final m = <String, Buf>{
    'ui': sfx(0.12, (b) => tone(b, 880, type: 'triangle', dur: 0.05, gain: 0.08)),
    'tap': sfx(0.12, (b) {
      noise(b, dur: 0.03, type: 'highpass', freq: 3500, gain: 0.12);
      tone(b, 1500, dur: 0.04, gain: 0.07);
    }),
    'select': sfx(0.15, (b) => tone(b, 1100, type: 'triangle', dur: 0.08, gain: 0.08, glide: 1320)),
    'bump': sfx(0.25, (b) {
      tone(b, 120, dur: 0.16, gain: 0.35, glide: 60);
      noise(b, dur: 0.07, type: 'lowpass', freq: 500, gain: 0.25);
    }),
    'locked': sfx(0.2, (b) {
      tone(b, 260, type: 'square', dur: 0.05, gain: 0.05, filter: 900);
      tone(b, 220, type: 'square', dur: 0.06, gain: 0.05, filter: 900, when: 0.07);
    }),
    'unlock': sfx(0.5, (b) {
      tone(b, 1318, type: 'triangle', dur: 0.25, gain: 0.12);
      tone(b, 1975, type: 'triangle', dur: 0.35, gain: 0.1, when: 0.07);
    }),
    'rotate': sfx(0.12, (b) {
      tone(b, 700, dur: 0.03, gain: 0.05);
      tone(b, 1050, dur: 0.03, gain: 0.04, when: 0.03);
    }),
    'portal': sfx(0.4, (b) {
      tone(b, 300, dur: 0.28, gain: 0.08, glide: 1400);
      noise(b, dur: 0.2, freq: 3000, to: 800, q: 6, gain: 0.06, when: 0.05);
    }),
    'toggle': sfx(0.3, (b) {
      tone(b, 440, type: 'square', dur: 0.08, gain: 0.05, filter: 1600);
      tone(b, 660, type: 'square', dur: 0.12, gain: 0.05, filter: 1600, when: 0.08);
    }),
    'hint': sfx(0.45, (b) {
      tone(b, 988, dur: 0.18, gain: 0.08);
      tone(b, 1319, dur: 0.28, gain: 0.08, when: 0.1);
    }),
    'complete': sfx(1.3, (b) {
      const notes = [0, 4, 7, 11, 12, 16];
      for (var i = 0; i < notes.length; i++) {
        tone(b, semis(392, notes[i]), type: 'triangle', dur: 0.7, gain: 0.1, when: i * 0.07);
        tone(b, semis(784, notes[i]), dur: 0.4, gain: 0.04, when: i * 0.07 + 0.02);
      }
      noise(b, dur: 0.6, type: 'highpass', freq: 7000, gain: 0.04, when: 0.3);
    }),
    'fail': sfx(0.8, (b) {
      tone(b, 392, type: 'triangle', dur: 0.3, gain: 0.1);
      tone(b, 330, type: 'triangle', dur: 0.5, gain: 0.1, when: 0.18);
    }),
  };
  for (var p = 0; p <= 10; p++) {
    m['slide_$p'] = sfx(0.35, (b) {
      noise(b, dur: 0.24, freq: 500, to: 2600, q: 1.4, gain: 0.16);
      tone(b, semis(330, penta[p]), type: 'triangle', dur: 0.2, gain: 0.1, glide: semis(660, penta[p]));
    });
  }
  for (var d = 1; d <= 8; d++) {
    final n = penta[math.min(d + 2, penta.length - 1)];
    m['chain_$d'] = sfx(0.4, (b) {
      tone(b, semis(523, n), type: 'triangle', dur: 0.3, gain: 0.14);
      tone(b, semis(1046, n), dur: 0.22, gain: 0.06, when: 0.01);
      noise(b, dur: 0.08, type: 'highpass', freq: 6000, gain: 0.05);
    });
  }
  for (var mult = 2; mult <= 5; mult++) {
    final f = semis(784, (mult - 2) * 2);
    m['combo_$mult'] = sfx(0.6, (b) {
      tone(b, f, dur: 0.5, gain: 0.1);
      tone(b, f * 2.76, dur: 0.3, gain: 0.03);
      tone(b, f * 1.5, type: 'triangle', dur: 0.4, gain: 0.05, when: 0.06);
    });
  }
  for (var i = 0; i < 3; i++) {
    m['star_$i'] = sfx(0.45, (b) => tone(b, semis(880, const [0, 4, 7][i]), type: 'triangle', dur: 0.35, gain: 0.12));
  }
  return m;
}

/// Generative ambient loop (same chords, tempo and pluck probability as the PWA).
Buf renderMusic() {
  const chords = [
    [50, 57, 62, 66, 69, 76],
    [47, 54, 59, 62, 66, 73],
    [43, 50, 55, 59, 62, 69],
    [45, 52, 57, 61, 64, 71],
  ];
  double midi(int m) => 440 * math.pow(2, (m - 69) / 12).toDouble();
  const beat = 60 / 68;
  const steps = 8 * 4 * 4; // 4 passes through the progression
  const loopLen = steps * beat / 2;
  const tail = beat * 9 + 4;
  final dry = Buf(musicRate, loopLen + tail);
  final send = Buf(musicRate, loopLen + tail);
  final rng = Rng(hashString('arcloom-music'));
  for (var step = 0; step < steps; step++) {
    final chord = chords[(step ~/ 8) % chords.length];
    final when = step * beat / 2;
    if (step % 8 == 0) {
      for (final n in chord.take(4)) {
        tone(dry, midi(n), dur: beat * 9, attack: 1.6, gain: 0.05, when: when, filter: 900);
      }
    }
    if (rng.float() < 0.38) {
      final n = chord[2 + (rng.float() * 4).floor()] + 12;
      tone(dry, midi(n), type: 'triangle', dur: 1.4, attack: 0.01, gain: 0.035, when: when, filter: 2400, send: send, sendGain: 0.8);
    }
  }
  // Feedback delay (0.42 s, fb 0.32, wet 0.28) on the send bus.
  final dl = (0.42 * musicRate).round();
  final d = send.data;
  final delayed = Float64List(d.length);
  for (var i = 0; i < d.length; i++) {
    final fb = i >= dl ? delayed[i - dl] : 0.0;
    delayed[i] = (i >= dl ? d[i - dl] : 0.0) + fb * 0.32;
    dry.data[i] += delayed[i] * 0.28;
  }
  // Fold the tail back onto the start so the loop is seamless.
  final n = (loopLen * musicRate).round();
  final looped = Buf(musicRate, loopLen);
  for (var i = 0; i < dry.data.length; i++) {
    looped.data[i % n] += dry.data[i];
  }
  return looped;
}

void main() {
  Directory('assets/audio').createSync(recursive: true);
  final all = renderSfx();
  all.forEach((name, b) => writeWav('assets/audio/$name.wav', b));
  writeWav('assets/audio/music.wav', renderMusic(), normalizeTo: 0.7);
  stdout.writeln('Rendered ${all.length} sound effects + music loop into assets/audio/');
}
