// src/features/base-analise/api/baseAnaliseApi.js
// Base de análise (#439): catálogo, total do recorte e os links de download.
import { apiClient } from "@/shared/api/client.js";

function params({ uf, codigoIbge, rede, blocos, anoIdeb, anoSiope }) {
  const p = new URLSearchParams();
  if (uf) p.set("uf", uf);
  if (codigoIbge) p.set("codigo_ibge", codigoIbge);
  if (rede) p.set("rede", rede);
  if (blocos?.length) p.set("blocos", blocos.join(","));
  if (anoIdeb && blocos?.includes("desempenho")) p.set("ano_ideb", String(anoIdeb));
  if (anoSiope && blocos?.includes("remuneracao")) p.set("ano_siope", String(anoSiope)); // #491
  return p;
}

/** Catálogo dos blocos, anos das bases e, com UF, o total de escolas do recorte. */
export function getBaseAnalise({ uf, codigoIbge, rede } = {}) {
  return apiClient.get("/api/base-analise", {
    uf: uf || undefined,
    codigo_ibge: codigoIbge || undefined,
    rede: rede || undefined,
  });
}

/** URL do CSV da base (o servidor dá o nome do arquivo, com a versão dos dados). */
export function baseCsvUrl(filtros) {
  return `/api/base-analise/csv?${params(filtros)}`;
}

/** URL do dicionário das colunas dos blocos escolhidos. */
export function dicionarioUrl({ blocos, anoIdeb, anoSiope }) {
  return `/api/base-analise/dicionario?${params({ blocos, anoIdeb, anoSiope })}`;
}
