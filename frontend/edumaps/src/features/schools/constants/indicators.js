// src/features/schools/constants/indicators.js
//
// A lista real vem da API (dinâmica, por escola — critério de aceitação 1),
// mas mantemos os labels aqui como fallback de exibição caso a API só
// devolva o `id`.
export const INDICATOR_LABELS = {
  ideb_anos_iniciais: "IDEB – Anos Iniciais",
  ideb_anos_finais: "IDEB – Anos Finais",
  ideb_ensino_medio: "IDEB – Ensino Médio",
  nota_matematica: "Nota Média – Matemática",
  nota_portugues: "Nota Média – Português",
  infraestrutura: "Infraestrutura",
  taxa_aprovacao: "Taxa de Aprovação",
};
