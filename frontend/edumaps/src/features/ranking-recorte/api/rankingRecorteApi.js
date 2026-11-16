// src/features/ranking-recorte/api/rankingRecorteApi.js
// Ranking por recorte (#430): escolas de um município e redes municipais.
import { apiClient } from "@/shared/api/client.js";

/**
 * Recorte: `abrangencia` "uf" (com `uf`), "regiao" (com `regiao`, #445) ou
 * "brasil".
 * @param {{indicador: string, abrangencia?: string, uf?: string, regiao?: string, minimo?: number, porte?: string}} p
 */
export function getRankingRedes({ indicador, abrangencia = "uf", uf, regiao, minimo, porte }) {
  return apiClient.get("/api/ranking/redes", {
    indicador,
    uf: abrangencia === "uf" ? uf : undefined,
    regiao: abrangencia === "regiao" ? regiao : undefined,
    nacional: abrangencia === "brasil" ? 1 : undefined,
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
