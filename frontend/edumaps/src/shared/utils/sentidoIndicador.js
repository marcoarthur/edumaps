// src/shared/utils/sentidoIndicador.js
//
// Sentido dos indicadores do perfil (escola e rede): em quais "menor é
// melhor" (#421, AN-02). Espelha `PROFILE_DIRECAO` do pacote R; o perfil
// da escola já traz `direcao` no payload, o da rede não.

export const MENOR_E_MELHOR = new Set(["prop_sem_especializacao", "ratio_aluno_docente"]);

/** @returns {"maior"|"menor"} */
export function sentidoIndicador(indicador, direcao) {
  if (direcao === "maior" || direcao === "menor") return direcao;
  return MENOR_E_MELHOR.has(String(indicador)) ? "menor" : "maior";
}

/**
 * A diferença (ex.: rede − Brasil) é favorável?
 * @returns {true|false|null} null quando zero ou ausente
 */
export function diferencaFavoravel(indicador, diferenca, direcao) {
  const n = Number(diferenca);
  if (diferenca === null || diferenca === undefined || diferenca === "" || Number.isNaN(n) || n === 0) {
    return null;
  }
  return sentidoIndicador(indicador, direcao) === "menor" ? n < 0 : n > 0;
}
