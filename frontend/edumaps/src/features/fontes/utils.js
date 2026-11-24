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

/**
 * #557 (QT-01 da P2): os meses em que a folha do município veio pela metade.
 * [{nome:"setembro"},{nome:"outubro"}] → "setembro e outubro"
 */
export function listaMeses(meses) {
  const n = (meses ?? []).map((m) => m.nome);
  if (n.length <= 1) return n[0] ?? "";
  return `${n.slice(0, -1).join(", ")} e ${n.at(-1)}`;
}

/** " (setembro e outubro incompletos)" ou "" */
export function sufixoIncompletos(meses) {
  const n = meses?.length ?? 0;
  if (!n) return "";
  return ` (${listaMeses(meses)} ${n === 1 ? "incompleto" : "incompletos"})`;
}

const NOMES_MESES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"];

/**
 * #558: meses (1 a 12) em texto, com as sequências de 3 ou mais como
 * intervalo. [3,4,5,6,7,8] → "de março a agosto"; [1,2] → "janeiro e
 * fevereiro"; [1,2,5,6,7] → "janeiro, fevereiro e de maio a julho".
 */
export function faixasMeses(meses) {
  const ms = [...new Set((meses ?? []).map(Number))].sort((a, b) => a - b);
  const partes = [];
  for (let i = 0; i < ms.length; ) {
    let j = i;
    while (j + 1 < ms.length && ms[j + 1] === ms[j] + 1) j++;
    if (j - i >= 2) partes.push(`de ${NOMES_MESES[ms[i] - 1]} a ${NOMES_MESES[ms[j] - 1]}`);
    else for (let k = i; k <= j; k++) partes.push(NOMES_MESES[ms[k] - 1]);
    i = j + 1;
  }
  return listaMeses(partes.map((nome) => ({ nome })));
}

/**
 * #512/#557/#558: o texto de um ano da cobertura da folha.
 * "8 meses, 48 escolas"; "12 meses (setembro e outubro incompletos), 167 escolas";
 * "por escola só em janeiro e fevereiro; de março a agosto, só o total da Secretaria; 168 escolas";
 * "só o total da Secretaria; julho incompleto".
 */
export function textoAnoFolha(a) {
  const inc = sufixoIncompletos(a.incompletos).slice(2, -1);
  if (!a.escolas) return `só o total da Secretaria${inc ? `; ${inc}` : ""}`;
  const escolas = `${a.escolas} ${a.escolas === 1 ? "escola" : "escolas"}`;
  if (a.meses_secretaria?.length) {
    return `por escola só em ${faixasMeses(a.meses_escola)}; ${faixasMeses(a.meses_secretaria)}, só o total da Secretaria${inc ? `; ${inc}` : ""}; ${escolas}`;
  }
  return `${a.meses} ${a.meses === 1 ? "mês" : "meses"}${sufixoIncompletos(a.incompletos)}, ${escolas}`;
}
