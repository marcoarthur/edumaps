// src/features/cluster-geotag/api/clusterApi.js
//
// Espelha EduMaps::Plugin::API::Cluster + POST /api/task/cluster.
// Todo fetch passa por aqui (padrão das demais features) para permitir
// mock simples nos testes.
import { apiClient } from "@/shared/api/client.js";

/**
 * Regiões disponíveis para a cascata de geotag.
 * @returns {Promise<Array<{ co_regiao: number, no_regiao: string }>>}
 */
export function getRegions() {
  return apiClient.get("/api/cluster/regions");
}

/**
 * UFs de uma região (ou todas sem o filtro).
 * @param {number|string} [codigoRegiao]
 * @returns {Promise<Array<{ co_uf: number, sg_uf: string, no_uf: string }>>}
 */
export function getUfs(codigoRegiao) {
  return apiClient.get("/api/cluster/ufs", { codigo_regiao: codigoRegiao });
}

/**
 * Municípios de uma UF (ou todos sem o filtro).
 * @param {number|string} [codigoUf]
 * @returns {Promise<Array<{ co_municipio: number, no_municipio: string }>>}
 */
export function getMunicipalities(codigoUf) {
  return apiClient.get("/api/cluster/municipalities", { codigo_uf: codigoUf });
}

/**
 * Enfileira o job de clusterização do recorte atual.
 * @param {Object} payload - { table_name, id_column, schema, algorithm,
 *   clusters, eps, min_pts, features, codigo_regiao, codigo_uf, codigo_ibge }
 * @returns {Promise<{ task: string, job_id: number }>}
 */
export function requestCluster(payload) {
  return apiClient.post("/api/task/cluster", payload);
}

/**
 * Polling de progresso do job.
 * @param {string|number} jobId
 * @returns {Promise<{ state: string, ... }>}
 */
export function getJobProgress(jobId) {
  return apiClient.get("/api/task/progress", { job_id: jobId });
}

/**
 * GeoJSON das escolas clusterizadas do recorte.
 * @param {Object} geotag - { codigo_regiao, codigo_uf, codigo_ibge }
 * @returns {Promise<{ type: string, features: Array<object> }>}
 */
export function getClusterSchools(geotag) {
  return apiClient.get("/api/cluster/schools", geotag);
}