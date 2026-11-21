// src/features/base-analise/mocks/handlers.js
import { http, HttpResponse } from "msw";
import { BASE_ANALISE_FIXTURE } from "./fixtures.js";

export const baseAnaliseHandlers = [
  http.get("*/api/base-analise", ({ request }) => {
    const p = new URL(request.url).searchParams;
    const total = !p.get("uf") ? null : p.get("codigo_ibge") ? 41 : p.get("rede") === "municipal" ? 1200 : 3010;
    // #512: SP com folha só em 2026 (Ubatuba); as demais UFs sem folha.
    const folha = !p.get("uf") ? null
      : p.get("uf") === "SP"
        ? { padrao: 2026, escolas: { 2026: 48 },
            municipios: [{ codigo_ibge: "3555406", municipio: "Ubatuba", uf: "SP", anos: [{ ano: 2026, meses: 8, escolas: 48 }] }] }
        : { padrao: null, escolas: {}, municipios: [] };
    return HttpResponse.json({ ...BASE_ANALISE_FIXTURE, total, folha });
  }),
];
