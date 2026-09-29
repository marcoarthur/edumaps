// src/features/schools/api/schoolEvolutionApi.js
//
// Espelha EduMaps::Plugin::API::School#evolution.
// GET /api/school/:cod_inep/evolution — série histórica da escola
// (IDEB por etapa e notas SAEB por ano), via serviço analítico.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * @param {string|number} codInep Código INEP (8 dígitos).
 * @returns {Promise<{ analysis: string, data: Array<object>|object,
 *   tables?: object, metrics?: object, metadata?: object }>}
 */
export function getSchoolEvolution(codInep) {
  return apiClient.get(`${BASE}/${codInep}/evolution`);
}
