// src/features/ranking-recorte/constants.js
// Espelha o indicator_registry de EduMaps::Model::Rank::School.

export const INDICADORES_IDEB = [
  { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais" },
  { id: "ideb_anos_finais", label: "IDEB – Anos Finais" },
  { id: "ideb_ensino_medio", label: "IDEB – Ensino Médio" },
  { id: "nota_matematica_fund_ii", label: "Nota Matemática – Anos Finais" },
  { id: "nota_portugues_fund_ii", label: "Nota Português – Anos Finais" },
  { id: "nota_matematica_medio", label: "Nota Matemática – Ensino Médio" },
  { id: "nota_portugues_medio", label: "Nota Português – Ensino Médio" },
  { id: "taxa_aprovacao_fund_i", label: "Taxa de Aprovação – Anos Iniciais" },
  { id: "taxa_aprovacao_fund_ii", label: "Taxa de Aprovação – Anos Finais" },
  { id: "taxa_aprovacao_medio", label: "Taxa de Aprovação – Ensino Médio" },
];

export const INDICADORES_CENSO = [
  { id: "infraestrutura", label: "Infraestrutura" },
  { id: "capacidade_atendimento", label: "Capacidade de Atendimento" },
  { id: "capacitacao_docente", label: "Capacitação Docente" },
  { id: "diversidade_discente", label: "Diversidade Discente" },
  { id: "capacidade_gestora", label: "Capacidade Gestora" },
  { id: "sustentabilidade", label: "Sustentabilidade" },
];

export const INDICADORES_ESCOLA = [...INDICADORES_IDEB, ...INDICADORES_CENSO];

export const UFS = [
  "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT", "PA",
  "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO",
];

export const REDES = [
  { id: "", label: "Todas as redes" },
  { id: "municipal", label: "Municipal" },
  { id: "estadual", label: "Estadual" },
  { id: "privada", label: "Privada" },
];

// Código IBGE da UF (2 primeiros dígitos do município) → sigla.
export const UF_POR_CODIGO = {
  11: "RO", 12: "AC", 13: "AM", 14: "RR", 15: "PA", 16: "AP", 17: "TO",
  21: "MA", 22: "PI", 23: "CE", 24: "RN", 25: "PB", 26: "PE", 27: "AL", 28: "SE", 29: "BA",
  31: "MG", 32: "ES", 33: "RJ", 35: "SP", 41: "PR", 42: "SC", 43: "RS",
  50: "MS", 51: "MT", 52: "GO", 53: "DF",
};

/** Sigla da UF a partir do código IBGE do município (7 dígitos). */
export function ufDoMunicipio(codigoIbge) {
  return UF_POR_CODIGO[Number(String(codigoIbge ?? "").slice(0, 2))] ?? null;
}
