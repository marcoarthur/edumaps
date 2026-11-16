// src/features/base-analise/mocks/handlers.js
import { http, HttpResponse } from "msw";
import { BASE_ANALISE_FIXTURE } from "./fixtures.js";

export const baseAnaliseHandlers = [
  http.get("*/api/base-analise", ({ request }) => {
    const p = new URL(request.url).searchParams;
    const total = !p.get("uf") ? null : p.get("codigo_ibge") ? 41 : p.get("rede") === "municipal" ? 1200 : 3010;
    return HttpResponse.json({ ...BASE_ANALISE_FIXTURE, total });
  }),
];
