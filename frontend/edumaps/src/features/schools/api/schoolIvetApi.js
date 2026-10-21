// src/features/schools/api/schoolIvetApi.js
//
// Espelha EduMaps::Plugin::API::School#ivet e #isocrona (issue #296).
//
// - IVET: GET /api/school/:cod_inep/ivet — índice de vulnerabilidade de
//   acesso (blocos A–G) da última medição vigente em analytics.ivet_escola.
// - Isócrona: GET /api/school/:cod_inep/isocrona — células H3 da área de
//   influência (15 min a pé, r9; 45 min de carro, r7). A conversão
//   célula→polígono é feita aqui no frontend com h3-js.
//
// Nenhum outro arquivo da feature chama fetch/apiClient diretamente.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * Última medição vigente do IVET da escola.
 *
 * Ausência ≠ 0 (#154): quando o índice não é publicável, `ivet` e/ou
 * blocos chegam como `null` — a UI deve exibir "não calculado", nunca 0.
 *
 * @param {string|number} codInep Código INEP (8 dígitos).
 * @returns {Promise<{
 *   co_entidade: number,
 *   nu_ano_censo: number,
 *   raio_m: number,
 *   ivet: number|null,
 *   publicavel: boolean,
 *   blocos: { A: number|null, B: number|null, C: number|null,
 *             D: number|null, E: number|null, F: number|null,
 *             G: number|null },
 *   formula: string,
 *   dataset_version: string|null,
 *   transform_version: string|null,
 *   dt_snapshot: string,
 *   calculado_em: string,
 * }>} Rejeita (404) quando a escola nunca foi medida.
 */
export function getSchoolIvet(codInep) {
  return apiClient.get(`${BASE}/${codInep}/ivet`);
}

/**
 * Células H3 da isócrona vigente da escola.
 *
 * O backend só entrega a grade; converta cada `grid_id` em polígono com
 * `cellToBoundary` do h3-js antes de desenhar no Leaflet.
 *
 * @param {string|number} codInep Código INEP (8 dígitos).
 * @param {15|45} [tempo] Restringe a uma faixa; sem ele vêm as duas.
 * @returns {Promise<{
 *   co_entidade: number,
 *   dt_snapshot: string,
 *   engine: { nome: string, versao: string, tileset_build_date: string },
 *   tempos: Array<{
 *     tempo_minutos: 15|45,
 *     resolucao_h3: number,
 *     n_celulas: number,
 *     populacao_total: number|null,
 *     celulas: Array<{ grid_id: string, populacao: number|null }>,
 *   }>,
 * }>} Rejeita (404) quando a escola está fora da cobertura extraída.
 */
export function getSchoolIsocrona(codInep, tempo) {
  return apiClient.get(`${BASE}/${codInep}/isocrona`, tempo ? { tempo } : {});
}
