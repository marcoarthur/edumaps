// src/features/gestor/constants/planos.js — rótulos dos planos de gestão (#371).
// Os valores espelham os CHECKs da change planos_gestao.

export const PLANO_TIPOS = [
  { valor: "gestao", rotulo: "Plano de gestão do diretor" },
  { valor: "acao", rotulo: "Plano de ação (PDDE / PDE Escola)" },
  { valor: "ppp", rotulo: "Projeto Político-Pedagógico (PPP)" },
  { valor: "outro", rotulo: "Outro plano" },
];
export const PLANO_TIPO_LABEL = Object.fromEntries(PLANO_TIPOS.map((t) => [t.valor, t.rotulo]));

export const PLANO_SITUACAO_LABEL = { rascunho: "Rascunho", vigente: "Vigente", encerrado: "Encerrado" };
export const PLANO_SITUACAO_BADGE = {
  rascunho: "bg-gray-100 text-gray-700",
  vigente: "bg-green-100 text-green-800",
  encerrado: "bg-blue-100 text-blue-800",
};

export const ACAO_SITUACOES = [
  { valor: "nao_iniciada", rotulo: "Não iniciada" },
  { valor: "em_andamento", rotulo: "Em andamento" },
  { valor: "concluida", rotulo: "Concluída" },
  { valor: "cancelada", rotulo: "Cancelada" },
];
export const ACAO_SITUACAO_LABEL = Object.fromEntries(ACAO_SITUACOES.map((s) => [s.valor, s.rotulo]));

export const FONTES_RECURSO = [
  { valor: "pdde", rotulo: "PDDE" },
  { valor: "fundeb", rotulo: "Fundeb" },
  { valor: "proprio", rotulo: "Recurso próprio" },
  { valor: "parceria", rotulo: "Parceria" },
  { valor: "outro", rotulo: "Outro" },
];
export const FONTE_RECURSO_LABEL = Object.fromEntries(FONTES_RECURSO.map((f) => [f.valor, f.rotulo]));

export const SENTIDOS = [
  { valor: "aumentar", rotulo: "Aumentar" },
  { valor: "reduzir", rotulo: "Reduzir" },
  { valor: "manter", rotulo: "Manter (não cair abaixo do alvo)" },
];

// Estado da meta (backend: progresso_meta). Nunca "0%" sem medição (#154).
export const META_ESTADO_LABEL = {
  medida: null,
  sem_medicao: "Sem medição",
  sem_dado: "Sem dado da escola na fonte",
  rascunho: "Defina linha de base e alvo",
  incoerente: "Alvo incoerente com o sentido",
};

/**
 * Valor com a unidade da meta (P1-PG-06): "%" cola no número ("12%"); as
 * demais unidades vêm depois, com espaço ("320 alunos"). Sem valor → "—".
 */
export function fmtComUnidade(v, unidade) {
  if (v === null || v === undefined || v === "") return "—";
  const n = fmtNum(v);
  if (!unidade) return n;
  return unidade === "%" ? `${n}%` : `${n} ${unidade}`;
}

/** Valor em reais (pt-BR, 2 casas); null → "—" (sem custo não é R$ 0). */
export function fmtMoeda(v) {
  if (v === null || v === undefined || v === "") return "—";
  return Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}

/** 0..1 → "42%"; null → null (quem chama decide o texto). */
export function pct(fracao) {
  if (fracao === null || fracao === undefined) return null;
  return `${Math.round(fracao * 100)}%`;
}

/** "2026-03-31" → "31/03/2026". */
export function fmtData(iso) {
  if (!iso) return "—";
  const [a, m, d] = String(iso).slice(0, 10).split("-");
  return d && m && a ? `${d}/${m}/${a}` : iso;
}

/** Número em pt-BR (até 2 casas). */
export function fmtNum(v) {
  if (v === null || v === undefined) return "—";
  return Number(v).toLocaleString("pt-BR", { maximumFractionDigits: 2 });
}

export const PLANO_LIMITS = { TITULO_MAX: 200, OBJETIVO_MAX: 300, DESCRICAO_MAX: 500, RESPONSAVEL_MAX: 120 };
