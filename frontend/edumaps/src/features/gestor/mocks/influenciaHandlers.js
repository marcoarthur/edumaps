// src/features/gestor/mocks/influenciaHandlers.js
// MSW handler da área de influência no Painel do Gestor
// (/api/gestor/:codInep/influencia) — somente leitura.
import { http, HttpResponse } from "msw";
import { INFLUENCIA_STATUS_FIXTURE } from "./influenciaFixtures.js";

export const gestorInfluenciaHandlers = [
  http.get("/api/gestor/:codInep/influencia", () => {
    return HttpResponse.json(INFLUENCIA_STATUS_FIXTURE);
  }),
];
