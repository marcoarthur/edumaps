// src/features/network-compare/utils/transformNetworkData.js
//
// Transformações puras dos dados da API (summary/performance) para os
// formatos consumidos pelos gráficos Carbon e pela tabela. Mantidas fora
// dos componentes para serem testadas isoladamente.
import {
  IDEB_ETAPA_LABELS,
  NETWORK_LABELS,
  NETWORK_ORDER,
  STAGE_AXES,
} from "../constants/indicators.js";

export function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

const round2 = (n) => Math.round(n * 100) / 100;

export const formatInt = (n) =>
  new Intl.NumberFormat("pt-BR").format(toNumber(n));

export const formatDecimal = (n, digits = 1) =>
  toNumber(n).toLocaleString("pt-BR", {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });

export function normalizeRede(rede) {
  const key = String(rede ?? "").toLowerCase();
  return NETWORK_ORDER.includes(key) ? key : key;
}

export function redeLabel(rede) {
  const label = NETWORK_LABELS[normalizeRede(rede)];
  if (label) return label;
  const unknown = String(rede ?? "Outra");
  return unknown.charAt(0).toUpperCase() + unknown.slice(1);
}

/**
 * Cabeçalho do município (campos iguais em todas as entradas da rede).
 */
export function municipalityHeader(networks) {
  const first = networks?.[0];
  return {
    no_municipio: first?.no_municipio ?? "—",
    sg_uf: first?.sg_uf ?? "",
    no_regiao: first?.no_regiao ?? "",
  };
}

function stageTotals(networks) {
  const totals = Object.fromEntries(NETWORK_ORDER.map((r) => [r, 0]));
  for (const net of networks) {
    const key = normalizeRede(net.rede);
    totals[key] = STAGE_AXES.reduce(
      (acc, s) => acc + toNumber(net[s.key]),
      0,
    );
  }
  return totals;
}

function stageAxisMax(networks) {
  const max = Object.fromEntries(STAGE_AXES.map((s) => [s.key, 0]));
  for (const net of networks) {
    for (const s of STAGE_AXES) {
      max[s.key] = Math.max(max[s.key], toNumber(net[s.key]));
    }
  }
  return max;
}

function stageRows(networks, { share }) {
  const totals = stageTotals(networks);
  const axisMax =
    share ? null : stageAxisMax(networks);

  const rows = [];
  for (const net of networks) {
    const group = redeLabel(net.rede);
    for (const stage of STAGE_AXES) {
      const abs = toNumber(net[stage.key]);
      let value = 0;
      if (share) {
        value = totals[normalizeRede(net.rede)] > 0
          ? (abs / totals[normalizeRede(net.rede)]) * 100
          : 0;
      } else if (axisMax[stage.key] > 0) {
        value = (abs / axisMax[stage.key]) * 100;
      }
      rows.push({
        group,
        stage: stage.label,
        value: round2(value),
        matricula: abs,
      });
    }
  }
  return rows;
}

/**
 * Radar "Perfil": participação (%) de cada etapa dentro da própria rede.
 */
export function buildShareRadarData(networks) {
  return stageRows(networks, { share: true });
}

/**
 * Radar "Volume": matrículas normalizadas pelo maior valor de cada etapa.
 */
export function buildVolumeRadarData(networks) {
  return stageRows(networks, { share: false });
}

/**
 * Barras agrupadas de matrículas por etapa × rede.
 */
export function buildStageBars(networks) {
  const rows = [];
  for (const net of networks) {
    const group = redeLabel(net.rede);
    for (const stage of STAGE_AXES) {
      rows.push({
        group,
        key: stage.label,
        value: toNumber(net[stage.key]),
      });
    }
  }
  return rows;
}

/**
 * Donut de participação por rede para um campo numérico (escolas, etc.).
 */
export function buildShareDonut(networks, field) {
  return networks
    .map((net) => ({
      group: redeLabel(net.rede),
      value: toNumber(net[field]),
    }))
    .filter((row) => row.value > 0);
}

const etapaLabel = (etapa) =>
  IDEB_ETAPA_LABELS[String(etapa).toLowerCase()] ?? String(etapa);

/**
 * Linhas IDEB (por rede · etapa × ano). Ignora entradas sem ideb_medio.
 */
export function buildIdedTimeline(performance) {
  const rows = [];
  for (const p of performance ?? []) {
    if (p.ideb_medio == null) continue;
    const group = `${redeLabel(p.rede)} · ${etapaLabel(p.etapa)}`;
    rows.push({ group, key: String(p.ano), value: toNumber(p.ideb_medio) });
  }
  return rows;
}

/**
 * Tabela comparativa — normaliza chaves para exibição amigável.
 */
export function buildTableRows(networks) {
  return networks.map((net) => ({
    ...net,
    rede: redeLabel(net.rede),
  }));
}