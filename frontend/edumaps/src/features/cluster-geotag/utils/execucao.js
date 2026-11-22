import { ETAPAS_IDEB, usaIdeb, rotuloCurto } from "../constants/cluster.js";
// src/features/cluster-geotag/utils/execucao.js
//
// Execuções guardadas do agrupamento (#427): leitura do universo e rótulo
// legível dos indicadores, sem depender da tela.

/**
 * Rótulo curto de um indicador a partir do comentário da coluna no catálogo
 * (`/api/cluster/columns`): tira a pergunta ("Há água potável na escola?")
 * e a fórmula entre parênteses. Sem comentário, o nome da coluna.
 * @param {string} coluna
 * @param {Array<{column_name: string, comment?: string}>} [columns]
 */
export function rotuloIndicador(coluna, columns = []) {
  const c = columns.find((col) => col.column_name === coluna);
  return rotuloCurto(c?.comment) || coluna;
}

/**
 * Resumo do universo de uma execução em frases curtas.
 * @param {object} execucao - resposta de /api/cluster/execucoes/:run_id
 * @param {Array} [columns] - catálogo, para os nomes dos indicadores
 * @returns {{ total: number|null, agrupadas: number|null, fora: number,
 *   motivos: Array<{texto: string, n: number}>, foraDoMapa: number }}
 */
export function resumoUniverso(execucao, columns = []) {
  const u = execucao?.universo ?? {};
  const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : null);
  const total = num(u.n_total) ?? num(u.n_recorte);
  const agrupadas = num(u.n_agrupadas) ?? num(execucao?.n_atribuicoes);
  const motivos = [];
  if (num(u.n_inativas)) motivos.push({ texto: "não funcionam mais", n: num(u.n_inativas) });
  const semDado = Object.entries(u.sem_dado ?? {})
    .map(([col, n]) => ({ texto: `sem dado de ${rotuloIndicador(col, columns).toLowerCase()}`, n: num(n) ?? 0 }))
    .filter((m) => m.n > 0)
    .sort((a, b) => b.n - a.n);
  motivos.push(...semDado);
  const fora = total != null && agrupadas != null ? Math.max(total - agrupadas, 0) : 0;
  const foraDoMapa = Math.max((num(execucao?.n_atribuicoes) ?? 0) - (num(execucao?.n_no_mapa) ?? 0), 0);
  return { total, agrupadas, fora, motivos, foraDoMapa };
}

/** "2027-02-13" → "13/02/2027" */
export function dataBR(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso ?? "");
  return m ? `${m[3]}/${m[2]}/${m[1]}` : "";
}

/**
 * Valor de um indicador na unidade de leitura: indicadores 0/1 (`in_*`) e
 * proporções (`prop_*`) em % de escolas/docentes; o resto com até 2 casas.
 * @param {string} coluna
 * @param {number} valor
 */
export function formatarIndicador(coluna, valor) {
  if (valor === null || valor === undefined || valor === "") return "–";
  const v = Number(valor);
  if (!Number.isFinite(v)) return "–";
  if (/^(in|prop)_/.test(coluna)) {
    return `${Math.round(v * 100).toLocaleString("pt-BR")}%`;
  }
  return v.toLocaleString("pt-BR", { maximumFractionDigits: 2 });
}

/**
 * Etapa do IDEB/SAEB de uma execução (#481): o rótulo da etapa escolhida;
 * "etapas misturadas" na execução antiga que agrupou o IDEB sem etapa; null
 * quando a execução não usa o IDEB.
 */
export function etapaExecucao(parametros = {}) {
  const e = ETAPAS_IDEB.find((x) => x.id === parametros?.etapa);
  if (e) return e.label;
  return usaIdeb(parametros?.features ?? []) ? "etapas misturadas (média entre as etapas da escola)" : null;
}
