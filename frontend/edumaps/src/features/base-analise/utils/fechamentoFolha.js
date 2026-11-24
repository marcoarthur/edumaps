// src/features/base-analise/utils/fechamentoFolha.js
//
// #554 (QS-02 da P5): a soma das escolas da base não dá o total que o
// município declara ao SIOPE. A diferença é a folha da Secretaria (sem
// escola) e a de escolas que o SIOPE declara e a lista do Censo não tem.
// Aqui, a frase que fecha a conta de um município num ano.

/** R$ 67,7 mi / R$ 267,8 mil / R$ 950 */
export function reaisCurto(v) {
  const n = Number(v) || 0;
  const f = (x) => x.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  if (Math.abs(n) >= 1e6) return `R$ ${f(n / 1e6)} mi`;
  if (Math.abs(n) >= 1e3) return `R$ ${f(n / 1e3)} mil`;
  return `R$ ${Math.round(n).toLocaleString("pt-BR")}`;
}

/**
 * @param {{ municipio: string, anos: Array<{ ano, fechamento? }> }} m
 * @param {number} ano - ano da folha escolhido
 * @param {number} anoCenso - o Censo da lista de escolas da base
 * @returns {string|null}
 */
export function fraseFechamento(m, ano, anoCenso) {
  const f = m?.anos?.find((a) => a.ano === ano)?.fechamento;
  if (!f || !(f.total > 0)) return null;
  const partes = [];
  if (f.escolas_base > 0) partes.push(`nas escolas desta base, ${reaisCurto(f.escolas_base)}`);
  if (f.secretaria > 0) partes.push(`da Secretaria, sem escola, ${reaisCurto(f.secretaria)}`);
  if (f.fora_total > 0) {
    const n = f.fora.length;
    const quais = f.fora.slice(0, 3).map((e) => (e.escola ? `${e.inep}, ${e.escola}` : e.inep)).join("; ");
    const mais = n > 3 ? `; e mais ${n - 3}` : "";
    partes.push(`em ${n} ${n === 1 ? "escola" : "escolas"} fora da lista do Censo ${anoCenso} (${quais}${mais}), ${reaisCurto(f.fora_total)}`);
  }
  const resto = partes.join("; ");
  return `${m.municipio}: ${reaisCurto(f.total)} declarados em ${ano}. ${resto.charAt(0).toUpperCase()}${resto.slice(1)}.`;
}
