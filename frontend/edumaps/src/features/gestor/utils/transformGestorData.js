// src/features/gestor/utils/transformGestorData.js
//
// Transformações puras do payload de GET /api/gestor/:inep/painel para o
// formato consumido pelos gráficos (@carbon) e pelas listas do painel.

/** Donut de matrículas por etapa (só etapas com alunos). */
export function buildEtapaRows(porEtapa = []) {
  return porEtapa
    .filter((e) => Number(e.value) > 0)
    .map((e) => ({ group: e.label, value: Number(e.value) }));
}

/** Barras de matrículas por faixa etária. */
export function buildFaixaRows(porFaixa = []) {
  return porFaixa.map((f) => ({
    group: "Alunos",
    key: f.label,
    value: Number(f.value) || 0,
  }));
}

/** Itens de lista (com barra proporcional) para turno/modalidade/vínculo/formacao. */
export function toBreakdownItems(items = []) {
  return items
    .map((i) => ({ key: i.key, label: i.label, value: Number(i.value) || 0 }))
    .filter((i) => i.value > 0);
}

/** Top-N disciplinas com docentes (barras). */
export function buildDisciplinaRows(porDisciplina = [], limit = 8) {
  return [...porDisciplina]
    .map((d) => ({
      group: "Docentes",
      key: d.label,
      value: Number(d.value) || 0,
    }))
    .sort((a, b) => b.value - a.value)
    .slice(0, limit);
}

/** Agrega listas de presença (infra/equip/acess) em {present,total}. */
export function presentStats(items = []) {
  const total = items.length;
  const present = items.filter((i) => i.present).length;
  return { present, total };
}

/** Cartões de resumo do topo (2 minutos de leitura). */
export function resumoCards(resumo = {}) {
  return [
    {
      key: "matriculas",
      label: "Matrículas",
      value: formatInt(resumo.matriculas),
      icon: "matriculas",
    },
    {
      key: "docentes",
      label: "Docentes",
      value: formatInt(resumo.docentes),
      icon: "docente",
    },
    {
      key: "salas",
      label: "Salas de aula",
      value: formatInt(resumo.salas_utilizadas),
      icon: "sala",
    },
    {
      key: "alunos_por_sala",
      label: "Alunos por sala",
      value: formatNumber(resumo.alunos_por_sala),
      icon: "alunos_por_sala",
    },
  ];
}

function toNum(value) {
  if (value === null || value === undefined || value === "") return NaN;
  return Number(value);
}

export function formatInt(value) {
  const num = toNum(value);
  if (!Number.isFinite(num)) return "—";
  return num.toLocaleString("pt-BR");
}

export function formatNumber(value) {
  const num = toNum(value);
  if (!Number.isFinite(num)) return "—";
  return num.toLocaleString("pt-BR", { maximumFractionDigits: 1 });
}
