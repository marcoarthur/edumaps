// src/features/chat/api/chatApi.js
//
// Espelha EduMaps::Plugin::API::Chat + POST /api/chat/ask + GET /api/chat/progress.
// Todo fetch passa por aqui para permitir mock simples nos testes.

import { apiClient } from "@/shared/api/client.js";

/**
 * Enfileira a pergunta ao Assistente do Censo (chat NL->SQL) na fila
 * dedicada 'analytics' e devolve 202 + Location para polling/SSE.
 *
 * @param {Object} payload
 * @param {string} payload.pergunta - Pergunta do gestor (máx. 500 chars).
 * @param {Object} payload.contexto - Escopo do gestor (opcional).
 *   @param {string} [payload.contexto.cod_municipio] - Código IBGE do município (7 dígitos).
 *   @param {string} [payload.contexto.cod_inep] - Código INEP da escola (8 dígitos).
 *   @param {string} [payload.contexto.nome_municipio] - Nome do município.
 *   @param {string} [payload.contexto.nome_escola] - Nome da escola.
 *   @param {string} [payload.contexto.sg_uf] - Sigla da UF (2 letras).
 * @returns {Promise<{ task: string, job_id: number }>}
 */
export function askChat(payload) {
  return apiClient.post("/api/chat/ask", payload);
}

/**
 * Snapshot JSON do job (polling simples) ou SSE (Accept: text/event-stream).
 * Sem o header `Accept: text/event-stream`, devolve JSON com { state, error? }.
 *
 * @param {string|number} jobId
 * @returns {Promise<{ state: string, error?: string, result?: object }>}
 */
export function getChatProgress(jobId) {
  return apiClient.get("/api/chat/progress", { job_id: jobId });
}

/**
 * Versão SSE (EventSource) do progresso — útil para UI reativa.
 * Retorna um EventSource que emite eventos 'progress' até estado terminal.
 *
 * @param {string|number} jobId
 * @returns {EventSource}
 */
export function getChatProgressStream(jobId) {
  const url = new URL("/api/chat/progress", window.location.origin);
  url.searchParams.set("job_id", jobId);
  const es = new EventSource(url.toString(), { withCredentials: true });
  return es;
}

/**
 * Extrai o SQL do payload final do job (se houver).
 * @param {object} jobResult
 * @returns {string|null}
 */
export function extractSql(jobResult) {
  return jobResult?.sql ?? null;
}

/**
 * Extrai a resposta textual do job.
 * @param {object} jobResult
 * @returns {string|null}
 */
export function extractResposta(jobResult) {
  return jobResult?.resposta ?? null;
}

/**
 * Extrai o resultado tabular do job.
 * @param {object} jobResult
 * @returns {object|null}
 */
export function extractResultado(jobResult) {
  return jobResult?.resultado ?? null;
}

/**
 * Extrai as tabelas de origem (clean./analytics.) usadas na consulta.
 * @param {object} jobResult
 * @returns {string[]}
 */
export function extractOrigem(jobResult) {
  return Array.isArray(jobResult?.origem) ? jobResult.origem : [];
}

/**
 * Extrai as linhas/colunas do resultado.
 * @param {object} jobResult
 * @returns {{linhas: number, colunas: number}}
 */
export function extractMeta(jobResult) {
  return {
    linhas: jobResult?.linhas ?? 0,
    colunas: jobResult?.colunas ?? 0,
  };
}