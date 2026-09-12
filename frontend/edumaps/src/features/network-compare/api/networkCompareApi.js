// src/features/network-compare/api/networkCompareApi.js
//
// Espelha EduMaps::Plugin::API::SchoolNetwork / EduMaps::Controller::SchoolNetwork.
// Nenhum outro arquivo da feature chama fetch/apiClient diretamente —
// tudo passa por aqui, o que torna trivial mockar em testes.
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/network";

/**
 * @param {string|number} codigoIbge
 * @returns {Promise<Array<object>>} Uma entrada por rede com os indicadores
 *   de analytics.mv_rede_escolas.
 */
export function getNetworkSummary(codigoIbge) {
  return apiClient.get(`${BASE}/${codigoIbge}/summary`);
}

/**
 * Série de IDEB/SAEB agregada por (ano, rede, etapa).
 * @param {string|number} codigoIbge
 * @returns {Promise<Array<{ rede: string, etapa: string, ano: number,
 *   numero_escolas: number, ideb_medio?: number, nota_matematica?: number,
 *   nota_portugues?: number, nota_media?: number, aprovacao_media?: number }>>}
 */
export function getNetworkPerformance(codigoIbge) {
  return apiClient.get(`${BASE}/${codigoIbge}/performance`);
}

/**
 * GeoJSON FeatureCollection das escolas do município.
 * @param {string|number} codigoIbge
 * @returns {Promise<{ type: string, features: Array<object> }>}
 */
export function getNetworkMarkers(codigoIbge) {
  return apiClient.get(`${BASE}/${codigoIbge}/markers`);
}

/**
 * @param {string} query
 * @returns {Promise<Array<{ codigo_ibge: number, nome: string, uf: string }>>}
 */
export function fetchMunicipioSuggestions(query) {
  return apiClient.get("/api/city/suggestions", { q: query });
}