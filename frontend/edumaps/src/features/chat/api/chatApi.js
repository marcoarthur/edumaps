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
 * Salva a conversa atual do gestor logado.
 * @param {Object} payload
 * @param {string} [payload.titulo] - Título opcional para a conversa
 * @param {Array} payload.messages - Array de mensagens { role, content, meta }
 * @returns {Promise<{ id: number }>}
 */
export function saveConversa(payload) {
  return apiClient.post("/api/chat/conversas", payload);
}

/**
 * Lista conversas do gestor logado (paginado).
 * @param {Object} params
 * @param {number} [params.page=1]
 * @param {number} [params.per_page=20]
 * @param {string} [params.from] - Data inicial (YYYY-MM-DD)
 * @param {string} [params.to] - Data final (YYYY-MM-DD)
 * @returns {Promise<{ items: Array, page: number, per_page: number, total: number, total_pages: number }>}
 */
export function listConversas(params = {}) {
  return apiClient.get("/api/chat/conversas", params);
}

/**
 * Obtém detalhes de uma conversa específica.
 * @param {string|number} id
 * @returns {Promise<{ id, titulo, created_at, updated_at, messages: Array }>}
 */
export function getConversa(id) {
  return apiClient.get(`/api/chat/conversas/${id}`);
}

/**
 * Exclui uma conversa do gestor logado.
 * @param {string|number} id
 * @returns {Promise<void>}
 */
export function deleteConversa(id) {
  return apiClient.delete(`/api/chat/conversas/${id}`);
}

/**
 * Busca full-text no conteúdo das mensagens.
 * @param {Object} params
 * @param {string} params.q - Termo de busca
 * @param {number} [params.page=1]
 * @param {number} [params.per_page=20]
 * @returns {Promise<{ items: Array, page: number, per_page: number, total: number, total_pages: number }>}
 */
export function searchConversas(params) {
  return apiClient.get("/api/chat/conversas/search", params);
}

/**
 * Obtém dias com conversas no intervalo para o calendário.
 * @param {Object} params
 * @param {string} params.from - Data inicial (YYYY-MM-DD)
 * @param {string} params.to - Data final (YYYY-MM-DD)
 * @returns {Promise<{ [date: string]: number }>}
 */
export function getCalendar(params) {
  return apiClient.get("/api/chat/conversas/calendar", params);
}

/**
 * Exporta conversas selecionadas ou todas para Markdown.
 * @param {Object} params
 * @param {Array<number>} [params.ids] - IDs das conversas a exportar
 * @param {boolean} [params.all] - Se true, exporta todas
 * @returns {Promise<Blob>} - Blob do arquivo .md
 */
export function exportConversas(params) {
  const url = new URL("/api/chat/conversas/export", window.location.origin);
  if (params.ids) {
    params.ids.forEach(id => url.searchParams.append("ids[]", id));
  }
  if (params.all) {
    url.searchParams.set("all", "1");
  }
  return fetch(url.toString(), {
    method: "GET",
    credentials: "include",
    headers: { Accept: "text/markdown" },
  }).then(r => {
    if (!r.ok) throw new Error("Falha ao exportar");
    return r.blob();
  });
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