// Original synthesized sound effects and generative ambient music (Web Audio, no asset files).

let ctx = null;
let master, sfxBus, musicBus, delay, delayFb, delayWet, noiseBuf;
const cfg = { sound: true, soundVolume: 0.8, music: true, musicVolume: 0.35 };
let musicTimer = null;
let musicNextTime = 0;
let musicStep = 0;

function ensure() {
  if (ctx) return ctx;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return null;
  ctx = new AC();
  master = ctx.createDynamicsCompressor();
  master.threshold.value = -14;
  master.ratio.value = 4;
  master.connect(ctx.destination);
  sfxBus = ctx.createGain();
  musicBus = ctx.createGain();
  sfxBus.connect(master);
  musicBus.connect(master);
  delay = ctx.createDelay(1);
  delay.delayTime.value = 0.42;
  delayFb = ctx.createGain();
  delayFb.gain.value = 0.32;
  delayWet = ctx.createGain();
  delayWet.gain.value = 0.28;
  delay.connect(delayFb).connect(delay);
  delay.connect(delayWet).connect(musicBus);
  noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
  const d = noiseBuf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  applyVolumes();
  return ctx;
}

function applyVolumes() {
  if (!ctx) return;
  const t = ctx.currentTime;
  sfxBus.gain.setTargetAtTime(cfg.sound ? cfg.soundVolume : 0, t, 0.02);
  musicBus.gain.setTargetAtTime(cfg.music ? cfg.musicVolume * 0.5 : 0, t, 0.4);
}

export function unlock() {
  const c = ensure();
  if (c && c.state === 'suspended') c.resume();
  if (cfg.music) startMusic();
}

export function configure(settings) {
  Object.assign(cfg, {
    sound: settings.sound, soundVolume: settings.soundVolume,
    music: settings.music, musicVolume: settings.musicVolume,
  });
  applyVolumes();
  if (ctx) {
    if (cfg.music) startMusic();
    else stopMusic();
  }
}

document.addEventListener('visibilitychange', () => {
  if (!ctx) return;
  if (document.hidden) ctx.suspend();
  else ctx.resume();
});

function tone(freq, { type = 'sine', dur = 0.2, attack = 0.005, gain = 0.2, when = 0, glide = null, bus = sfxBus, filter = null, send = 0 } = {}) {
  const t = ctx.currentTime + when;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (glide) o.frequency.exponentialRampToValueAtTime(glide, t + dur);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  let node = o;
  if (filter) {
    const f = ctx.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = filter;
    o.connect(f);
    node = f;
  }
  node.connect(g).connect(bus);
  if (send) {
    const s = ctx.createGain();
    s.gain.value = send;
    g.connect(s).connect(delay);
  }
  o.start(t);
  o.stop(t + dur + 0.05);
}

function noise({ dur = 0.1, type = 'bandpass', freq = 1000, to = null, q = 1, gain = 0.2, when = 0 } = {}) {
  const t = ctx.currentTime + when;
  const src = ctx.createBufferSource();
  src.buffer = noiseBuf;
  const f = ctx.createBiquadFilter();
  f.type = type;
  f.Q.value = q;
  f.frequency.setValueAtTime(freq, t);
  if (to) f.frequency.exponentialRampToValueAtTime(to, t + dur);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  src.connect(f).connect(g).connect(sfxBus);
  src.start(t, Math.random() * 0.5);
  src.stop(t + dur + 0.05);
}

const semis = (base, n) => base * Math.pow(2, n / 12);
const PENTA = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24];

function play(fn) {
  if (!cfg.sound || !ensure()) return;
  try { fn(); } catch { /* audio is best-effort */ }
}

export const sfx = {
  ui: () => play(() => tone(880, { type: 'triangle', dur: 0.05, gain: 0.08 })),
  tap: () => play(() => {
    noise({ dur: 0.03, type: 'highpass', freq: 3500, gain: 0.12 });
    tone(1500, { dur: 0.04, gain: 0.07 });
  }),
  select: () => play(() => tone(1100, { type: 'triangle', dur: 0.08, gain: 0.08, glide: 1320 })),
  slide: (step = 0) => play(() => {
    const p = Math.min(step, 10);
    noise({ dur: 0.24, freq: 500, to: 2600, q: 1.4, gain: 0.16 });
    tone(semis(330, PENTA[p]), { type: 'triangle', dur: 0.2, gain: 0.1, glide: semis(660, PENTA[p]) });
  }),
  bump: () => play(() => {
    tone(120, { dur: 0.16, gain: 0.35, glide: 60 });
    noise({ dur: 0.07, type: 'lowpass', freq: 500, gain: 0.25 });
  }),
  locked: () => play(() => {
    tone(260, { type: 'square', dur: 0.05, gain: 0.05, filter: 900 });
    tone(220, { type: 'square', dur: 0.06, gain: 0.05, filter: 900, when: 0.07 });
  }),
  unlock: () => play(() => {
    tone(1318, { type: 'triangle', dur: 0.25, gain: 0.12 });
    tone(1975, { type: 'triangle', dur: 0.35, gain: 0.1, when: 0.07 });
  }),
  rotate: () => play(() => {
    tone(700, { dur: 0.03, gain: 0.05 });
    tone(1050, { dur: 0.03, gain: 0.04, when: 0.03 });
  }),
  portal: () => play(() => {
    tone(300, { dur: 0.28, gain: 0.08, glide: 1400 });
    noise({ dur: 0.2, freq: 3000, to: 800, q: 6, gain: 0.06, when: 0.05 });
  }),
  toggle: () => play(() => {
    tone(440, { type: 'square', dur: 0.08, gain: 0.05, filter: 1600 });
    tone(660, { type: 'square', dur: 0.12, gain: 0.05, filter: 1600, when: 0.08 });
  }),
  chain: (depth = 1) => play(() => {
    const n = PENTA[Math.min(depth + 2, PENTA.length - 1)];
    tone(semis(523, n), { type: 'triangle', dur: 0.3, gain: 0.14 });
    tone(semis(1046, n), { dur: 0.22, gain: 0.06, when: 0.01 });
    noise({ dur: 0.08, type: 'highpass', freq: 6000, gain: 0.05 });
  }),
  combo: (mult = 2) => play(() => {
    const f = semis(784, (mult - 2) * 2);
    tone(f, { dur: 0.5, gain: 0.1 });
    tone(f * 2.76, { dur: 0.3, gain: 0.03 });
    tone(f * 1.5, { type: 'triangle', dur: 0.4, gain: 0.05, when: 0.06 });
  }),
  hint: () => play(() => {
    tone(988, { dur: 0.18, gain: 0.08 });
    tone(1319, { dur: 0.28, gain: 0.08, when: 0.1 });
  }),
  star: (i = 0) => play(() => tone(semis(880, [0, 4, 7][i] || 0), { type: 'triangle', dur: 0.35, gain: 0.12 })),
  complete: () => play(() => {
    [0, 4, 7, 11, 12, 16].forEach((n, i) => {
      tone(semis(392, n), { type: 'triangle', dur: 0.7, gain: 0.1, when: i * 0.07 });
      tone(semis(784, n), { dur: 0.4, gain: 0.04, when: i * 0.07 + 0.02 });
    });
    noise({ dur: 0.6, type: 'highpass', freq: 7000, gain: 0.04, when: 0.3 });
  }),
  fail: () => play(() => {
    tone(392, { type: 'triangle', dur: 0.3, gain: 0.1 });
    tone(330, { type: 'triangle', dur: 0.5, gain: 0.1, when: 0.18 });
  }),
};

// --- Generative ambient music -------------------------------------------------
const CHORDS = [
  [50, 57, 62, 66, 69, 76], // D maj9
  [47, 54, 59, 62, 66, 73], // B m9
  [43, 50, 55, 59, 62, 69], // G maj9
  [45, 52, 57, 61, 64, 71], // A add9
];
const midi = (m) => 440 * Math.pow(2, (m - 69) / 12);
const BEAT = 60 / 68;

function scheduleMusic() {
  if (!ctx || !cfg.music) return;
  while (musicNextTime < ctx.currentTime + 1.2) {
    const bar = Math.floor(musicStep / 8);
    const chord = CHORDS[bar % CHORDS.length];
    const when = musicNextTime - ctx.currentTime;
    if (musicStep % 8 === 0) {
      for (const n of chord.slice(0, 4)) {
        tone(midi(n), { type: 'sine', dur: BEAT * 9, attack: 1.6, gain: 0.05, when, bus: musicBus, filter: 900 });
      }
    }
    if (Math.random() < 0.38) {
      const n = chord[2 + Math.floor(Math.random() * 4)] + 12;
      tone(midi(n), { type: 'triangle', dur: 1.4, attack: 0.01, gain: 0.035, when, bus: musicBus, filter: 2400, send: 0.8 });
    }
    musicNextTime += BEAT / 2;
    musicStep++;
  }
}

export function startMusic() {
  if (!ensure() || musicTimer) return;
  musicNextTime = ctx.currentTime + 0.1;
  musicTimer = setInterval(scheduleMusic, 250);
  scheduleMusic();
}

export function stopMusic() {
  if (musicTimer) clearInterval(musicTimer);
  musicTimer = null;
}
