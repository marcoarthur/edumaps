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

/** " (setembro e outubro incompletos)" ou "" (#576: com carga registrada, "… já na planilha do SIOPE") */
export function sufixoIncompletos(meses, carga = null) {
  const n = meses?.length ?? 0;
  if (!n) return "";
  return ` (${listaMeses(meses)} ${n === 1 ? "incompleto" : "incompletos"}${carga ? " já na planilha do SIOPE" : ""})`;
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
 * Sempre com a carga no fim (#564): "; carga em 24/11/2026" ou "; carga não registrada".
 */
export function textoAnoFolha(a) {
  // #564 (QQ-02 da P6): a data da carga do município e ano, quando registrada
  const carga = `; ${a.carga ? `carga em ${dataBR(a.carga)}` : "carga não registrada"}`;
  return textoAnoFolhaSemCarga(a) + carga;
}

function textoAnoFolhaSemCarga(a) {
  const inc = sufixoIncompletos(a.incompletos, a.carga).slice(2, -1);
  if (!a.escolas) return `só o total da Secretaria${inc ? `; ${inc}` : ""}`;
  const escolas = `${a.escolas} ${a.escolas === 1 ? "escola" : "escolas"}`;
  if (a.meses_secretaria?.length) {
    return `por escola só em ${faixasMeses(a.meses_escola)}; ${faixasMeses(a.meses_secretaria)}, só o total da Secretaria${inc ? `; ${inc}` : ""}; ${escolas}`;
  }
  return `${a.meses} ${a.meses === 1 ? "mês" : "meses"}${sufixoIncompletos(a.incompletos, a.carga)}, ${escolas}`;
}

const brl = (v) => `R$ ${Math.round(Number(v) || 0).toLocaleString("pt-BR")}`;

/**
 * #571 (QI-01 da P3): o salário do magistério da rede inteira (escolas e o
 * total da Secretaria), por mês, sem dezembro e sem conversão para 40 horas.
 * "salário total R$ 6.975 e base R$ 2.669 (medianas por mês, sem dezembro, de 2.961 profissionais do magistério); carga mais comum: 18"
 */
export function textoSalarioRede(s) {
  if (!s || !s.pessoas) return "";
  const pessoas = `${Number(s.pessoas).toLocaleString("pt-BR")} ${s.pessoas === 1 ? "profissional" : "profissionais"} do magistério`;
  const carga = s.carga_comum != null ? `; carga mais comum: ${Number(s.carga_comum).toLocaleString("pt-BR")}` : "";
  // #572 (QI-02 da P3): carga que não parece em horas semanais
  const aviso = s.carga_suspeita
    ? " (não parece ser em horas semanais, e sim em aulas ou numa jornada parcial: as contas por 40 horas não valem aqui)"
    : "";
  return `salário total ${brl(s.total)} e base ${brl(s.base)} (medianas por mês, sem dezembro, de ${pessoas})${carga}${aviso}`;
}

/**
 * #575 (QH-01 da P5): quem fica abaixo do piso na rede inteira (escolas e o
 * total da Secretaria), no mês típico, entre quem recebeu 3 meses ou mais.
 * Sem contagem (sem piso, ou carga fora de horas): "".
 */
export function textoPisoRede(s, ano) {
  if (!s || s.abaixo_piso == null || s.piso == null) return "";
  const n = Number(s.abaixo_piso);
  const sec = Number(s.abaixo_piso_so_secretaria) || 0;
  const pessoas = `${n.toLocaleString("pt-BR")} ${n === 1 ? "profissional" : "profissionais"} do magistério`;
  const daSec = sec ? `, ${sec.toLocaleString("pt-BR")} ${sec === 1 ? "dele" : "deles"} só no total da Secretaria` : "";
  return `Abaixo do piso${ano ? ` de ${ano}` : ""} (${brl2(s.piso)} por 40 horas) no mês típico, entre quem recebeu 3 meses ou mais: ${pessoas}${daSec}. `
    + "Não é a verificação legal do piso (complementos, jornada, licenças, reajuste pago com atraso), e o total da Secretaria pode ter pagamentos parciais.";
}

const brl2 = (v) => `R$ ${Number(v).toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

/**
 * #589 (P1-FL-03): o salário da escola, na mesma conta da rede, e quanto
 * difere da rede no total. "salário total R$ 9.353 e base R$ 6.100 (medianas
 * por mês, sem dezembro, de 36 profissionais do magistério); 30% acima da
 * rede no salário total"
 */
export function textoSalarioEscola(e, rede) {
  if (!e || !e.pessoas) return "";
  const base = textoSalarioRede({ ...e, carga_suspeita: false });
  if (!rede?.total || !e.total) return base;
  const dif = Math.round((100 * (e.total - rede.total)) / rede.total);
  const comp = dif === 0 ? "igual à rede no salário total" : `${Math.abs(dif)}% ${dif > 0 ? "acima" : "abaixo"} da rede no salário total`;
  return `${base}; ${comp}`;
}
