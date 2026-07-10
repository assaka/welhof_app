// Self-destroying service worker.
//
// The app is built with `--pwa-strategy=none`, so no Flutter service worker is
// generated. Browsers that visited earlier still have the old aggressive
// caching worker registered at this URL. On their next visit the browser
// fetches this file as the "updated" worker; it then clears all caches,
// unregisters itself, and reloads open tabs so returning visitors get fresh
// content instead of a stale cached build.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: 'window' });
      for (const client of clients) {
        client.navigate(client.url);
      }
    })(),
  );
});
