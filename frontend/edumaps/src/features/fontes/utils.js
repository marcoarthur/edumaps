// src/features/fontes/utils.js

/** "2026-10-14" → "14/10/2026" */
export function dataBR(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso ?? "");
  return m ? `${m[3]}/${m[2]}/${m[1]}` : "";
}

/**
 * Bases de uma tela, na ordem do catálogo.
 * @param {Array} fontes - resposta de /api/fontes
 * @param {string} tela - ex.: "comparacao_redes"
 */
export function fontesDaTela(fontes, tela) {
  return (fontes ?? []).filter((f) => (f.telas ?? []).includes(tela));
}

/** "Censo Escolar 2025" / "IDEB e SAEB 2005–2023" */
export function rotuloFonte(f) {
  return [f.nome, f.periodo?.texto].filter(Boolean).join(" ");
}
