// src/features/schools/api/schoolApi.js
//
// Espelha EduMaps::Plugin::API::School / EduMaps::Controller::School.
// Nenhum outro arquivo da feature chama fetch/apiClient diretamente —
// tudo passa por aqui, o que torna trivial mockar em testes e trocar
// de endpoint sem tocar em componentes.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * @param {{ escola?: string, municipio?: string, limit?: number }} params
 * @returns {Promise<Array<object>>}
 */
export function searchSchools({ escola, municipio, limit } = {}) {
  return apiClient.get(`${BASE}/search`, { escola, municipio, limit });
}

export function getSchoolInfo(codInep) {
  return apiClient.get(`${BASE}/${codInep}/info`);
}

/**
 * Obtém a folha de pagamento (payroll) de uma escola para um determinado mês/ano.
 * @param {string|number} codInep - Código INEP da escola (8 dígitos)
 * @param {string} date - Mês/ano no formato "MM-YYYY" (padrão: "10-2025")
 * @returns {Promise<Array<Object>>} Lista de registros de pagamento
 */
export function getSchoolPayroll(codInep, date = "10-2025") {
  return apiClient.get(`${BASE}/${codInep}/payroll`, { date });
}

export function getSchoolPanelData(codInep) {
  return apiClient.get(`${BASE}/${codInep}/panel/info`);
}

/**
 * Resumo financeiro da escola (custos/profissionais ao longo do tempo +
 * custos por categoria). Fonte: clean.remuneracao_municipal.
 * @param {string|number} codInep
 * @returns {Promise<{ escola: { codigo_inep, nome },
 *   series: Array<{ ano, mes, mes_num, total_salario, total_profissionais }>,
 *   categorias: Array<{ categoria, tipo, total_salario, total_profissionais }> }>}
 */
export function getSchoolFinance(codInep) {
  return apiClient.get(`${BASE}/${codInep}/finance`);
}

// ---------------------------------------------------------------------------
// SIOPE (remuneração municipal) — disparo assíncrono pelo painel financeiro
// ---------------------------------------------------------------------------

/**
 * Enfileira o download do SIOPE para a escola/ano (exige sessão do gestor).
 * @returns {Promise<{ task: string, job_id: number, ano: number }>}
 */
export function requestSchoolSiope(codInep, ano) {
  return apiClient.post(`/api/gestor/${codInep}/financeiro/siope`, { ano });
}

/** Snapshot do job (polling simples). @returns {Promise<{state, error?}>} */
export function getJobProgress(jobId) {
  return apiClient.get("/api/task/progress", { job_id: jobId });
}

/**
 * Acompanha o job por SSE (Server-Sent Events) e, ao encerrar o stream, lê o
 * snapshot final (o SSE não emite falha) para decidir sucesso/erro.
 * @param {string|number} jobId
 * @param {{ onProgress?: (p:object)=>void, onDone?: ()=>void, onError?: (msg:string)=>void }} handlers
 * @returns {() => void} função para cancelar
 */
export function watchJobProgress(jobId, { onProgress, onDone, onError } = {}) {
  let encerrado = false;
  const source = new EventSource(`/api/task/progress?job_id=${jobId}`);

  const finalizar = async () => {
    source.close();
    try {
      const snap = await getJobProgress(jobId);
      if (snap.state === "failed") {
        onError?.(snap.error || "Falha ao baixar os dados do SIOPE.");
      } else {
        onDone?.();
      }
    } catch (err) {
      onError?.(err instanceof Error ? err.message : "Falha ao acompanhar o job.");
    }
  };

  source.onmessage = (event) => {
    try {
      onProgress?.(JSON.parse(event.data));
    } catch {
      // evento sem JSON — ignora
    }
  };

  source.onerror = () => {
    if (encerrado) return;
    encerrado = true;
    finalizar();
  };

  return () => {
    encerrado = true;
    source.close();
  };
}

/**
 * Busca paginada de escolas com suporte a paginação server‑side.
 *
 * O endpoint retorna a estrutura:
 *   {
 *     data: [ ...schools ],
 *     meta: {
 *       current_page,   // número da página atual
 *       per_page,       // itens por página
 *       total_entries,  // total de registros na busca (sem paginação)
 *       total_pages     // última página
 *     }
 *   }
 *
 * @param {Object} params
 * @param {string} [params.escola] - Nome da escola (mínimo 3 caracteres)
 * @param {string} [params.municipio] - Município (mínimo 3 caracteres)
 * @param {number} [params.page=1] - Número da página (>= 1)
 * @param {number} [params.per_page=10] - Itens por página (1 a 500)
 * @returns {Promise<{ data: Array<object>, meta: object }>}
 */
export function searchPaginatedSchools({
  escola,
  municipio,
  page = 1,
  per_page = 10,
} = {}) {
  return apiClient.get(`${BASE}/search/pageable`, {
    escola,
    municipio,
    page,
    per_page,
  });
}
