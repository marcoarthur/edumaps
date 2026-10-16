// src/features/gestor/api/gestorApi.js
//
// Espelha EduMaps::Plugin::API::Gestor / EduMaps::Controller::Gestor.
// Toda chamada da feature passa por aqui (facilita mock e troca de endpoint).
import { apiClient } from "@/shared/api/client.js";

const BASE = "/api/gestor";

/**
 * Raio-x da escola para o gestor.
 * @param {string|number} codInep
 * @returns {Promise<object>} ver EduMaps::Roles::Business::Gestor::Overview
 */
export function getGestorPanel(codInep) {
  return apiClient.get(`${BASE}/${codInep}/painel`);
}

/**
 * Busca de escolas similares (porte, localização, INSE e etapas) via pgvector.
 * @param {string|number} codInep
 * @param {{scope?: 'municipio'|'estado'|'regiao', limit?: number}} [opts]
 * @returns {Promise<{escola_alvo: object, scope: string, limit: number, similares: Array}>}
 */
export function getSchoolSimilares(codInep, { scope = "municipio", limit = 10 } = {}) {
  return apiClient.get(`${BASE}/${codInep}/similares`, { scope, limit });
}

/**
 * Dispara a busca de POIs (equipamentos públicos) no entorno da escola.
 * Idempotente no backend: se já houver job pendente para a escola, devolve o
 * mesmo job_id (reused=true).
 * @param {string|number} codInep
 * @param {{ raio?: number, profiles?: string[], refresh?: boolean }} [opts]
 * @returns {Promise<{task:string, job_id:number, reused:boolean}>}
 */
export function requestOsmPois(codInep, { raio, profiles, refresh } = {}) {
  return apiClient.post(`${BASE}/${codInep}/osm/pois`, { raio, profiles, refresh });
}

/**
 * Status dos POIs OSM da escola (seleção atual + resumo por categoria).
 * @param {string|number} codInep
 * @returns {Promise<{updated_at?:string, raio?:number, profiles?:string[],
 *   total:number, resumo:Array<{category:string,count:number}>, job_id?:number}>}
 */
export function getOsmPoisStatus(codInep) {
  return apiClient.get(`${BASE}/${codInep}/osm/pois`);
}

/**
 * Área de influência materializada da escola (metodologia `influencia-v1`,
 * #255/#137). Somente leitura: a camada é gerada pelo job de materialização;
 * a API devolve 404 quando ainda não foi calculada.
 * @param {string|number} codInep
 * @returns {Promise<{co_entidade:number, nu_ano_censo:number, tier:string,
 *   versao:string, computado_em:string, raios:number[], escola:object,
 *   geojson:{type:string, features:Array}}>}
 */
export function getInfluencia(codInep) {
  return apiClient.get(`${BASE}/${codInep}/influencia`);
}
