// src/features/chat/mocks/chatHandlers.js
//
// MSW do Assistente do Censo (#224): POST /api/chat/ask e
// GET /api/chat/progress exigem a sessão do gestor (Bearer); sem ela, 401.
// O job termina na primeira consulta de progresso com o resultado configurado.
import { http, HttpResponse } from "msw";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";

export const CHAT_RESULTADO_FIXTURE = {
  cache_hit: 0,
  resposta: "Existem **1.588** escolas ativas no município.\n\n- 1.200 municipais\n- 388 estaduais",
  sql: "SELECT COUNT(*) FROM clean.censo_escolas WHERE co_municipio = 1100205",
  linhas: 2,
  colunas: 2,
  origem: ["clean.censo_escolas"],
  resultado: [
    { rede: "Municipal", total: 1200 },
    { rede: "Estadual", total: 388 },
  ],
  chart: {
    data: [{ x: ["Municipal", "Estadual"], y: [1200, 388], type: "bar" }],
    layout: {
      title: { text: "Escolas por rede", font: { size: 14 } },
      xaxis: { title: "rede" },
      yaxis: { title: "total" },
    },
  },
};

const estado = { resultado: CHAT_RESULTADO_FIXTURE, falha: null, ultimoAsk: null, proximoId: 1 };

export function resetChatMockState() {
  estado.resultado = CHAT_RESULTADO_FIXTURE;
  estado.falha = null;
  estado.ultimoAsk = null;
  estado.proximoId = 1;
}

/** Resultado do próximo job (o que o GET de progresso devolve ao terminar). */
export function setChatMockResultado(resultado) {
  estado.resultado = resultado;
}

/** Faz o próximo job falhar com a mensagem dada. */
export function setChatMockFalha(msg) {
  estado.falha = msg;
}

/** Corpo do último POST /api/chat/ask. */
export function getUltimoAsk() {
  return estado.ultimoAsk;
}

const naoAutorizado = (request) =>
  (request.headers.get("Authorization") ?? "") !== `Bearer ${SESSION_TOKEN}`;

const erro401 = () => HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });

export const chatHandlers = [
  http.post("/api/chat/ask", async ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    estado.ultimoAsk = await request.json();
    const jobId = estado.proximoId++;
    return HttpResponse.json(
      { task: "chat", job_id: jobId },
      { status: 202, headers: { Location: `/api/chat/progress?job_id=${jobId}` } },
    );
  }),

  http.get("/api/chat/progress", ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    if (estado.falha) return HttpResponse.json({ state: "failed", error: estado.falha });
    return HttpResponse.json({ state: "finished", result: estado.resultado });
  }),
];
