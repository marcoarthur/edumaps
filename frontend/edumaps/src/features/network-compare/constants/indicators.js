// src/features/network-compare/constants/indicators.js
//
// Catálogo de redes, etapas de ensino e eixos usados nas visualizações
// da página de comparação de redes por município.
// Reflete as colunas de analytics.mv_rede_escolas (summary) e os rótulos
// devolvidos por SchoolNetwork::Analytic (performance).

export const NETWORK_ORDER = ["federal", "estadual", "municipal", "privada"];

export const NETWORK_LABELS = {
  federal: "Federal",
  estadual: "Estadual",
  municipal: "Municipal",
  privada: "Privada",
};

export const NETWORK_COLORS = {
  federal: "#0ea5e9", // sky-500
  estadual: "#f59e0b", // amber-500
  municipal: "#10b981", // emerald-500
  privada: "#8b5cf6", // violet-500
};

// Eixos do radar de matrículas por etapa (summary -> colunas da MV).
export const STAGE_AXES = [
  { key: "matriculas_infantil", label: "Infantil" },
  { key: "matriculas_fundamental_ai", label: "Fundamental I" },
  { key: "matriculas_fundamental_af", label: "Fundamental II" },
  { key: "matriculas_medio", label: "Médio" },
  { key: "matriculas_eja", label: "EJA" },
  { key: "matriculas_profissional", label: "Profissionalizante" },
];

// Etapas do IDEB (performance -> etapa).
export const IDEB_ETAPAS = [
  { key: "fundamental_i", label: "Fundamental I" },
  { key: "fundamental_ii", label: "Fundamental II" },
  { key: "ensino_medio", label: "Ensino Médio" },
];

export const IDEB_ETAPA_LABELS = Object.fromEntries(
  IDEB_ETAPAS.map((e) => [e.key, e.label]),
);

// Modos de normalização do radar por etapa.
export const RADAR_MODES = [
  {
    key: "share",
    label: "Perfil",
    description: "Participação de cada etapa dentro da própria rede (%)",
  },
  {
    key: "volume",
    label: "Volume",
    description: "Matrículas normalizadas pelo maior valor da etapa",
  },
];