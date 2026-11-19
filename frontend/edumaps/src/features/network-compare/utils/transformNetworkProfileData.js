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
 * Diferença rede − Brasil (#421): proporções em pontos percentuais
 * ("−43,6 p.p.", não "−43,6%", que leria como variação relativa) e sinal
 * explícito.
 */
export function formatNetworkVariacao(indicador, value) {
  if (value === null || value === undefined || value === "") return "–";
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  const sinal = n > 0 ? "+" : "";
  if (/^prop_/.test(String(indicador))) return `${sinal}${(n * 100).toFixed(1)} p.p.`;
  return `${sinal}${n.toFixed(1)}`;
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
        cluster_label: row.cluster_label ?? "Sem INSE",
        n: Number(row.n) || 0,
        indicadores: [],
      });
    }
    map.get(key).indicadores.push({
      indicador: row.indicador,
      label: row.label ?? row.indicador,
      media: row.media === null || row.media === undefined ? null : Number(row.media),
      // #479 (RP-02): escolas com valor no indicador (a média ignora as sem).
      nComValor: row.n_com_valor == null ? null : Number(row.n_com_valor),
    });
  }
  return [...map.values()];
}

/**
 * Rótulo do indicador com a edição (#479). Desde a #483, o IDEB e o SAEB
 * vêm por etapa (`ideb_anos_iniciais` …), com o rótulo pronto ("IDEB 2023,
 * anos iniciais"). Perfil em cache antigo (`ideb_observado`, etapas
 * misturadas) fica marcado.
 */
export function rotuloIndicadorRede(ind, metadata = {}) {
  const base = ind.label ?? ind.indicador;
  const anoIdeb = metadata.anoIdeb ? ` ${metadata.anoIdeb}` : "";
  if (ind.indicador === "ideb_observado") return `IDEB${anoIdeb} (etapas misturadas)`;
  if (ind.indicador === "nota_media") return `Nota média SAEB${anoIdeb} (etapas misturadas)`;
  if (ind.indicador === "inse" && metadata.anoInse) return `${base} ${metadata.anoInse}`;
  return base;
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
      anoIdeb: meta.ano_ideb ?? null,
      anoInse: meta.ano_inse ?? null,
      // #497: qual Brasil é a referência (com a rede filtrada, a mesma rede)
      referenciaEscopo: meta.referencia_escopo ?? "brasil",
      referenciaRotulo: meta.referencia_rotulo ?? "Brasil",
      nBrasil: meta.n_brasil == null ? null : Number(meta.n_brasil),
      // #497: critério dos grupos (níveis do INSE do INEP)
      grupoCriterio: meta.grupo_criterio ?? null,
    },
    metrics: raw?.metrics ?? {},
    indicadores: asArray(raw?.tables?.indicadores).map((ind) => ({
      ...ind,
      nComValor: ind.n_com_valor == null ? null : Number(ind.n_com_valor),
    })),
    clusters: groupClusters(raw?.tables?.clusters),
  };
}
