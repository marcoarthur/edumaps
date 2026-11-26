// src/shared/ui/ordenar.js
// A comparação de colunas do DataTable, separada para quem pagina: com
// `onsort`, a página ordena a lista inteira (filtrada) antes de cortar a
// página, e não só as linhas que a tabela mostra (#602, QC-02 da P2).

/**
 * @template T
 * @param {T[]} data
 * @param {string|null} field
 * @param {'asc'|'desc'|null} dir
 * @returns {T[]}
 */
export function ordenar(data, field, dir) {
  if (!field || !dir) return data;
  const sample = data.find((l) => l?.[field] != null)?.[field];
  const isNumeric = typeof sample === "number" || sample === undefined;
  return [...data].sort((a, b) => {
    const valA = a[field] ?? "";
    const valB = b[field] ?? "";
    const r = isNumeric ? (Number(valA) || 0) - (Number(valB) || 0) : String(valA).localeCompare(String(valB));
    return dir === "asc" ? r : -r;
  });
}
