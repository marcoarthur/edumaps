// src/features/schools/utils/transformEvolutionData.js
//
// Transforma a resposta do `GET /api/school/:cod_inep/evolution` no formato
// dos componentes: séries agrupadas por (indicador, etapa), com os pontos
// ordenados por ano e a variação (do resumo quando disponível).
import { asArray } from "./transformProfileData.js";

export const EVOLUTION_ORDER = [
  "ideb_observado",
  "saeb_media",
  "saeb_matematica",
  "saeb_portugues",
];

export const ETAPA_LABELS = {
  fundamental_i: "Anos Iniciais",
  fundamental_ii: "Anos Finais",
  ensino_medio: "Ensino Médio",
};

export function formatEvolutionValue(value) {
  if (value === null || value === undefined || value === "") return "–";
  const n = Number(value);
  if (Number.isNaN(n)) return "–";
  return n.toFixed(1);
}

function resumoVariacao(resumo, indicador, etapa) {
  const hit = asArray(resumo).find(
    (r) =>
      r.indicador === indicador &&
      (r.etapa ?? null) === (etapa ?? null),
  );
  return hit && hit.variacao !== undefined && hit.variacao !== null
    ? Number(hit.variacao)
    : null;
}

/**
 * Agrupa a série longa em séries por (indicador, etapa).
 * @returns {Array<{ indicador, label, etapa, etapaLabel, pontos, variacao }>}
 */
export function groupEvolution(series, resumo = []) {
  const groups = new Map();

  for (const row of asArray(series)) {
    if (!row || row.indicador === undefined) continue;
    const etapa = row.etapa ?? null;
    const key = `${row.indicador}::${etapa ?? ""}`;
    if (!groups.has(key)) {
      groups.set(key, {
        indicador: row.indicador,
        label: row.label ?? row.indicador,
        etapa,
        etapaLabel: etapa ? ETAPA_LABELS[etapa] ?? etapa : null,
        pontos: [],
        variacao: null,
      });
    }
    groups.get(key).pontos.push({
      ano: Number(row.ano),
      valor: row.valor === null || row.valor === undefined ? null : Number(row.valor),
    });
  }

  const result = [...groups.values()].map((g) => {
    g.pontos.sort((a, b) => a.ano - b.ano);
    g.variacao = resumoVariacao(resumo, g.indicador, g.etapa);
    return g;
  });

  const rank = (id) => {
    const i = EVOLUTION_ORDER.indexOf(id);
    return i === -1 ? EVOLUTION_ORDER.length : i;
  };
  result.sort((a, b) => rank(a.indicador) - rank(b.indicador) || (a.etapa ?? "").localeCompare(b.etapa ?? ""));

  return result;
}

/**
 * @param {object} raw Payload cru do endpoint /evolution.
 * @returns {{ analysis, school, series, groups, metrics }}
 */
export function transformEvolutionData(raw) {
  const meta = raw?.metadata ?? {};
  const series = asArray(raw?.data);
  const resumo = asArray(raw?.tables?.resumo);

  return {
    analysis: raw?.analysis ?? "school_evolution",
    school: {
      co_entidade: meta.co_entidade,
      nome: meta.no_entidade,
      municipio: meta.no_municipio,
      uf: meta.sg_uf,
      rede: meta.rede,
    },
    series,
    groups: groupEvolution(series, resumo),
    metrics: raw?.metrics ?? {},
  };
}
