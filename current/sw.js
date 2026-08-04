/* Orion service worker — offline app-shell caching.
   Cache-first for the app shell + same-origin assets; the Anthropic API and the
   Moon Core worker are NEVER cached (always network) so chat and cloud sync
   behave correctly online and simply fail-soft offline. */
const CACHE = 'orion-v11';   /* BUMP THIS on every deploy — a stale cache name serves old code */
const SHELL = ['./', './index.html', './manifest.webmanifest',
               './icon-192.png', './icon-512.png', './icon-512-maskable.png', './apple-touch-icon.png'];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => Promise.allSettled(SHELL.map((u) => c.add(u)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  let url; try { url = new URL(req.url); } catch (_) { return; }
  if (url.hostname.indexOf('anthropic.com') !== -1 || url.hostname.indexOf('workers.dev') !== -1) return;
  e.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((resp) => {
        if (resp && resp.ok && url.origin === self.location.origin) {
          const copy = resp.clone(); caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        }
        return resp;
      }).catch(() => {
        if (req.mode === 'navigate') return caches.match('./index.html').then((m) => m || caches.match('./'));
        return Response.error();
      });
    })
  );
});
