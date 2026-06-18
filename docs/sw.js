/* Ball Blast service worker.
   Network-first for the page so an online launch always runs the latest
   version; falls back to cache only when offline. Static assets are
   cache-first. Bump CACHE to force a clean re-cache on update. */
const CACHE = "ballblast-v3";
const ASSETS = ["./", "./index.html", "./icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;

  const isDoc = req.mode === "navigate" || req.destination === "document";
  if (isDoc) {
    // Network-first: newest page when online, cached page when offline.
    e.respondWith(
      fetch(req).then(res => {
        const clone = res.clone();
        caches.open(CACHE).then(c => c.put(req, clone));
        return res;
      }).catch(() => caches.match(req).then(r => r || caches.match("./index.html")))
    );
  } else {
    // Cache-first for static assets, refreshed in the background.
    e.respondWith(
      caches.match(req).then(cached => {
        const fresh = fetch(req).then(res => {
          if (res && res.ok) {
            const clone = res.clone();
            caches.open(CACHE).then(c => c.put(req, clone));
          }
          return res;
        }).catch(() => cached);
        return cached || fresh;
      })
    );
  }
});
