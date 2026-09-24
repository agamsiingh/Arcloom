// ARCLOOM bootstrap: load save, apply settings, register screens + offline cache.
import * as store from './services/storage.js';
import * as audio from './services/audio.js';
import { registerScreen, go, initHistory } from './ui/dom.js';
import { applySettings, settingsScreen } from './ui/settings.js';
import { homeScreen, levelsScreen } from './ui/screens.js';
import { dailyScreen, trophiesScreen, shopScreen } from './ui/meta.js';
import { gameScreen } from './game/controller.js';

store.load();
applySettings();

registerScreen('home', homeScreen);
registerScreen('levels', levelsScreen);
registerScreen('game', gameScreen);
registerScreen('daily', dailyScreen);
registerScreen('trophies', trophiesScreen);
registerScreen('settings', settingsScreen);
registerScreen('shop', shopScreen);

// Browsers only allow audio after a user gesture.
const unlockAudio = () => audio.unlock();
window.addEventListener('pointerdown', unlockAudio, { once: true, capture: true });
window.addEventListener('keydown', unlockAudio, { once: true, capture: true });

initHistory();
go('home');
document.getElementById('boot')?.remove();

if ('serviceWorker' in navigator && location.protocol !== 'file:') {
  window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
}
