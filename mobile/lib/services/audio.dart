// Sound effects + ambient music. Assets are rendered from the PWA's synth by
// tool/render_audio.dart and played through SoLoud (low-latency, overlapping voices).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'storage.dart';

/// Every sound asset name (`assets/audio/NAME.wav`).
final List<String> sfxNames = [
  'ui', 'tap', 'select', 'bump', 'locked', 'unlock', 'rotate', 'portal', 'toggle', 'hint', 'complete', 'fail',
  for (var i = 0; i <= 10; i++) 'slide_$i',
  for (var i = 1; i <= 8; i++) 'chain_$i',
  for (var i = 2; i <= 5; i++) 'combo_$i',
  for (var i = 0; i < 3; i++) 'star_$i',
];

abstract class AudioBackend {
  Future<void> init();
  void playSfx(String name, double volume);
  void setMusic({required bool on, required double volume});
  void pause();
  void resume();
}

/// Game-facing API, mirroring the PWA's `sfx` object.
class GameAudio {
  GameAudio(this.backend);

  final AudioBackend backend;
  bool _sound = true;
  double _soundVolume = 0.8;

  void configure(Settings s) {
    _sound = s.sound;
    _soundVolume = s.soundVolume;
    backend.setMusic(on: s.music, volume: s.musicVolume * 0.5);
  }

  void _play(String name) {
    if (_sound && _soundVolume > 0) backend.playSfx(name, _soundVolume);
  }

  void ui() => _play('ui');
  void tap() => _play('tap');
  void select() => _play('select');
  void slide([int step = 0]) => _play('slide_${step.clamp(0, 10)}');
  void bump() => _play('bump');
  void locked() => _play('locked');
  void unlock() => _play('unlock');
  void rotate() => _play('rotate');
  void portal() => _play('portal');
  void toggle() => _play('toggle');
  void chain([int depth = 1]) => _play('chain_${depth.clamp(1, 8)}');
  void combo([int mult = 2]) => _play('combo_${mult.clamp(2, 5)}');
  void hint() => _play('hint');
  void star([int i = 0]) => _play('star_${i.clamp(0, 2)}');
  void complete() => _play('complete');
  void fail() => _play('fail');

  void pause() => backend.pause();
  void resume() => backend.resume();
}

class SoloudBackend implements AudioBackend {
  final Map<String, AudioSource> _sources = {};
  AudioSource? _music;
  SoundHandle? _musicHandle;
  bool _musicOn = false;
  double _musicVolume = 0.175;
  bool _paused = false;
  bool _ready = false;

  @override
  Future<void> init() async {
    try {
      await SoLoud.instance.init();
      SoLoud.instance.setMaxActiveVoiceCount(24);
      await Future.wait([
        for (final n in sfxNames)
          SoLoud.instance.loadAsset('assets/audio/$n.wav').then((s) => _sources[n] = s),
      ]);
      _music = await SoLoud.instance.loadAsset('assets/audio/music.wav');
      _ready = true;
      _applyMusic();
    } catch (e) {
      // Audio is optional: the game stays fully playable without it.
      debugPrint('Audio unavailable: $e');
      _ready = false;
    }
  }

  @override
  void playSfx(String name, double volume) {
    final src = _sources[name];
    if (!_ready || _paused || src == null) return;
    try {
      SoLoud.instance.play(src, volume: math.min(1, volume));
    } catch (e) {
      debugPrint('sfx $name failed: $e');
    }
  }

  @override
  void setMusic({required bool on, required double volume}) {
    _musicOn = on;
    _musicVolume = volume;
    _applyMusic();
  }

  void _applyMusic() {
    if (!_ready || _music == null) return;
    try {
      if (_musicOn && !_paused) {
        final h = _musicHandle;
        if (h == null) {
          _musicHandle = SoLoud.instance.play(_music!, volume: _musicVolume, looping: true);
          SoLoud.instance.setProtectVoice(_musicHandle!, true);
        } else {
          SoLoud.instance.setVolume(h, _musicVolume);
          SoLoud.instance.setPause(h, false);
        }
      } else if (_musicHandle != null) {
        SoLoud.instance.setPause(_musicHandle!, true);
      }
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  @override
  void pause() {
    _paused = true;
    _applyMusic();
  }

  @override
  void resume() {
    _paused = false;
    _applyMusic();
  }
}

/// No-op backend (tests, or when the audio engine cannot start).
class SilentAudioBackend implements AudioBackend {
  final List<String> played = [];
  bool musicOn = false;

  @override
  Future<void> init() async {}
  @override
  void playSfx(String name, double volume) => played.add(name);
  @override
  void setMusic({required bool on, required double volume}) => musicOn = on;
  @override
  void pause() {}
  @override
  void resume() {}
}
