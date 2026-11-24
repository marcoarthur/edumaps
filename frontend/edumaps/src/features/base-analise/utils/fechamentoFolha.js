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
  return `${m.municipio}: ${reaisCurto(f.total)} declarados em ${ano}. ${resto.charAt(0).toUpperCase()}${resto.slice(1)}.${frasePorFonte(f)}`;
}

const pct = (v, t) => `${((100 * v) / t).toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;

/**
 * #579 (QG-01 da P6): a folha inteira do município (com a Secretaria) por
 * fonte. " Pela fonte: 94,5% pela parcela de 70% do Fundeb, 0,3% pela de 30%
 * e 5,2% de outras fontes." Sem fonte nenhuma informada: "".
 */
export function frasePorFonte(f) {
  const p = f?.por_fonte;
  if (!p || !(f.total > 0)) return "";
  const soma = (p.fundeb_70 || 0) + (p.fundeb_30 || 0) + (p.outras || 0);
  if (!(soma > 0)) return "";
  const sem = f.total - soma;
  const semTxt = sem / f.total >= 0.005 ? `; ${pct(sem, f.total)} sem a fonte informada` : "";
  return ` Pela fonte: ${pct(p.fundeb_70 || 0, f.total)} pela parcela de 70% do Fundeb, ${pct(p.fundeb_30 || 0, f.total)} pela de 30% e ${pct(p.outras || 0, f.total)} de outras fontes${semTxt}.`;
}
