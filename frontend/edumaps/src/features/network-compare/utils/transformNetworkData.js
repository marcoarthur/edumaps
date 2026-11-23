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
 * Texto do tooltip de um ponto da linha do IDEB (#479): média e em quantas
 * escolas ela se apoia.
 */
export function idebTooltipText({ group, key, value, escolas }) {
  const media = Number(value).toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const n = escolas == null ? "" : ` (${Number(escolas).toLocaleString("pt-BR")} ${Number(escolas) === 1 ? "escola" : "escolas"} com IDEB)`;
  return `${group}, ${key}: ${media}${n}`;
}

/**
 * Linhas IDEB (por rede · etapa × ano). Ignora entradas sem ideb_medio.
 */
export function buildIdedTimeline(performance) {
  const rows = [];
  for (const p of performance ?? []) {
    if (p.ideb_medio == null) continue;
    const group = `${redeLabel(p.rede)} · ${etapaLabel(p.etapa)}`;
    // #479 (RP-03): escolas com IDEB naquele ponto, para o tooltip.
    const escolas = p.numero_escolas == null ? null : toNumber(p.numero_escolas);
    rows.push({ group, key: String(p.ano), value: toNumber(p.ideb_medio), escolas });
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
/**
 * URL do Perfil da Rede (/municipio/perfil). Sem `codigoRede`, o perfil
 * reúne todas as redes do município.
 * @param {string|number} codigoIbge
 * @param {number} [codigoRede] tp_dependencia (1 federal … 4 privada)
 */
export function networkProfileUrl(codigoIbge, codigoRede) {
  const params = new URLSearchParams({ codigo_ibge: String(codigoIbge) });
  if (codigoRede != null) params.set("dependencia", String(codigoRede));
  return `/municipio/perfil?${params}`;
}

/**
 * URL da comparação de redes de um município (lê `codigo_ibge`).
 * @param {string|number} codigoIbge
 */
export function networkCompareUrl(codigoIbge) {
  return `/municipio/compare?codigo_ibge=${encodeURIComponent(String(codigoIbge))}`;
}

/**
 * #533 (QP-01 da P2): taxa de atendimento da educação infantil, a meta 1 do
 * PNE (creche para 50% das crianças de 0 a 3 anos, pré-escola para todas as
 * de 4 e 5). Matrículas da etapa sobre a população na idade (Censo
 * Demográfico), em três recortes: todas as redes (a meta), a rede municipal
 * e a municipal mais as privadas conveniadas com a prefeitura (teto: o
 * Censo marca a escola conveniada, não a vaga, #520).
 *
 * Devolve null sem a população carregada.
 */
export function buildAtendimentoInfantil(networks) {
  const first = networks?.[0];
  if (!first) return null;
  const pop = { creche: Number(first.populacao_0_3), pre: Number(first.populacao_4_5) };
  if (!(pop.creche > 0) || !(pop.pre > 0)) return null;

  const porRede = (key) => networks.find((n) => normalizeRede(n.rede) === key);
  // #545: no DF não há prefeitura; a rede local é a distrital (estadual no Censo)
  const df = ehDistritoFederal(first.co_municipio);
  const municipal = porRede(df ? "estadual" : "municipal");
  const privada = porRede("privada");
  const soma = (campo) => networks.reduce((acc, n) => acc + toNumber(n[campo]), 0);

  const etapa = (campo, populacao, meta) => {
    const todas = soma(`matriculas_${campo}`);
    const mun = toNumber(municipal?.[`matriculas_${campo}`]);
    const conv = toNumber(privada?.[`matriculas_${campo}_conveniada`]);
    return {
      populacao,
      todas: todas / populacao,
      municipal: mun / populacao,
      teto: conv > 0 ? (mun + conv) / populacao : null,
      // #547: vagas que faltam para a meta (meta × crianças, para cima,
      // menos as matrículas de todas as redes); 0 quando atingida
      vagas: Math.max(0, Math.ceil(meta * populacao - 1e-9) - todas),
    };
  };

  return {
    ano: first.ano_populacao_idade ?? null,
    redeLocal: df ? "Rede do DF (distrital)" : "Rede municipal",
    creche: { ...etapa("creche", pop.creche, 0.5), meta: 0.5 },
    pre: { ...etapa("pre", pop.pre, 1), meta: 1 },
  };
}

export const formatPercent = (fraction, digits = 1) =>
  `${formatDecimal(toNumber(fraction) * 100, digits)}%`;

/** #545: o Distrito Federal (sem prefeitura: a rede local é a distrital). */
export const ehDistritoFederal = (codigoIbge) => String(codigoIbge ?? "") === "5300108";

