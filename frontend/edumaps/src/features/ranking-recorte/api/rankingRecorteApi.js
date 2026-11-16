// src/features/ranking-recorte/api/rankingRecorteApi.js
// Ranking por recorte (#430): escolas de um município e redes municipais.
import { apiClient } from "@/shared/api/client.js";

/** @param {{indicador: string, uf?: string, nacional?: boolean, minimo?: number, porte?: string}} p */
export function getRankingRedes({ indicador, uf, nacional, minimo, porte }) {
  return apiClient.get("/api/ranking/redes", {
    indicador,
    uf: nacional ? undefined : uf,
    nacional: nacional ? 1 : undefined,
    minimo: minimo && minimo !== 3 ? minimo : undefined,
    porte: porte || undefined,
  });
}

/** @param {{codigoIbge: string, indicador: string, rede?: string}} p */
export function getRankingEscolas({ codigoIbge, indicador, rede }) {
  return apiClient.get("/api/ranking/escolas", {
    codigo_ibge: codigoIbge,
    indicador,
    rede: rede || undefined,
  });
}
