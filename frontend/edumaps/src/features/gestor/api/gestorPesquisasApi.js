// src/features/gestor/api/gestorPesquisasApi.js
//
// Espelha EduMaps::Plugin::API::Pesquisa (base /api/gestor/pesquisas).
// Fase 1: cadastro do gestor + CRUD de pesquisas (rascunho -> publicada).
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/gestor/pesquisas";

/**
 * Cadastro/upsert do gestor por e-mail (não existe login no EduMaps ainda).
 * @param {{cod_inep: string|number, nome: string, email: string, telefone?: string, cargo?: string, cpf?: string}} perfil
 * @returns {Promise<{id: number, cod_inep: number, nome: string, email: string, telefone: string|null, cargo: string|null, cpf_masc: string|null}>}
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