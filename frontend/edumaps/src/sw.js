// src/sw.js
//
// Service Worker do EduMaps — app shell offline com cache VERSIONADO POR BUILD
// (issue #225: SPA em branco após deploy).
//
// Versão do cache
//   O build (vite-plugin-pwa, `injectManifest`) injeta em `self.__WB_MANIFEST`
//   a lista `[{ url, revision }]` de todos os arquivos do bundle. O nome do
//   cache é `edumaps-<hash>`, com o hash (FNV-1a) dessa lista — ver
//   `src/shared/pwa/cacheNome.js`. Qualquer arquivo diferente → outro cache.
//
// Estratégias
//   - install  : precache dos arquivos DESTE build. SEM skipWaiting automático:
//                o SW novo espera até o app mandar {type:'SKIP_WAITING'}
//                (aviso "Nova versão disponível — Atualizar").
//   - activate : apaga os caches `edumaps-*` de outros builds + clients.claim.
//   - navigate : network-first; offline → o index.html precacheado DESTE build
//                (nunca o shell de outro build, que aponta para hashes que já
//                não existem no servidor → tela em branco).
//   - /api/, /analytic-api/ : só rede (nunca cache).
//   - /sw.js, /registerSW.js, /manifest.webmanifest : só rede, senão o SW
//                antigo se perpetua.
//   - /assets/*-<hash>.* : cache-first (imutáveis); 404 nunca é cacheado.
//   - demais estáticos same-origin (sem hash): stale-while-revalidate.
//
// Não usamos o runtime do Workbox: só o `url`/`revision` do manifest injetado.

import {
  nomeDoCache,
  cachesObsoletos,
  ehAssetComHash,
} from "./shared/pwa/cacheNome.js";

// Injetado pelo build (Workbox precache manifest): [{ url, revision }, ...].
const INJECTED_MANIFEST = self.__WB_MANIFEST || [];

const CACHE_VERSION = nomeDoCache(INJECTED_MANIFEST);
const SHELL = "/index.html";
const EXTRAS = ["/favicon.svg"];

// Normaliza para caminho absoluto ("favicon.svg" -> "/favicon.svg") para
// deduplicar: Cache.addAll falha com "duplicate requests".
const toAbsolute = (u) => {
  try {
    return new URL(u, self.location.origin).pathname;
  } catch {
    return u;
  }
};

const PRECACHE = [
  ...new Set(
    [
      SHELL,
      ...EXTRAS,
      ...INJECTED_MANIFEST.map((entry) =>
        typeof entry === "string" ? entry : entry.url
      ),
    ].map(toAbsolute)
  ),
];

const SOMENTE_REDE = new Set(["/sw.js", "/registerSW.js", "/manifest.webmanifest"]);

self.addEventListener("install", (event) => {
  // `cache: "reload"` evita que o cache HTTP devolva o shell anterior.
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) =>
        cache.addAll(PRECACHE.map((u) => new Request(u, { cache: "reload" })))
      )
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          cachesObsoletos(keys, CACHE_VERSION).map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  );
});

function guardar(request, response) {
  if (response && response.ok && response.type === "basic") {
    const copy = response.clone();
    caches.open(CACHE_VERSION).then((cache) => cache.put(request, copy));
  }
  return response;
}

self.addEventListener("fetch", (event) => {
  const { request } = event;

  // Só GET é cacheável/servível.
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Navegação (SPA): rede primeiro; offline → shell DESTE build.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).catch(() =>
        caches
          .open(CACHE_VERSION)
          .then((cache) => cache.match(SHELL))
          .then((r) => r || Response.error())
      )
    );
    return;
  }

  // API: sempre rede (sem cache).
  if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/analytic-api/")) {
    return;
  }

  // Arquivos de controle do PWA: sempre rede.
  if (SOMENTE_REDE.has(url.pathname)) return;

  // Assets com hash: imutáveis → cache-first (no cache deste build).
  if (ehAssetComHash(url.pathname)) {
    event.respondWith(
      caches
        .open(CACHE_VERSION)
        .then((cache) => cache.match(request))
        .then((cached) => cached || fetch(request).then((r) => guardar(request, r)))
    );
    return;
  }

  // Demais estáticos same-origin: stale-while-revalidate.
  event.respondWith(
    caches
      .open(CACHE_VERSION)
      .then((cache) => cache.match(request))
      .then((cached) => {
        const fetched = fetch(request)
          .then((r) => guardar(request, r))
          .catch(() => cached || Response.error());
        return cached || fetched;
      })
  );
});
