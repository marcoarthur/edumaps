// src/features/schools/utils/leituraPosicao.js
//
// #541 (P1-PN-01 da P1): a leitura da posição da escola, igual no painel e
// na página da posição. Sem cor de "bom" ou "ruim" (decisão A1: a posição e
// o "de N" já dizem onde a escola está). Empate nas pontas vira primeiro ou
// último lugar dividido (decisão B1): "1ª de 81" com "acima de 16%" parecia
// contradição, e "acima de 0%" no último lugar dividido não dizia nada.

const escolas = (n) => `${n.toLocaleString("pt-BR")} ${n === 1 ? "escola" : "escolas"}`;

/**
 * @param {{ posicao: number, total: number, empate?: number, abaixo?: number, percentil: number }} e
 * @param {string} [onde] - complemento de "das outras escolas" (ex.: "no município")
 * @returns {{ empate: string|null, frase: string }}
 */
export function leituraPosicao(e, onde = "") {
  const empate = Number(e?.empate ?? 1);
  const outras = empate - 1;
  const sufixo = onde ? ` ${onde}` : "";
  if (empate > 1 && empate >= Number(e.total)) {
    return { empate: null, frase: `Todas as ${escolas(empate)} têm o mesmo valor` };
  }
  if (empate > 1 && Number(e.posicao) === 1) {
    return { empate: null, frase: `1º lugar, dividido com ${escolas(outras)} com o mesmo valor` };
  }
  if (empate > 1 && Number(e.abaixo) === 0) {
    return { empate: null, frase: `Último lugar, dividido com ${escolas(outras)} com o mesmo valor` };
  }
  return {
    empate: empate > 1 ? `empatada com ${escolas(outras)}` : null,
    frase: `Acima de ${e.percentil}% das outras escolas${sufixo}`,
  };
}
