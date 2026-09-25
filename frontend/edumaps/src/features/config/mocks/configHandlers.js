// src/features/config/mocks/configHandlers.js
// MSW handlers do Painel de Configuração (base /api/admin/config).
import { http, HttpResponse } from "msw";
import { CONFIG_TREE, CONFIG_KEY_API, CONFIG_SAVED_ITEM } from "./configFixtures.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";

const BASE = "/api/admin/config";

let saved = false;

function authed(request) {
  const auth = request.headers.get("Authorization") ?? "";
  return auth === `Bearer ${SESSION_TOKEN}`;
}

export const resetConfigMockState = () => {
  saved = false;
};

export const configHandlers = [
  // árvore (exige sessão admin)
  http.get(`${BASE}/tree`, ({ request }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const tree = JSON.parse(JSON.stringify(CONFIG_TREE));
    tree.categories[1].children[0].children[0].value = { set: saved ? 1 : 0 };
    return HttpResponse.json(tree);
  }),

  http.get(`${BASE}/:key`, ({ request, params }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const key = decodeURIComponent(params.key);
    if (key !== CONFIG_KEY_API) {
      return HttpResponse.json({ error: "Chave de configuração não encontrada." }, { status: 404 });
    }
    return HttpResponse.json(saved ? CONFIG_SAVED_ITEM : { ...CONFIG_SAVED_ITEM, value: { set: 0 } });
  }),

  http.put(`${BASE}/:key`, async ({ request, params }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const key = decodeURIComponent(params.key);
    const body = await request.json();
    if (key !== CONFIG_KEY_API) {
      return HttpResponse.json({ error: "Chave de configuração não encontrada." }, { status: 404 });
    }
    if (typeof body.value !== "string" || body.value.length < 8) {
      return HttpResponse.json({ error: "A chave não pode ser vazia." }, { status: 400 });
    }
    saved = true;
    return HttpResponse.json(CONFIG_SAVED_ITEM);
  }),

  http.post(`${BASE}/:key/validate`, async ({ request, params }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const body = await request.json();
    if (typeof body.value !== "string" || body.value.length < 8) {
      return HttpResponse.json({ error: "A chave não pode ser vazia." }, { status: 400 });
    }
    return HttpResponse.json({ ok: 1, value: "[validada]" });
  }),
];