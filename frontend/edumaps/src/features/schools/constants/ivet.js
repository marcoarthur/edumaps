// src/features/schools/constants/ivet.js
//
// Constantes de exibição do IVET (Índice de Vulnerabilidade de acesso) e da
// isócrona — issue #296.
//
// Os rótulos em português descrevem o que cada bloco mede; o valor real vem
// da API (analytics.ivet_escola). Os nomes de campo (bloco_a..g) são o
// contrato JSON exato — não renomear.

/**
 * Blocos do IVET, na ordem do contrato da API. `chave` casa com
 * `blocos` do GET /api/school/:cod_inep/ivet.
 */
export const IVET_BLOCOS = [
  { chave: "A", sigla: "A", rotulo: "Porte / oferta" },
  { chave: "B", sigla: "B", rotulo: "Contexto socioeconômico" },
  { chave: "C", sigla: "C", rotulo: "Acesso (isócrona)" },
  { chave: "D", sigla: "D", rotulo: "Segurança" },
  { chave: "E", sigla: "E", rotulo: "Recursos" },
  { chave: "F", sigla: "F", rotulo: "Saúde" },
  { chave: "G", sigla: "G", rotulo: "Mobilidade" },
];

/**
 * Faixas da isócrona: 15 min a pé (H3 r9) e 45 min de carro (H3 r7),
 * conforme a extração #278/#295. `cor` é usada no polígono do Leaflet e
 * na legenda clicável.
 */
export const ISOCRONA_FAIXAS = [
  { tempo_minutos: 15, rotulo: "15 min a pé", resolucao_h3: 9, cor: "#2563eb" },
  { tempo_minutos: 45, rotulo: "45 min de carro", resolucao_h3: 7, cor: "#7c3aed" },
];

/** Cor da faixa pelo tempo (fallback: cinza). */
export function isocronaCor(tempoMinutos) {
  return ISOCRONA_FAIXAS.find((f) => f.tempo_minutos === tempoMinutos)?.cor ?? "#6b7280";
}

/** Rótulo da faixa pelo tempo (fallback: "<N> min"). */
export function isocronaRotulo(tempoMinutos) {
  return (
    ISOCRONA_FAIXAS.find((f) => f.tempo_minutos === tempoMinutos)?.rotulo ??
    `${tempoMinutos} min`
  );
}
