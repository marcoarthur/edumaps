// src/features/gestor/utils/relatorioGrafico.js
//
// Converte a seção "grafico" do ReportResult (#219) para o formato dos
// wrappers Carbon ({group, key, value}) e gera a descrição textual.

/**
 * @param {{x?: {id: string}, series?: Array<{id: string, rotulo?: string}>, dados?: Array<object>}} secao
 * @returns {Array<{group: string, key: string, value: number}>}
 */
export function dadosGrafico(secao) {
  const xId = secao?.x?.id;
  const out = [];
  for (const serie of secao?.series ?? []) {
    for (const d of secao?.dados ?? []) {
      const v = d?.[serie.id];
      if (v === null || v === undefined || v === "" || !Number.isFinite(Number(v))) continue;
      out.push({ group: serie.rotulo ?? serie.id, key: String(d?.[xId] ?? ""), value: Number(v) });
    }
  }
  return out;
}

/**
 * Descrição em texto do gráfico, para leitores de tela.
 * @param {object} secao
 * @param {(v: unknown, f?: string) => string} formatar
 */
export function descricaoGrafico(secao, formatar) {
  const tipo = secao?.grafico === "linhas" ? "Gráfico de linhas" : "Gráfico de barras";
  const xId = secao?.x?.id;
  const xRotulo = secao?.x?.rotulo ?? xId ?? "";
  const partes = (secao?.series ?? []).map((serie) => {
    const valores = (secao?.dados ?? [])
      .map((d) => `${d?.[xId]}: ${formatar(d?.[serie.id], serie.formato)}`)
      .join("; ");
    return `${serie.rotulo ?? serie.id} — ${valores}`;
  });
  const titulo = secao?.titulo ? ` "${secao.titulo}"` : "";
  return `${tipo}${titulo} por ${xRotulo}. ${partes.join(". ")}.`;
}
