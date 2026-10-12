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

// --- Retenção (LGPD) dos canais (canais.retencao.*, issue #214) ------------
const RETENCAO_BASE = "/api/admin/canais/retencao";

/** Prazos, última execução e agendamento da task de retenção.
 * @returns {Promise<{enabled: number|boolean, metadados_dias: number, pendentes_dias: number,
 *   listas_inativas_meses: number,
 *   ultima_execucao: {em: string, metadados: number, pendentes: number, listas_inativas: number}|null,
 *   agendado: number|boolean}>}
 */
export function getRetencaoStatus() {
  return apiClient.get(RETENCAO_BASE);
}

/** Execução avulsa (não reagenda). 202 {ok, job_id}.
 * @returns {Promise<{ok: 1, job_id: number}>}
 */
export function executarRetencao() {
  return apiClient.post(`${RETENCAO_BASE}/executar`);
}

// --- Envios por e-mail (canais.envio.*, issue #216, onda 2) ----------------
const ENVIOS_BASE = "/api/admin/canais/envios";

/** Limites vigentes e volume por escola (envio nos últimos 30 dias ou suspensa).
 * @returns {Promise<{limites: {enabled: number|boolean, ritmo_por_minuto: number, cota_diaria: number,
 *   max_destinatarios: number, smtp_disponivel: number|boolean},
 *   escolas: Array<{cod_inep: number, escola_nome: string, enviados_hoje: number, enviados_30d: number,
 *   falhas_30d: number, optouts_30d: number, envios_em_curso: number,
 *   suspensao: null|{id: number, motivo: string, suspenso_em: string, suspenso_por: number}}>}>}
 */
export function getEnviosAdmin() {
  return apiClient.get(ENVIOS_BASE);
}

/** Suspende os envios de uma escola. 201 {suspensao} · 400 · 409 (já suspensa).
 * @param {string|number} cod_inep
 * @param {string} motivo 1..500
 */
export function suspenderEnvios(cod_inep, motivo) {
  return apiClient.post(`${ENVIOS_BASE}/suspensoes`, { cod_inep: Number(cod_inep), motivo });
}

/** Reativa os envios da escola. 200 {ok, envios_retomados} · 404 (sem suspensão ativa).
 * @param {string|number} cod_inep
 * @returns {Promise<{ok: number, envios_retomados: number}>}
 */
export function reativarEnvios(cod_inep) {
  return apiClient.post(`${ENVIOS_BASE}/suspensoes/${encodeURIComponent(cod_inep)}/reativar`);
}

// --- Versões do texto de consentimento (issue #214) ------------------------
const CONSENTIMENTO_BASE = "/api/admin/consentimento/versoes";

/** @returns {Promise<Array<{id: number, versao: string, texto: string, texto_hash: string,
 *   status: "rascunho"|"vigente"|"arquivada", publicada_em: string|null, created_at: string}>>}
 */
export function listConsentimentoVersoes() {
  return apiClient.get(CONSENTIMENTO_BASE);
}

/** Cria um rascunho. 400 inválido · 409 versão repetida.
 * @param {{versao: string, texto: string}} versao
 */
export function criarConsentimentoVersao({ versao, texto }) {
  return apiClient.post(CONSENTIMENTO_BASE, { versao, texto });
}

/** Edita um rascunho (só os campos passados). 409 se não for rascunho · 404.
 * @param {number} id
 * @param {{versao?: string, texto?: string}} mudancas
 */
export function atualizarConsentimentoVersao(id, mudancas = {}) {
  const body = {};
  for (const campo of ["versao", "texto"]) {
    if (mudancas[campo] !== undefined) body[campo] = mudancas[campo];
  }
  return apiClient.put(`${CONSENTIMENTO_BASE}/${id}`, body);
}

/** Publica o rascunho: vira vigente e a vigente anterior é arquivada. 409 se não for rascunho. */
export function publicarConsentimentoVersao(id) {
  return apiClient.post(`${CONSENTIMENTO_BASE}/${id}/publicar`);
}
