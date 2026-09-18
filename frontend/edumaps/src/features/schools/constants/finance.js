// src/features/schools/constants/finance.js
//
// Buckets curados de categoria profissional para o painel financeiro.
// O banco (clean.remuneracao_municipal) guarda `tipo` (2 valores, com
// encoding irregular) e `categoria` (texto longo). Agrupamos em poucos baldes
// com ícone, com fallback para "Outros profissionais".

export const MONTH_ABBR = [
  "", "Jan", "Fev", "Mar", "Abr", "Mai", "Jun",
  "Jul", "Ago", "Set", "Out", "Nov", "Dez",
];

export const MONTH_FULL = [
  "", "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
];

export const FINANCE_BUCKETS = [
  {
    id: "docentes",
    label: "Docentes",
    icon: "docente",
    color: "#2563eb",
    match: [/licenciatura/i, /magist[eé]rio/i, /docente/i, /professor/i],
  },
  {
    id: "administrativo",
    label: "Administrativo",
    icon: "administrativo",
    color: "#7c3aed",
    match: [/secretaria/i, /administrativ/i, /apoio/i, /gest[aã]o/i],
  },
  {
    id: "alimentacao",
    label: "Alimentação",
    icon: "alimentacao",
    color: "#16a34a",
    match: [/alimenta/i, /merendeir/i],
  },
  {
    id: "multimeios",
    label: "Multimeios e infraestrutura",
    icon: "multimeios",
    color: "#f59e0b",
    match: [/multimeios/i, /infraestrutura/i],
  },
];

export const FALLBACK_BUCKET = {
  id: "outros",
  label: "Outros profissionais",
  icon: "outros_profissionais",
  color: "#64748b",
};

/**
 * Mapeia uma categoria/tipo brutos para um bucket curado (ou o fallback).
 * A primeira regra que casar vence — a ordem importa.
 */
export function bucketFor({ categoria, tipo } = {}) {
  const text = `${categoria ?? ""} ${tipo ?? ""}`;
  for (const bucket of FINANCE_BUCKETS) {
    if (bucket.match.some((re) => re.test(text))) return bucket;
  }
  return FALLBACK_BUCKET;
}

/** Rótulo curto da competência para o eixo do gráfico (ex.: "Jan/2025"). */
export function periodLabel(mesNum, ano) {
  return `${MONTH_ABBR[mesNum] ?? "?"}/${ano}`;
}

/** Valor de competência no formato aceito pela rota de folha (MM-YYYY). */
export function periodKey(mesNum, ano) {
  return `${String(mesNum).padStart(2, "0")}-${ano}`;
}
