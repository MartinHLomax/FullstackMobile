const CACHE = "shoppinglist-v1";
const ASSETS = ["./", "./index.html", "./manifest.webmanifest", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);

  // Lad Supabase-kald gå direkte til nettet (ingen caching af API)
  if (url.origin.includes(".supabase.co")) return;

  // Navigations-requests: network-first, fallback til cache (offline)
  if (e.request.mode === "navigate") {
    e.respondWith(
      fetch(e.request)
        .then((r) => {
          const clone = r.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
          return r;
        })
        .catch(() => caches.match("./index.html"))
    );
    return;
  }

  // Statiske assets: cache-first
  e.respondWith(
    caches.match(e.request).then((hit) => {
      return (
        hit ||
        fetch(e.request).then((r) => {
          const clone = r.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
          return r;
        })
      );
    })
  );
});
