// src/features/gestor/api/gestorPlanosApi.js
//
// Espelha EduMaps::Controller::GestorPlanos (#369, #370 — épico #368).
// Base /api/gestor/:cod_inep/planos — exige sessão do gestor (Bearer).
// PUT é PARCIAL: só os campos enviados mudam; null limpa o campo.

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/planos`;

/** @returns {Promise<{planos: Array}>} */
export function listPlanos(inep, { arquivados = false } = {}) {
  return apiClient.get(BASE(inep), arquivados ? { arquivados: 1 } : {});
}

/** Plano com objetivos → metas (progresso, medições) e ações, e o resumo. */
export function getPlano(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}`);
}

export function createPlano(inep, plano) {
  return apiClient.post(BASE(inep), plano);
}

export function updatePlano(inep, id, campos) {
  return apiClient.put(`${BASE(inep)}/${id}`, campos);
}

/** Arquiva (não apaga). */
export function arquivarPlano(inep, id) {
  return apiClient.delete(`${BASE(inep)}/${id}`);
}

export function getAuditoria(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}/auditoria`);
}

/** Catálogo de indicadores oficiais com o último valor da escola (ou null). */
export function getIndicadores(inep) {
  return apiClient.get(`${BASE(inep)}/indicadores`);
}

const filho = (rota) => ({
  create: (inep, planoId, dados) => apiClient.post(`${BASE(inep)}/${planoId}/${rota}`, dados),
  update: (inep, planoId, id, campos) => apiClient.put(`${BASE(inep)}/${planoId}/${rota}/${id}`, campos),
  remove: (inep, planoId, id) => apiClient.delete(`${BASE(inep)}/${planoId}/${rota}/${id}`),
});

export const objetivos = filho("objetivos");
export const metas = filho("metas");
export const acoes = filho("acoes");

export function createMedicao(inep, planoId, metaId, { data_ref, valor, nota = null }) {
  return apiClient.post(`${BASE(inep)}/${planoId}/metas/${metaId}/medicoes`, { data_ref, valor, nota });
}

export function deleteMedicao(inep, planoId, metaId, medicaoId) {
  return apiClient.delete(`${BASE(inep)}/${planoId}/metas/${metaId}/medicoes/${medicaoId}`);
}
