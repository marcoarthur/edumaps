// src/sw.js
//
// Service Worker do EduMaps — RASCUNHO/base.
//
// Serviço básico provido hoje: **app shell offline**. Os demais serviços ainda
// não têm planejamento; este arquivo é o ponto de partida.
//
// Estratégias deliberadamente simples (para não virar "cache complexo"):
//   - install  : precache do app shell + skipWaiting
//   - activate : limpa caches de versões antigas + clients.claim
//   - navigate : network-first, com fallback para o shell em cache (offline)
//   - /api/    : network-only (nunca servido do cache)
//   - estáticos: stale-while-revalidate (serve do cache e atualiza em background)
//
// O build (vite-plugin-pwa, estratégia `injectManifest`) injeta em
// `self.__WB_MANIFEST` a lista de assets com hash. Consumimos apenas o `.url`
// dessa lista para o precache — sem trazer o runtime do Workbox.

// Injetado pelo build (Workbox precache manifest): [{ url, revision }, ...].
const INJECTED_MANIFEST = self.__WB_MANIFEST || [];

const CACHE_VERSION = "edumaps-v1";
const APP_SHELL = ["/", "/index.html", "/favicon.svg", "/manifest.webmanifest"];

const PRECACHE = [
  ...new Set([
    ...APP_SHELL,
    ...INJECTED_MANIFEST.map((entry) =>
      typeof entry === "string" ? entry : entry.url
    ),
  ]),
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== CACHE_VERSION)
            .map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const { request } = event;

  // Só GET é cacheável/servível.
  if (request.method !== "GET") return;

  const url = new URL(request.url);

  // Navegação (SPA): rede primeiro; se offline, serve o shell em cache.
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match("/index.html")));
    return;
  }

  // API: sempre rede (sem cache).
  if (url.pathname.startsWith("/api/")) return;

  // Estáticos same-origin: stale-while-revalidate.
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const fetched = fetch(request)
          .then((response) => {
            if (response && response.ok) {
              const copy = response.clone();
              caches
                .open(CACHE_VERSION)
                .then((cache) => cache.put(request, copy));
            }
            return response;
          })
          .catch(() => cached);

        return cached || fetched;
      })
    );
  }
});
