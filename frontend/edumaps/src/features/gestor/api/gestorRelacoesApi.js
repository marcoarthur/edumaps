// src/features/gestor/api/gestorRelacoesApi.js
//
// Espelha EduMaps::Plugin::API::Gestor (Relações Institucionais da escola).
// Base /api/gestor/:cod_inep/relacoes — exige sessão do gestor (Bearer).
// O GET raiz devolve { categorias, entidades, relacoes } e aceita filtros.

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/relacoes`;

/** @returns {Promise<{categorias:Array, entidades:Array, relacoes:Array}>} */
export function getRelacoes(inep, filtros = {}) {
  return apiClient.get(BASE(inep), filtros);
}

/**
 * Agenda institucional (visão temporal derivada).
 * @returns {Promise<{de,ate,total,vencidas,itens:Array,sem_prazo:Array}>}
 */
export function getAgenda(inep, { de = "", ate = "" } = {}) {
  return apiClient.get(`${BASE(inep)}/agenda`, { de, ate });
}

// ---------------------------------------------------------------------------
// taxonomia (categorias de eixo entidade|finalidade)
// ---------------------------------------------------------------------------

export function createCategoria(inep, { eixo, nome }) {
  return apiClient.post(`${BASE(inep)}/categorias`, { eixo, nome });
}

export function updateCategoria(inep, id, { eixo, nome }) {
  return apiClient.put(`${BASE(inep)}/categorias/${id}`, { eixo, nome });
}

export function deleteCategoria(inep, id) {
  return apiClient.delete(`${BASE(inep)}/categorias/${id}`);
}

// ---------------------------------------------------------------------------
// entidades externas
// ---------------------------------------------------------------------------

export function listEntidades(inep, { tipo = "", q = "" } = {}) {
  return apiClient.get(`${BASE(inep)}/entidades`, { tipo, q });
}

export function createEntidade(inep, entidade) {
  return apiClient.post(`${BASE(inep)}/entidades`, entidade);
}

export function updateEntidade(inep, id, entidade) {
  return apiClient.put(`${BASE(inep)}/entidades/${id}`, entidade);
}

export function deleteEntidade(inep, id) {
  return apiClient.delete(`${BASE(inep)}/entidades/${id}`);
}

// ---------------------------------------------------------------------------
// relações (o centro do módulo)
// ---------------------------------------------------------------------------

export function createRelacao(inep, relacao) {
  return apiClient.post(BASE(inep), relacao);
}

export function updateRelacao(inep, id, relacao) {
  return apiClient.put(`${BASE(inep)}/${id}`, relacao);
}

export function deleteRelacao(inep, id) {
  return apiClient.delete(`${BASE(inep)}/${id}`);
}
