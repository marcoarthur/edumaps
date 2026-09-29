// src/features/schools/utils/transformProfileData.js
//
// Transforma a resposta do `GET /api/school/:cod_inep/profile` no formato
// que os componentes do painel esperam.
//
// O serviço analítico (Plumber) pode serializar uma tabela de uma linha
// como objeto em vez de array (auto_unbox) — `asArray` normaliza os dois
// formatos, de modo que os componentes sempre recebem arrays.

/** @returns {Array} Sempre um array (objeto único vira [objeto]). */
export function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return [value];
  return [];
}

export const CLUSTER_SOURCE_LABELS = {
  persisted: "cluster da base",
  fallback_kmeans: "cluster estimado (município)",
  none: "sem cluster",
};

export const PEERS_SOURCE_LABELS = {
  similarity_pairs: "pares da base (Gower)",
  gower_municipio: "Gower calculado no município",
};

export const SEVERIDADE_LABELS = {
  alta: "Alta",
  media: "Média",
  baixa: "Baixa",
};

/** Indicadores expressos como proporção 0..1 (exibidos como %). */
export function isProporcao(indicador) {
  return /^prop_/.test(String(indicador));
}

/**
 * Formata o valor de um indicador para exibição.
 * `null`/`undefined`/NaN viram "–".
 */
export function formatIndicator(indicador, value) {
  if (value === null || value === undefined || value === "") return "–";
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  if (isProporcao(indicador)) return `${(n * 100).toFixed(1)}%`;
  return n.toFixed(1);
}

/** Similaridade (0..1) como percentual inteiro. */
export function formatSimilarity(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  return `${Math.round(n * 100)}%`;
}

/** Quartil do cluster (1..4) como rótulo curto. */
export function formatQuartil(quartil) {
  const q = Number(quartil);
  if (!q || Number.isNaN(q)) return "–";
  return `Q${q}`;
}

/**
 * @param {object} raw Payload cru do endpoint /profile.
 * @returns {{
 *   analysis: string,
 *   school: object,
 *   cluster: object,
 *   peersSource: string,
 *   peersSourceLabel: string,
 *   metrics: object,
 *   indicadores: Array<object>,
 *   clusterResumo: Array<object>,
 *   peers: Array<object>,
 *   flags: Array<object>,
 * }}
 */
export function transformProfileData(raw) {
  const meta = raw?.metadata ?? {};
  const tables = raw?.tables ?? {};

  return {
    analysis: raw?.analysis ?? "school_profile",
    school: {
      co_entidade: meta.co_entidade,
      nome: meta.no_entidade,
      municipio: meta.no_municipio,
      uf: meta.sg_uf,
      anoCenso: meta.nu_ano_censo,
    },
    cluster: {
      id: meta.cluster_id,
      label: meta.cluster_label,
      source: meta.cluster_source,
      sourceLabel: CLUSTER_SOURCE_LABELS[meta.cluster_source] ?? meta.cluster_source,
      scope: meta.cluster_scope,
      size: meta.cluster_size,
    },
    peersSource: meta.peers_source,
    peersSourceLabel: PEERS_SOURCE_LABELS[meta.peers_source] ?? meta.peers_source,
    metrics: raw?.metrics ?? {},
    indicadores: asArray(tables.indicadores_comparados),
    clusterResumo: asArray(tables.cluster_resumo),
    peers: asArray(tables.peers),
    flags: asArray(tables.flags),
  };
}
