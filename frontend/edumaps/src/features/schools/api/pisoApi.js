// src/features/schools/api/pisoApi.js
// #601 (QC-01 da P2): a lista do ano de quem fica abaixo do piso na rede
// municipal. Espelha GET /api/city/:codigo_ibge/piso (EduMaps::Controller::City).
import { apiClient } from "@/shared/api/client.js";

/** @param {string} codigoIbge 7 dígitos @param {number|string} [ano] */
export function getPisoLista(codigoIbge, ano) {
  return apiClient.get(`/api/city/${codigoIbge}/piso`, ano ? { ano } : {});
}

/** O endereço do CSV, para o link de download. */
export function urlPisoCsv(codigoIbge, ano) {
  return `/api/city/${encodeURIComponent(codigoIbge)}/piso?${ano ? `ano=${encodeURIComponent(ano)}&` : ""}formato=csv`;
}

/** O endereço da página da lista (#601), para os links do painel e da base. */
export function urlPisoPagina(codigoIbge, ano) {
  return `/municipio/piso?ibge=${encodeURIComponent(codigoIbge)}${ano ? `&ano=${encodeURIComponent(ano)}` : ""}`;
}
