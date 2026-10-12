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
// --- Bot público do Telegram (canais.telegram.*) ---------------------------
// Mesmo guard de /api/admin/config (Bearer admin).
const TELEGRAM_BASE = "/api/admin/canais/telegram";

/** Status do bot público: enabled, recebimento, bot_username, webhook?, polling.
 * @returns {Promise<{enabled: number, recebimento: string, bot_username: string,
 *   webhook?: {url: string, pending_update_count: number, last_error_message: string|null},
 *   polling: {ativo: number, offset: number}}>}
 */
export function getTelegramStatus() {
  return apiClient.get(`${TELEGRAM_BASE}/status`);
}

/** Registra o webhook no Telegram (modo webhook). 409 fora do modo / sem
 * URL pública ou segredo; 502 quando o Telegram recusa.
 * @returns {Promise<{ok: 1, url: string}>}
 */
export function registrarTelegramWebhook() {
  return apiClient.post(`${TELEGRAM_BASE}/webhook`);
}

/** Remove o webhook no Telegram. 502 quando o Telegram recusa.
 * @returns {Promise<{ok: 1}>}
 */
export function removerTelegramWebhook() {
  return apiClient.delete(`${TELEGRAM_BASE}/webhook`);
}

/** Inicia o polling (task Minion). 202 {ok, job_id} ou 200 {ok, ja_ativo: 1};
 * 409 fora do modo polling ou com o bot desligado.
 * @returns {Promise<{ok: 1, job_id?: number, ja_ativo?: 1}>}
 */
export function iniciarTelegramPolling() {
  return apiClient.post(`${TELEGRAM_BASE}/polling`);
}
