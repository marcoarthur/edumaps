// src/features/schools/api/schoolProfileApi.js
//
// Espelha EduMaps::Plugin::API::School#profile.
// GET /api/school/:cod_inep/profile — ponte do backend para o serviço
// analítico (edumapsr) que devolve o "Perfil da Escola" (issue #105):
// diagnóstico, posição relativa (município/rede/Brasil), benchmarking
// justo (cluster + peers) e sinais de atenção.
//
// Nenhum outro arquivo da feature chama fetch/apiClient diretamente —
// tudo passa por aqui, o que torna trivial mockar em testes (MSW).
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/school";

/**
 * Perfil analítico de uma escola.
 * @param {string|number} codInep Código INEP (8 dígitos).
 * @returns {Promise<{
 *   analysis: string,
 *   metrics: object,
 *   metadata: object,
 *   tables: {
 *     indicadores_comparados?: Array<object>|object,
 *     cluster_resumo?: Array<object>|object,
 *     peers?: Array<object>|object,
 *     flags?: Array<object>|object,
 *   },
 * }>}
 */
export function getSchoolProfile(codInep) {
  return apiClient.get(`${BASE}/${codInep}/profile`);
}
