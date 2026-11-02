// src/features/gestor/api/gestorPesquisasApi.js
//
// Espelha EduMaps::Plugin::API::Pesquisa (base /api/gestor/pesquisas).
// Cadastro do gestor (anônimo, só cria conta), login, CRUD de pesquisas e
// resultados (com sessão; escola da sessão) e link público de resposta.
import { apiClient, setApiToken } from "@/shared/api/client.js";
import { eventBus } from "@/shared/events";
import { GESTOR_EVENTS } from "../constants/events.js";

const BASE = "/api/gestor/pesquisas";

/**
 * Cadastro do gestor: só cria conta. E-mail já cadastrado responde 409
 * ("Este e-mail já tem conta. Entre com sua senha.").
 * @param {{cod_inep: string|number, nome: string, email: string, senha: string, telefone?: string, cargo?: string, cpf?: string}} perfil
 * @returns {Promise<{id: number, cod_inep: number, nome: string, email: string, senha? : never}>}
 */
export function cadastrarGestor(perfil) {
  return apiClient.post(`${BASE}/perfil`, perfil);
}

/** Lista as pesquisas da escola da sessão (`inep` só confere; outra escola → 403).
 * @param {string|number} inep
 * @returns {Promise<Array>}
 */
export function listPesquisas(inep) {
  return apiClient.get(BASE, { inep });
}

/** Cria um rascunho de pesquisa.
 * O autor e a escola vêm da sessão.
 * @param {{titulo: string, descricao?: string, perguntas: Array}} payload
 * @returns {Promise<object>} pesquisa detalhada
 */
export function createPesquisa(payload) {
  return apiClient.post(BASE, payload);
}

/** Detalhe de uma pesquisa (com perguntas + gestor).
 * @param {string|number} id
 * @returns {Promise<object>}
 */
export function getPesquisa(id) {
  return apiClient.get(`${BASE}/${id}`);
}

/** Autosave: substitui título/descrição e todas as perguntas (só rascunho).
 * @param {string|number} id
 * @param {{titulo: string, descricao?: string, perguntas: Array}} payload
 * @returns {Promise<object>}
 */
export function updatePesquisa(id, payload) {
  return apiClient.put(`${BASE}/${id}`, payload);
}

/** Publica a pesquisa (rascunho -> publicada).
 * @param {string|number} id
 * @returns {Promise<object>}
 */
export function finalizarPesquisa(id) {
  return apiClient.post(`${BASE}/${id}/finalizar`);
}

/** Exclui um rascunho.
 * @param {string|number} id
 * @returns {Promise<null>}
 */
export function deletePesquisa(id) {
  return apiClient.delete(`${BASE}/${id}`);
}

// ---------------------------------------------------------------
// fase 2 — autenticação do gestor
// ---------------------------------------------------------------

/** Abre sessão do gestor e guarda o token para as próximas chamadas.
 * @param {{email: string, senha: string}} credenciais
 * @returns {Promise<{token: string, expira_em: string, gestor: object}>}
 */
export async function loginGestor(credenciais) {
  try {
    const sessao = await apiClient.post("/api/gestor/login", credenciais);
    setApiToken(sessao.token);
    // Telemetria: registra o desfecho do login (nunca e-mail/senha).
    eventBus.emit(GESTOR_EVENTS.LOGIN, { ok: true }, { source: "gestorPesquisasApi" });
    return sessao;
  } catch (err) {
    eventBus.emit(GESTOR_EVENTS.LOGIN, { ok: false }, { source: "gestorPesquisasApi" });
    throw err;
  }
}

// ---------------------------------------------------------------
// esqueci minha senha (#336)
// ---------------------------------------------------------------

/** O link "Esqueci minha senha" só aparece se o e-mail estiver configurado.
 * @returns {Promise<{disponivel: number}>}
 */
export function senhaDisponivel() {
  return apiClient.get("/api/gestor/senha/disponivel");
}

/** Pede o link por e-mail. Responde sempre igual (202), exista a conta ou não.
 * @param {string} email
 * @returns {Promise<{ok: number, mensagem: string}>}
 */
export function pedirRedefinicaoSenha(email) {
  return apiClient.post("/api/gestor/senha/esqueci", { email });
}

/** Grava a senha nova a partir do token do link (uso único).
 * @param {{token: string, senha: string}} payload
 * @returns {Promise<{ok: number}>}
 */
export function redefinirSenha(payload) {
  return apiClient.post("/api/gestor/senha/redefinir", payload);
}

/** Verifica a sessão atual no servidor.
 * @returns {Promise<{id:number, cod_inep:number, nome:string, email:string}>}
 */
export function fetchMe() {
  return apiClient.get("/api/gestor/me");
}

/** Encerra a sessão no servidor e limpa o token local. */
export async function logoutGestor() {
  try {
    await apiClient.post("/api/gestor/logout");
  } finally {
    setApiToken(null);
    eventBus.emit(GESTOR_EVENTS.LOGOUT, undefined, { source: "gestorPesquisasApi" });
  }
}

// ---------------------------------------------------------------
// fase 2 — link público de resposta
// ---------------------------------------------------------------

/** Formulário público de uma pesquisa pelo token (uuid do link).
 * @param {string} token
 * @returns {Promise<{id:number, titulo:string, descricao:string, perguntas:Array}>}
 */
export function getPesquisaPublica(token) {
  return apiClient.get(`${BASE}/publica/${token}`);
}

/** Envia a resposta da comunidade.
 * @param {string} token
 * @param {{identificador_dispositivo: string, respostas: Array}} payload
 * @returns {Promise<{ok: boolean, id: number}>}
 */
export function enviarRespostaPublica(token, payload) {
  return apiClient.post(`${BASE}/publica/${token}/resposta`, payload);
}

// ---------------------------------------------------------------
// fase 2 — resultados
// ---------------------------------------------------------------

/** Resultados agregados de uma pesquisa (exige sessão do gestor da escola).
 * @param {string|number} id
 * @returns {Promise<{n_respostas:number, perguntas:Array}>}
 */
export function getResultados(id) {
  return apiClient.get(`${BASE}/${id}/resultados`);
}