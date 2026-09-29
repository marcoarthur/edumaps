// src/features/network-compare/utils/transformNetworkProfileData.js
//
// Transforma a resposta do `GET /api/network/:ibge/profile` (issue #109)
// no formato dos componentes: indicadores da rede vs. Brasil e clusters
// agrupados (nº de escolas + médias por indicador).

function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return [value];
  return [];
}

export const DEPENDENCIA_LABELS = {
  1: "Federal",
  2: "Estadual",
  3: "Municipal",
  4: "Privada",
};

export function formatNetworkValue(indicador, value) {
  if (value === null || value === undefined || value === "") return "–";
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  if (/^prop_/.test(String(indicador))) return `${(n * 100).toFixed(1)}%`;
  return n.toFixed(1);
}

/**
 * Agrupa a tabela longa de clusters em [{ cluster_id, cluster_label, n,
 * indicadores: [{ indicador, label, media }] }].
 */
export function groupClusters(clusters) {
  const map = new Map();
  for (const row of asArray(clusters)) {
    const key = row.cluster_id ?? "__sem__";
    if (!map.has(key)) {
      map.set(key, {
        cluster_id: row.cluster_id ?? null,
        cluster_label: row.cluster_label ?? "Sem cluster",
        n: Number(row.n) || 0,
        indicadores: [],
      });
    }
    map.get(key).indicadores.push({
      indicador: row.indicador,
      label: row.label ?? row.indicador,
      media: row.media === null || row.media === undefined ? null : Number(row.media),
    });
  }
  return [...map.values()];
}

/**
 * @param {object} raw Payload cru do endpoint /network/profile.
 * @returns {{ metadata, metrics, indicadores, clusters }}
 */
export function transformNetworkProfileData(raw) {
  const meta = raw?.metadata ?? {};

  return {
    analysis: raw?.analysis ?? "network_profile",
    metadata: {
      codigoIbge: meta.codigo_ibge,
      municipio: meta.no_municipio,
      uf: meta.sg_uf,
      dependencia: meta.tp_dependencia,
      dependenciaLabel: DEPENDENCIA_LABELS[meta.tp_dependencia] ?? null,
      anoCenso: meta.nu_ano_censo,
    },
    metrics: raw?.metrics ?? {},
    indicadores: asArray(raw?.tables?.indicadores),
    clusters: groupClusters(raw?.tables?.clusters),
  };
}
