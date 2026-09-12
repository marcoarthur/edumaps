// src/features/network-compare/mocks/handlers.js
import { http, HttpResponse } from "msw";
import {
  FIXTURE_CODIGO_IBGE,
  MUNICIPIO_SUGGESTIONS_FIXTURE,
  NETWORK_MARKERS_FIXTURE,
  NETWORK_PERFORMANCE_FIXTURE,
  NETWORK_SUMMARY_FIXTURE,
} from "./fixtures.js";

function municipalityNotFound(codigoIbge) {
  return HttpResponse.json(
    { error: `Dados não encontrados para o município: ${codigoIbge}` },
    { status: 404 },
  );
}

export const networkCompareHandlers = [
  http.get(`/api/network/${FIXTURE_CODIGO_IBGE}/summary`, () => {
    return HttpResponse.json(NETWORK_SUMMARY_FIXTURE);
  }),

  http.get(`/api/network/${FIXTURE_CODIGO_IBGE}/performance`, () => {
    return HttpResponse.json(NETWORK_PERFORMANCE_FIXTURE);
  }),

  http.get(`/api/network/${FIXTURE_CODIGO_IBGE}/markers`, () => {
    return HttpResponse.json(NETWORK_MARKERS_FIXTURE);
  }),

  // Qualquer outro município retorna 404
  http.get("/api/network/:codigoIbge/summary", ({ params }) =>
    municipalityNotFound(params.codigoIbge),
  ),
  http.get("/api/network/:codigoIbge/performance", ({ params }) =>
    municipalityNotFound(params.codigoIbge),
  ),
  http.get("/api/network/:codigoIbge/markers", ({ params }) =>
    municipalityNotFound(params.codigoIbge),
  ),

  http.get("/api/city/suggestions", ({ request }) => {
    const url = new URL(request.url);
    const q = (url.searchParams.get("q") ?? "").toLowerCase();
    return HttpResponse.json(
      MUNICIPIO_SUGGESTIONS_FIXTURE.filter((city) =>
        city.nome.toLowerCase().includes(q),
      ),
    );
  }),
];