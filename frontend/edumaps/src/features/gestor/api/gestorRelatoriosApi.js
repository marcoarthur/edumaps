// src/features/gestor/api/gestorRelatoriosApi.js
//
// Assistente de Relatório (issue #219, contrato congelado da onda 1).
// Base /api/gestor/:cod_inep/relatorios — Bearer + posse do :cod_inep.
//
//   GET  /recorte-padrao  → {escola:{cod_inep,nome}, municipio:{codigo,nome},
//                            uf:{codigo,nome}, regiao:{codigo,nome}}
//   GET  /assistentes     → {assistentes:[{id,titulo,descricao,modo,niveis,publico,
//                            temas?, capitulos?:[{tema,titulo}], opcoes, padroes}]}  (fase 4)
//   GET  /temas?nivel&assistente → {temas:[{id,titulo,descricao,niveis,profundidade,opcoes}]}
//   POST /                {geotag:{nivel,codigo}, tema?, opcoes?, assistente?} → 202 {job_id}
//                         (modo composto: sem tema; `assistente` omitido = "relatorio")
//   GET  /jobs/:job_id    → {state, progress?, result?: ReportResult+{cache_hit}, error?}
import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/relatorios`;

export const ESTADOS_FINAIS = ["finished", "failed"];

/** Escola do gestor e o município/UF/região em que ela fica. */
export function getRecortePadrao(inep) {
  return apiClient.get(`${BASE(inep)}/recorte-padrao`);
}

/** Assistente padrão (Fases 1–3): "Relatório por tema". */
export const ASSISTENTE_PADRAO = "relatorio";

/**
 * Assistentes de relatório visíveis ao gestor (fase 4).
 * @returns {Promise<Array<object>>}
 */
export function listarAssistentes(inep) {
  return apiClient.get(`${BASE(inep)}/assistentes`).then((d) => d?.assistentes ?? []);
}

/**
 * Temas disponíveis (opcionalmente só os de um nível e de um assistente).
 * O `assistente` padrão não vai na query (o servidor assume "relatorio").
 * @returns {Promise<Array<object>>}
 */
export function listTemasRelatorio(inep, nivel, assistente) {
  const params = { nivel };
  if (assistente && assistente !== ASSISTENTE_PADRAO) params.assistente = assistente;
  return apiClient.get(`${BASE(inep)}/temas`, params).then((d) => d?.temas ?? []);
}

/** Remove opções vazias (ex.: rede "todas"). */
export function limparOpcoes(opcoes = {}) {
  const out = {};
  for (const [k, v] of Object.entries(opcoes ?? {})) {
    if (v !== undefined && v !== null && v !== "") out[k] = v;
  }
  return out;
}

/**
 * Enfileira a geração do relatório. O `assistente` só vai no corpo quando
 * não é o padrão ("relatorio"), e o `tema` só quando há (no modo composto o
 * assistente define os capítulos e o tema é omitido).
 * @param {{geotag: {nivel: string, codigo: string}, tema?: string, opcoes?: object, assistente?: string}} pedido
 * @returns {Promise<{job_id: number}>}
 */
export function gerarRelatorio(inep, { geotag, tema, opcoes, assistente } = {}) {
  const body = { geotag: { nivel: geotag?.nivel, codigo: String(geotag?.codigo ?? "") } };
  if (tema) body.tema = tema;
  if (assistente && assistente !== ASSISTENTE_PADRAO) body.assistente = assistente;
  const limpas = limparOpcoes(opcoes);
  if (Object.keys(limpas).length) body.opcoes = limpas;
  return apiClient.post(BASE(inep), body);
}

/** Estado do job de geração. */
export function getJobRelatorio(inep, jobId) {
  return apiClient.get(`${BASE(inep)}/jobs/${jobId}`);
}

// ---------------------------------------------------------------- salvos (fase 3)
//
//   POST   /salvos          {job_id} → 201 {salvo} (novo) · 200 {salvo} (já salvo)
//                                     · 404 (job alheio/inexistente) · 409 (job não terminou bem)
//   GET    /salvos          ?page&per_page → {items:[resumo], total, page, per_page}
//   GET    /salvos/:id      → resumo + relatorio (ReportResult gravado) · 404
//   DELETE /salvos/:id      → {ok:1} · 404
//
// O conteúdo salvo vem do resultado do job no servidor, nunca do cliente: o
// POST só leva o job_id.

/**
 * Aceita tanto `{salvo: {...}, relatorio?}` quanto o resumo "achatado" com
 * `relatorio` — o contrato descreve o detalhe como "salvo + relatorio".
 */
function desembrulharSalvo(d) {
  if (d && typeof d === "object" && d.salvo && typeof d.salvo === "object") {
    const relatorio = d.relatorio ?? d.salvo.relatorio;
    return relatorio ? { ...d.salvo, relatorio } : { ...d.salvo };
  }
  return d;
}

/** Salva o relatório gerado pelo job (dedupe pelo job_id no servidor). */
export function salvarRelatorio(inep, jobId) {
  return apiClient
    .post(`${BASE(inep)}/salvos`, { job_id: Number(jobId) })
    .then(desembrulharSalvo);
}

/**
 * Lista paginada dos relatórios salvos do gestor (mais recentes primeiro).
 * @returns {Promise<{items: Array<object>, total: number, page: number, per_page: number}>}
 */
export function listarSalvos(inep, { page = 1, per_page = 20 } = {}) {
  return apiClient.get(`${BASE(inep)}/salvos`, { page, per_page }).then((d) => ({
    items: d?.items ?? [],
    total: Number(d?.total ?? 0),
    page: Number(d?.page ?? page),
    per_page: Number(d?.per_page ?? per_page),
  }));
}

/** Detalhe do salvo: o resumo mais o `relatorio` (fotografia). */
export function getSalvo(inep, id) {
  return apiClient.get(`${BASE(inep)}/salvos/${id}`).then(desembrulharSalvo);
}

/** Exclui o relatório salvo. */
export function excluirSalvo(inep, id) {
  return apiClient.delete(`${BASE(inep)}/salvos/${id}`);
}
