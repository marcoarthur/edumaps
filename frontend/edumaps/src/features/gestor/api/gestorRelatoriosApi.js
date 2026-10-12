// src/features/gestor/api/gestorRelatoriosApi.js
//
// Assistente de Relatório (issue #219, contrato congelado da onda 1).
// Base /api/gestor/:cod_inep/relatorios — Bearer + posse do :cod_inep.
//
//   GET  /recorte-padrao  → {escola:{cod_inep,nome}, municipio:{codigo,nome},
//                            uf:{codigo,nome}, regiao:{codigo,nome}}
//   GET  /temas?nivel     → {temas:[{id,titulo,descricao,niveis,profundidade,opcoes}]}
//   POST /                {geotag:{nivel,codigo}, tema, opcoes?} → 202 {job_id}
//   GET  /jobs/:job_id    → {state, progress?, result?: ReportResult+{cache_hit}, error?}
import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/relatorios`;

export const ESTADOS_FINAIS = ["finished", "failed"];

/** Escola do gestor e o município/UF/região em que ela fica. */
export function getRecortePadrao(inep) {
  return apiClient.get(`${BASE(inep)}/recorte-padrao`);
}

/**
 * Temas disponíveis (opcionalmente só os de um nível).
 * @returns {Promise<Array<object>>}
 */
export function listTemasRelatorio(inep, nivel) {
  return apiClient.get(`${BASE(inep)}/temas`, { nivel }).then((d) => d?.temas ?? []);
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
 * Enfileira a geração do relatório.
 * @param {{geotag: {nivel: string, codigo: string}, tema: string, opcoes?: object}} pedido
 * @returns {Promise<{job_id: number}>}
 */
export function gerarRelatorio(inep, { geotag, tema, opcoes } = {}) {
  const body = { geotag: { nivel: geotag?.nivel, codigo: String(geotag?.codigo ?? "") }, tema };
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
