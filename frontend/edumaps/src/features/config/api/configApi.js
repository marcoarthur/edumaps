// src/features/config/api/configApi.js
//
// Espelha EduMaps::Plugin::API::Admin (base /api/admin/config). Toda chamada
// da feature passa por aqui. Exige sessão de gestor com access_role = 'admin'.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/admin/config";

/** Árvore de configuração com estados (categorias/grupos/folhas).
 * @returns {Promise<{categories: Array}>}
 */
export function getConfigTree() {
  return apiClient.get(`${BASE}/tree`);
}

/** Detalhe de uma folha (segredos mascarados em { value: { set: 0|1 } }).
 * @param {string} key
 * @returns {Promise<object>}
 */
export function getConfigItem(key) {
  return apiClient.get(`${BASE}/${encodeURIComponent(key)}`);
}

/** Grava o valor de uma folha.
 * @param {string} key
 * @param {string|number|boolean} value
 * @returns {Promise<object>} item atualizado
 */
export function updateConfigItem(key, value) {
  return apiClient.put(`${BASE}/${encodeURIComponent(key)}`, { value });
}

/** Valida um valor sem gravar.
 * @param {string} key
 * @param {string|number|boolean} value
 * @returns {Promise<{ok: 1, value: *}>}
 */
export function validateConfigItem(key, value) {
  return apiClient.post(`${BASE}/${encodeURIComponent(key)}/validate`, { value });
}