// src/features/gestor/utils/relatorioCapitulos.js
//
// Agrupamento do ReportResult em capítulos (#219, fase 4 — modo composto).
// Uma regra só para a tela, a impressão e o Markdown:
//   - sem `capitulos` (lista não vazia) → null: o relatório é renderizado
//     exatamente como nas Fases 1–3;
//   - seções com `capitulo` conhecido vão para o capítulo, na ordem em que vêm;
//   - seções gerais (sem `capitulo`, ou com um capítulo que não está na
//     lista) ficam antes ou depois dos capítulos: `resumo` sempre antes,
//     `leitura` sempre depois, as demais pela posição relativa à primeira
//     seção de capítulo.

/**
 * @param {object} relatorio
 * @returns {null | {
 *   antes: Array<object>,
 *   capitulos: Array<{id: string, titulo: string, tema?: string, secoes: Array<object>}>,
 *   depois: Array<object>,
 * }}
 */
export function agruparPorCapitulo(relatorio) {
  const lista = Array.isArray(relatorio?.capitulos)
    ? relatorio.capitulos.filter((c) => c && typeof c === "object" && c.id !== undefined && c.id !== null)
    : [];
  if (!lista.length) return null;

  const capitulos = lista.map((c) => ({
    id: String(c.id),
    titulo: c.titulo ?? String(c.id),
    tema: c.tema,
    secoes: [],
  }));
  const porId = new Map(capitulos.map((c) => [c.id, c]));
  const secoes = (relatorio?.secoes ?? []).filter((s) => s && typeof s === "object");
  const capituloDe = (s) => (s.capitulo === undefined || s.capitulo === null ? null : porId.get(String(s.capitulo)));
  const primeira = secoes.findIndex((s) => capituloDe(s));

  const antes = [];
  const depois = [];
  secoes.forEach((s, i) => {
    const cap = capituloDe(s);
    if (cap) cap.secoes.push(s);
    else if (s.id === "resumo") antes.push(s);
    else if (s.id === "leitura") depois.push(s);
    else if (primeira < 0 || i < primeira) antes.push(s);
    else depois.push(s);
  });
  return { antes, capitulos, depois };
}

/** Âncora do capítulo no documento (sumário → h2). */
export function ancoraCapitulo(id) {
  return `capitulo-${String(id).replace(/[^A-Za-z0-9_-]+/g, "-")}`;
}
