// src/shared/pwa/cacheNome.js
//
// Nome do cache do service worker derivado do BUILD (issue #225).
//
// Importado pelo `src/sw.js` (empacotado junto pelo vite-plugin-pwa) e pelos
// testes — por isso é JS puro, sem DOM nem API de service worker.
//
// O build injeta em `self.__WB_MANIFEST` a lista `[{ url, revision }]` de
// todos os arquivos do bundle. Arquivos com hash no nome mudam a `url`; os
// demais (index.html, favicon…) mudam a `revision`. Um hash da lista inteira,
// portanto, muda sempre que qualquer arquivo do build muda — e só então.

export const PREFIXO_CACHE = "edumaps-";

// FNV-1a 32 bits: curto, determinístico e sem dependência (o SW não tem
// `crypto.subtle` síncrono). Não é criptográfico — só precisa distinguir builds.
export function fnv1a(texto) {
  let h = 0x811c9dc5;
  for (let i = 0; i < texto.length; i++) {
    h ^= texto.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, "0");
}

// Hash estável do manifesto: independe da ordem das entradas.
export function hashDoManifesto(manifesto = []) {
  const linhas = (manifesto || [])
    .map((e) =>
      typeof e === "string" ? `${e}|` : `${e?.url ?? ""}|${e?.revision ?? ""}`
    )
    .sort();
  return fnv1a(linhas.join("\n"));
}

export function nomeDoCache(manifesto) {
  return `${PREFIXO_CACHE}${hashDoManifesto(manifesto)}`;
}

// Caches a apagar no `activate`: os nossos (prefixo) que não são deste build.
// Caches de terceiros (sem o prefixo) ficam intocados.
export function cachesObsoletos(chaves, atual) {
  return chaves.filter((k) => k.startsWith(PREFIXO_CACHE) && k !== atual);
}

// Asset com hash do Vite (`/assets/nome-<hash>.ext`): imutável → cache-first.
export function ehAssetComHash(pathname) {
  return /^\/assets\/.+-[A-Za-z0-9_-]{8,}\.[a-z0-9]+$/.test(pathname);
}
