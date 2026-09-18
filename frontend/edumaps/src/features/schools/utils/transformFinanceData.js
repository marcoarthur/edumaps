// src/features/schools/utils/transformFinanceData.js
//
// Transformações puras do resumo financeiro (GET /api/school/:inep/finance)
// para o formato consumido pelos gráficos do @carbon e pela lista de buckets.
import {
  bucketFor,
  periodKey,
  periodLabel,
  MONTH_FULL,
} from "../constants/finance.js";

/** Série de custo total mensal — usado no LineChart. */
export function buildCostRows(series = []) {
  return series.map((s) => ({
    group: "Custo total",
    key: periodLabel(s.mes_num, s.ano),
    value: Number(s.total_salario) || 0,
  }));
}

/** Série de profissionais por mês — usado no LineChart. */
export function buildProfessionalsRows(series = []) {
  return series.map((s) => ({
    group: "Profissionais",
    key: periodLabel(s.mes_num, s.ano),
    value: Number(s.total_profissionais) || 0,
  }));
}

/** Agrega as categorias brutas nos buckets curados (com ícone). */
export function buildCategoryBuckets(categorias = []) {
  const acc = new Map();
  for (const c of categorias) {
    const bucket = bucketFor(c);
    const cur =
      acc.get(bucket.id) ?? { bucket, total_salario: 0, total_profissionais: 0 };
    cur.total_salario += Number(c.total_salario) || 0;
    cur.total_profissionais += Number(c.total_profissionais) || 0;
    acc.set(bucket.id, cur);
  }
  return [...acc.values()].sort((a, b) => b.total_salario - a.total_salario);
}

/** Linhas do DonutChart (custo por bucket). */
export function buildCategoryRows(buckets = []) {
  return buckets.map((b) => ({
    group: b.bucket.label,
    value: Math.round(b.total_salario),
  }));
}

/** Opções do dropdown de competência (mais recente primeiro). */
export function buildPeriodOptions(series = []) {
  return [...series]
    .sort((a, b) => b.ano - a.ano || b.mes_num - a.mes_num)
    .map((s) => ({
      value: periodKey(s.mes_num, s.ano),
      label: `${MONTH_FULL[s.mes_num] ?? s.mes}/${s.ano}`,
    }));
}

/** Totais do período + competência mais recente. */
export function summarize(series = []) {
  const totalCusto = series.reduce(
    (acc, s) => acc + (Number(s.total_salario) || 0),
    0,
  );
  const last = [...series].sort(
    (a, b) => a.ano - b.ano || a.mes_num - b.mes_num,
  ).at(-1);

  return {
    totalCusto,
    mesCount: series.length,
    lastProfessionals: last ? Number(last.total_profissionais) || 0 : 0,
    lastPeriod: last ? periodLabel(last.mes_num, last.ano) : null,
  };
}

export function formatBRL(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return "—";
  return num.toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

export function formatBRLCompact(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return "—";
  if (Math.abs(num) >= 1_000_000) return `R$ ${(num / 1_000_000).toFixed(1)} mi`;
  if (Math.abs(num) >= 1_000) return `R$ ${(num / 1_000).toFixed(0)} mil`;
  return formatBRL(num);
}

export function formatInt(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return "—";
  return num.toLocaleString("pt-BR");
}
