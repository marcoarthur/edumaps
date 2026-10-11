// src/features/admin/mocks/telemetryHandlers.js
// MSW handlers do Painel de Administração (base /api/admin/telemetry).
import { http, HttpResponse } from "msw";
import { buildOverview } from "./telemetryFixtures.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";

const BASE = "/api/admin/telemetry";
const WINDOWS = new Set(["6h", "12h", "24h", "hoje", "7d", "30d"]);

function authed(request) {
  return (request.headers.get("Authorization") ?? "") === `Bearer ${SESSION_TOKEN}`;
}

export const telemetryHandlers = [
  http.get(`${BASE}/overview`, ({ request }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const janela = new URL(request.url).searchParams.get("window") ?? "24h";
    if (!WINDOWS.has(janela)) {
      return HttpResponse.json({ error: `Janela inválida: '${janela}'.` }, { status: 400 });
    }
    return HttpResponse.json(buildOverview(janela));
  }),
];
