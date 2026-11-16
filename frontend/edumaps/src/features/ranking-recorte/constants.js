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
  // #457 (VK-01): itens básicos (água, energia, esgoto, banheiro), de 0 a 4;
  // só na lista de escolas de um município.
  { id: "infraestrutura_basica", label: "Infraestrutura básica (água, energia, esgoto, banheiro)" },
  { id: "infraestrutura", label: "Infraestrutura (índice)" },
  { id: "capacidade_atendimento", label: "Capacidade de Atendimento" },
  { id: "capacitacao_docente", label: "Capacitação Docente" },
  { id: "diversidade_discente", label: "Diversidade Discente" },
  { id: "capacidade_gestora", label: "Capacidade Gestora" },
  { id: "sustentabilidade", label: "Sustentabilidade" },
];

export const INDICADORES_ESCOLA = [...INDICADORES_IDEB, ...INDICADORES_CENSO];

// Mínimo de escolas por rede oferecido na tela (#437); o backend aceita 3..30.
export const MINIMOS = [3, 5, 10, 20];

/**
 * Porte do município (#439): classes de tamanho da população do IBGE, as
 * mesmas de `@PORTES` em EduMaps::Model::Rank::School.
 */
export const PORTES = [
  { id: "ate_5mil", label: "Até 5 mil hab." },
  { id: "5_10mil", label: "5 a 10 mil hab." },
  { id: "10_20mil", label: "10 a 20 mil hab." },
  { id: "20_50mil", label: "20 a 50 mil hab." },
  { id: "50_100mil", label: "50 a 100 mil hab." },
  { id: "100_500mil", label: "100 a 500 mil hab." },
  { id: "mais_500mil", label: "Mais de 500 mil hab." },
];

/** Rótulo curto do porte; "–" quando sem população. */
export function rotuloPorte(id) {
  return PORTES.find((p) => p.id === id)?.label ?? "–";
}

/**
 * Regiões do IBGE (#445): as mesmas de `@REGIOES` em EduMaps::Regiao. O
 * ranking de redes aceita a região como recorte, entre a UF e o Brasil.
 */
export const REGIOES = [
  { id: "N", label: "Norte" },
  { id: "NE", label: "Nordeste" },
  { id: "SE", label: "Sudeste" },
  { id: "S", label: "Sul" },
  { id: "CO", label: "Centro-Oeste" },
];

/** Nome da região pelo id; "" quando desconhecida. */
export function rotuloRegiao(id) {
  return REGIOES.find((r) => r.id === id)?.label ?? "";
}

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
