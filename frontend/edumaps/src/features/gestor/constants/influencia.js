// src/features/gestor/constants/influencia.js
//
// Parâmetros da camada de influência (metodologia `influencia-v1`,
// docs/analises/influencia.md §4) — espelham os raios materializados em
// clean.escola_influencia. A legenda precisa nomear cada raio com o grupo de
// indicadores a que serve, por isso a tabela de propósito vive aqui.
export const INFLUENCIA_RADII = [500, 1000, 2000];

// Cor estável por raio (menor → maior: azul escuro → violeta).
export const INFLUENCIA_COLORS = {
  500: "#1d4ed8",
  1000: "#0891b2",
  2000: "#7c3aed",
};

/** Rótulo curto do raio: 500 → "500 m", 1000 → "1 km", 2000 → "2 km". */
export function radiusLabel(m) {
  if (m === null || m === undefined || m === "") return "—";
  const n = Number(m);
  if (!Number.isFinite(n)) return "—";
  return n >= 1000 ? `${n / 1000} km` : `${n} m`;
}

/** Cor do raio (fallback cinza para raios fora da metodologia). */
export function radiusColor(m) {
  return INFLUENCIA_COLORS[Number(m)] ?? "#64748b";
}

/**
 * Conteúdo da cartela de um anel, desenhada sobre a própria geometria no mapa.
 *
 * Identifica o entorno — raio, leitura do entorno (Censo 2022) e área em km².
 * Pura e testável; o `InfluenciaMap` a converte em HTML do `divIcon`.
 */
export function ringCartela(props = {}) {
  return {
    label: radiusLabel(props.raio_m),
    entorno: entornoLabel(props.entorno),
    area: formatAreaKm2(props.area_km2),
    color: radiusColor(props.raio_m),
  };
}

// Grupo de indicadores que usa cada raio (defaults do §4 da metodologia).
export const INFLUENCIA_PURPOSE = {
  500: "Equipamentos e vias (feições locais)",
  1000: "Uso do solo e densidade (MapBiomas)",
  2000: "Queimada e chuva (INMET, MapBiomas fogo)",
};

/** Para que serve o raio (default genérico se não for um raio conhecido). */
export function radiusPurpose(m) {
  return INFLUENCIA_PURPOSE[Number(m)] ?? "Área de influência";
}

/** Formata um inteiro pt-BR; ausente vira "—" (ausência ≠ 0, #154). */
export function formatCount(value) {
  const n = Number(value);
  if (value === null || value === undefined || value === "" || !Number.isFinite(n)) {
    return "—";
  }
  return n.toLocaleString("pt-BR", { maximumFractionDigits: 0 });
}

/**
 * Densidade (hab/km²) no padrão pt-BR. Abaixo de 10 guarda 1 decimal (um "0"
 * cru seria lido como ausência); acima, arredonda (o banco já grava 2 casas).
 */
export function formatDensity(value) {
  const n = Number(value);
  if (value === null || value === undefined || value === "" || !Number.isFinite(n)) {
    return "—";
  }
  return n.toLocaleString("pt-BR", {
    minimumFractionDigits: 0,
    maximumFractionDigits: Math.abs(n) < 10 ? 1 : 0,
  });
}

/**
 * Leitura do entorno socioeconômico (Censo 2022) de um anel:
 * "5.362 hab · 6.867 hab/km²". Sem leitura (null), devolve "—" (#154).
 */
export function entornoLabel(entorno) {
  if (!entorno) return "—";
  const partes = [];
  const pop = formatCount(entorno.pop_total);
  const dens = formatDensity(entorno.densidade_pop_km2);
  if (pop !== "—") partes.push(`${pop} hab`);
  if (dens !== "—") partes.push(`${dens} hab/km²`);
  return partes.length ? partes.join(" · ") : "—";
}

/** Formata uma área em km² no padrão pt-BR. */
export function formatAreaKm2(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "—";
  return `${n.toLocaleString("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  })} km²`;
}

/** Formata um timestamp (ISO/Postgres) em data/hora pt-BR (ou null). */
export function formatComputedAt(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value);
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}
