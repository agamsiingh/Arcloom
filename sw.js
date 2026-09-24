// Offline support: precache the app shell, then serve cache-first and refresh in the background.
const CACHE = 'arcloom-v1';
const SHELL = [
  './', 'index.html', 'manifest.webmanifest',
  'css/base.css', 'css/screens.css', 'css/game.css',
  'assets/icon.svg', 'assets/icon-maskable.svg',
  'js/main.js',
  'js/core/rng.js', 'js/core/model.js', 'js/core/rules.js', 'js/core/solver.js', 'js/core/generator.js',
  'js/core/levels.js', 'js/core/handcrafted.js', 'js/core/baked.js', 'js/core/codec.js',
  'js/game/session.js', 'js/game/draw.js', 'js/game/renderer.js', 'js/game/input.js', 'js/game/controller.js',
  'js/services/storage.js', 'js/services/audio.js', 'js/services/haptics.js', 'js/services/monetization.js',
  'js/services/achievements.js', 'js/services/progress.js',
  'js/ui/dom.js', 'js/ui/settings.js', 'js/ui/screens.js', 'js/ui/meta.js', 'js/ui/gameModals.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(req, { ignoreSearch: true });
      const fresh = fetch(req)
        .then((res) => {
          if (res.ok) cache.put(req, res.clone());
          return res;
        })
        .catch(() => hit);
      return hit || fresh;
    }),
  );
});
