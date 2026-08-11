// autocompleteApi.js
//
// Funções de busca de sugestão passadas como `fetchSuggestions` para
// InputAutocomplete. Mantidas na feature (não em shared/ui) porque cada
// uma sabe o endpoint e o formato de resposta específicos de escola/
// município — o componente genérico não sabe nada sobre isso.
//
// ATENÇÃO: os endpoints e o formato de resposta abaixo são um CHUTE
// razoável (mesmo padrão de /api/escola/... já usado no restante da
// feature) — ajuste pra bater com o contrato real do backend antes de
// usar em produção.
import { apiClient } from "@/shared/api/client.js";

/**
 * @param {string} query
 * @returns {Promise<Array<{ id: number, nome: string, municipio?: string }>>}
 */
export async function fetchSchoolSuggestions(query) {
  return apiClient.get("/api/school/suggestions", { q: query });
}

/**
 * @param {string} query
 * @returns {Promise<Array<{ codigo_ibge: number, nome: string, uf: string }>>}
 */
export async function fetchMunicipioSuggestions(query) {
  return apiClient.get("/api/city/suggestions", { q: query });
}
