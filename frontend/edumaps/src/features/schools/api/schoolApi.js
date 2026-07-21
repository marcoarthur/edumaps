// src/features/schools/api/schoolApi.js
//
// Espelha EduMaps::Plugin::API::School / EduMaps::Controller::School.
// Nenhum outro arquivo da feature chama fetch/apiClient diretamente —
// tudo passa por aqui, o que torna trivial mockar em testes e trocar
// de endpoint sem tocar em componentes.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * @param {{ escola?: string, municipio?: string, limit?: number }} params
 * @returns {Promise<Array<object>>}
 */
export function searchSchools({ escola, municipio, limit } = {}) {
  return apiClient.get(`${BASE}/search`, { escola, municipio, limit });
}

export function getSchoolInfo(codInep) {
  return apiClient.get(`${BASE}/${codInep}/info`);
}
