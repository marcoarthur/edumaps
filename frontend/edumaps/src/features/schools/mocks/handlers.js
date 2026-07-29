// src/features/schools/mocks/handlers.js
import { http, HttpResponse } from "msw";
import {
  DEMO_SCHOOL_COD_INEP,
  INDICATORS_FIXTURE,
  RANKING_FIXTURES,
} from "./fixtures.js";

export const schoolsHandlers = [
  http.get(`/api/school/${DEMO_SCHOOL_COD_INEP}/indicators`, () => {
    return HttpResponse.json(INDICATORS_FIXTURE);
  }),

  http.get(`/api/school/${DEMO_SCHOOL_COD_INEP}/ranking`, ({ request }) => {
    const url = new URL(request.url);
    const indicador = url.searchParams.get("indicador");
    const rede = url.searchParams.get("rede");

    const meta = INDICATORS_FIXTURE.find((i) => i.id === indicador);
    if (meta && !meta.available) {
      return HttpResponse.json(
        {
          error: `Indicador "${meta.label}" não está disponível para esta escola.`,
        },
        { status: 404 },
      );
    }

    const data = RANKING_FIXTURES[indicador];
    if (!data) {
      return HttpResponse.json(
        { error: "Indicador não encontrado." },
        { status: 404 },
      );
    }

    // Simula filtro por rede (apenas para teste)
    const responseData = { ...data };
    if (rede) {
      responseData.rede = rede;
      // Ajustar posições/totais para simular filtro
      responseData.ranking.municipio = { posicao: 1, total: 10, percentil: 90 };
      responseData.ranking.estado = { posicao: 3, total: 50, percentil: 94 };
    }

    return HttpResponse.json(responseData);
  }),

  // Qualquer outra escola (fora da fixture) retorna 404
  http.get("/api/school/:codInep/ranking", () => {
    return HttpResponse.json(
      { error: "Escola não encontrada." },
      { status: 404 },
    );
  }),

  http.get("/api/school/:codInep/indicators", () => {
    return HttpResponse.json([]);
  }),
];
