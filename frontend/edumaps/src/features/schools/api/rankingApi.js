// src/features/schools/api/rankingApi.js
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * Obtém a lista de indicadores disponíveis para uma escola
 *
 * @param {string|number} codInep - Código INEP da escola
 * @returns {Promise<Array<{ id: string, label: string, available: boolean }>>}
 *
 * @example
 * const indicators = await getAvailableIndicators(35123456);
 * // => [{ id: 'ideb_anos_finais', label: 'IDEB – Anos Finais', available: true }, ...]
 */
export function getAvailableIndicators(codInep) {
  return apiClient.get(`${BASE}/${codInep}/indicators`);
}

/**
 * Obtém o ranking de uma escola para um indicador específico
 *
 * @param {string|number} codInep - Código INEP da escola
 * @param {string} indicatorId - ID do indicador (ex: 'ideb_anos_finais')
 * @param {Object} [opts] - Opções adicionais
 * @param {string} [opts.network] - Filtrar por rede: 'municipal' | 'estadual' | 'privada' | null
 * @param {boolean} [opts.national] - Incluir ranking nacional
 * @returns {Promise<{
 *   indicador: { id: string, label: string, valor: number },
 *   ano: number,
 *   rede: string | null,
 *   ranking: {
 *     municipio: { posicao: number, total: number, percentil: number } | null,
 *     estado: { posicao: number, total: number, percentil: number } | null,
 *     nacional: { posicao: number, total: number, percentil: number } | null
 *   }
 * }>}
 *
 * @example
 * const ranking = await getSchoolRanking(35123456, 'ideb_anos_finais', { network: 'estadual' });
 * // => { indicador: { ... }, ano: 2023, rede: 'estadual', ranking: { ... } }
 */
export function getSchoolRanking(codInep, indicatorId, opts = {}) {
  const params = { indicador: indicatorId };
  if (opts.network) params.rede = opts.network;
  if (opts.national) params.nacional = "1";
  return apiClient.get(`${BASE}/${codInep}/ranking`, params);
}
