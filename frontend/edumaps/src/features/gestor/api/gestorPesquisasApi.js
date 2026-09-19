// src/features/gestor/api/gestorPesquisasApi.js
//
// Espelha EduMaps::Plugin::API::Pesquisa (base /api/gestor/pesquisas).
// Fase 1: cadastro do gestor + CRUD de pesquisas (rascunho -> publicada).
// Fase 2: login do gestor e link público de resposta (token) + resultados.
import { apiClient, setApiToken } from "@/shared/api/client.js";

const BASE = "/api/gestor/pesquisas";

/**
 * Cadastro/upsert do gestor por e-mail (senha obrigatória na fase 2).
 * @param {{cod_inep: string|number, nome: string, email: string, senha: string, telefone?: string, cargo?: string, cpf?: string}} perfil
 * @returns {Promise<{id: number, cod_inep: number, nome: string, email: string, senha? : never}>}
 */
export function upsertGestor(perfil) {
  return apiClient.post(`${BASE}/perfil`, perfil);
}

/** Lista pesquisas de uma escola.
 * @param {string|number} inep
 * @returns {Promise<Array>}
 */
export function listPesquisas(inep) {
  return apiClient.get(BASE, { inep });
}

/** Cria um rascunho de pesquisa.
 * @param {{gestor_id: number, titulo: string, descricao?: string, perguntas: Array}} payload
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
  const sessao = await apiClient.post("/api/gestor/login", credenciais);
  setApiToken(sessao.token);
  return sessao;
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