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
