// src/shared/utils/uuid.js
//
// Geração de UUID v4 sem depender de *contexto seguro*.
//
// `crypto.randomUUID()` só existe em contextos seguros (HTTPS ou localhost).
// Em dev acessado por host/IP (ex.: http://ubatexu.lan:5173) o `crypto` global
// existe, mas `randomUUID` é `undefined` — daí o erro
// "crypto.randomUUID is not a function". A Web Crypto API que funciona em
// qualquer contexto é `crypto.getRandomValues()`, que usamos para montar um
// UUID v4 nativo, sem dependência externa.

/**
 * Gera um UUID v4.
 *
 * Ordem de preferência (tudo nativo):
 *  1. `crypto.randomUUID()` — quando disponível (contexto seguro/Node);
 *  2. `crypto.getRandomValues()` — funciona também em contexto inseguro;
 *  3. fallback com `Date.now()`/`Math.random()` — só para ambientes sem Web
 *     Crypto (suficiente para IDs de UI, não para uso criptográfico).
 *
 * @returns {string} UUID v4 no formato canônico.
 */
export function uuid() {
  const c = globalThis.crypto;
  if (typeof c?.randomUUID === "function") return c.randomUUID();
  if (typeof c?.getRandomValues === "function") return uuidV4(c);
  return fallbackId();
}

function uuidV4(cryptoObj) {
  const bytes = cryptoObj.getRandomValues(new Uint8Array(16));

  // Marca a versão (4) e a variante (10xx), conforme RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

  return (
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`
  );
}

function fallbackId() {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (ch) => {
    const r = (Date.now() + Math.random() * 16) % 16 | 0;
    const v = ch === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
