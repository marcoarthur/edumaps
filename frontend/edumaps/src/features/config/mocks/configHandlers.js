// src/features/config/mocks/configHandlers.js
// MSW handlers do Painel de Configuração (base /api/admin/config).
import { http, HttpResponse } from "msw";
import {
  CONFIG_TREE,
  CONFIG_KEY_API,
  CONFIG_SAVED_ITEM,
  TELEGRAM_STATUS_POLLING,
  TELEGRAM_WEBHOOK_URL,
} from "./configFixtures.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";

const BASE = "/api/admin/config";
const TELEGRAM_BASE = "/api/admin/canais/telegram";

// Estado do bot público do Telegram (status + ações admin). Mutável pelos
// testes via setTelegramMockState / setTelegramMockErro.
const clone = (o) => JSON.parse(JSON.stringify(o));
let telegramState = clone(TELEGRAM_STATUS_POLLING);
// Erro forçado por ação: { webhook_post|webhook_delete|polling: {status, error} }
let telegramErros = {};
// Contador de GET status (para testar a recarga após as ações).
let telegramStatusChamadas = 0;

export const setTelegramMockState = (estado) => {
  telegramState = clone(estado);
};
export const getTelegramMockState = () => clone(telegramState);
export const setTelegramMockErro = (acao, erro) => {
  telegramErros[acao] = erro;
};
export const getTelegramStatusChamadas = () => telegramStatusChamadas;

let saved = false;
// Valores gravados das demais folhas habilitadas (canais.*), por chave.
let outrosState = {};

// Estado do Bot Telegram (espelha o PUT real por chave).
let botState = {
  "integrations.bot_telegram.token": null, // string quando salva
  "integrations.bot_telegram.chat_id": null,
  "integrations.bot_telegram.enabled": 0,
  "integrations.bot_telegram.allowed_actions": [],
};
const BOT_ACTIONS = CONFIG_TREE.categories[1].children[1].children[3].options;

function authed(request) {
  const auth = request.headers.get("Authorization") ?? "";
  return auth === `Bearer ${SESSION_TOKEN}`;
}

export const resetConfigMockState = () => {
  saved = false;
  outrosState = {};
  telegramState = clone(TELEGRAM_STATUS_POLLING);
  telegramErros = {};
  telegramStatusChamadas = 0;
  botState = {
    "integrations.bot_telegram.token": null,
    "integrations.bot_telegram.chat_id": null,
    "integrations.bot_telegram.enabled": 0,
    "integrations.bot_telegram.allowed_actions": [],
  };
};

function erroForcado(acao) {
  const e = telegramErros[acao];
  return e ? HttpResponse.json({ error: e.error }, { status: e.status }) : null;
}

const naoAutorizado = () => HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });

export const telegramHandlers = [
  http.get(`${TELEGRAM_BASE}/status`, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    telegramStatusChamadas += 1;
    return HttpResponse.json(telegramState);
  }),

  http.post(`${TELEGRAM_BASE}/webhook`, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    const forcado = erroForcado("webhook_post");
    if (forcado) return forcado;
    if (telegramState.recebimento !== "webhook") {
      return HttpResponse.json({ error: "O modo de recebimento não é webhook." }, { status: 409 });
    }
    telegramState.webhook = {
      ...(telegramState.webhook ?? {}),
      url: TELEGRAM_WEBHOOK_URL,
      pending_update_count: 0,
      last_error_message: null,
    };
    return HttpResponse.json({ ok: 1, url: TELEGRAM_WEBHOOK_URL });
  }),

  http.delete(`${TELEGRAM_BASE}/webhook`, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    const forcado = erroForcado("webhook_delete");
    if (forcado) return forcado;
    if (telegramState.webhook) telegramState.webhook.url = "";
    return HttpResponse.json({ ok: 1 });
  }),

  http.post(`${TELEGRAM_BASE}/polling`, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    const forcado = erroForcado("polling");
    if (forcado) return forcado;
    if (telegramState.recebimento !== "polling" || !telegramState.enabled) {
      return HttpResponse.json(
        { error: "O bot público está desligado ou o modo de recebimento não é polling." },
        { status: 409 },
      );
    }
    if (telegramState.polling?.ativo) return HttpResponse.json({ ok: 1, ja_ativo: 1 });
    telegramState.polling = { ...(telegramState.polling ?? {}), ativo: 1 };
    return HttpResponse.json({ ok: 1, job_id: 4242 }, { status: 202 });
  }),
];

export const configHandlers = [
  ...telegramHandlers,
  // árvore (exige sessão admin)
  http.get(`${BASE}/tree`, ({ request }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const tree = JSON.parse(JSON.stringify(CONFIG_TREE));
    tree.categories[1].children[0].children[0].value = { set: saved ? 1 : 0 };
    const [token, chatId, enabled, actions] = tree.categories[1].children[1].children;
    token.value = { set: botState["integrations.bot_telegram.token"] ? 1 : 0 };
    chatId.value = botState["integrations.bot_telegram.chat_id"];
    enabled.value = botState["integrations.bot_telegram.enabled"];
    actions.value = botState["integrations.bot_telegram.allowed_actions"];
    return HttpResponse.json(tree);
  }),

  http.get(`${BASE}/:key`, ({ request, params }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const key = decodeURIComponent(params.key);
    if (key === CONFIG_KEY_API) {
      return HttpResponse.json(saved ? CONFIG_SAVED_ITEM : { ...CONFIG_SAVED_ITEM, value: { set: 0 } });
    }
    const folha = acharFolha(key);
    if (!folha) {
      return HttpResponse.json({ error: "Chave de configuração não encontrada." }, { status: 404 });
    }
    const valor = key in botState ? botState[key] : outrosState[key];
    const value = folha.type === "secret"
      ? { set: valor ? 1 : 0 }
      : valor !== null && valor !== undefined
        ? valor
        : folha.value;
    return HttpResponse.json({ ...folha, value });
  }),

  http.put(`${BASE}/:key`, async ({ request, params }) => {
    if (!authed(request)) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    const key = decodeURIComponent(params.key);
    const body = await request.json();

    if (key in botState) {
      const err = validarBot(key, body.value);
      if (err) return HttpResponse.json({ error: err }, { status: 400 });
      botState[key] = body.value;
      const folha = acharFolha(key);
      const value = folha.type === "secret" ? { set: 1 } : body.value;
      return HttpResponse.json({ ...folha, value, updated_by: "admin@edu.gov.br" });
    }

    if (key !== CONFIG_KEY_API) {
      const folha = acharFolha(key);
      if (!folha || !folha.enabled) {
        return HttpResponse.json({ error: "Chave de configuração não encontrada." }, { status: 404 });
      }
      if (body.value === undefined || body.value === null || String(body.value).trim() === "") {
        return HttpResponse.json({ error: "O valor não pode ser vazio." }, { status: 400 });
      }
      outrosState[key] = body.value;
      const value = folha.type === "secret" ? { set: 1 } : body.value;
      return HttpResponse.json({ ...folha, value, updated_by: "admin@edu.gov.br" });
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
    const key = decodeURIComponent(params.key);
    const body = await request.json();

    if (key in botState) {
      const err = validarBot(key, body.value);
      if (err) return HttpResponse.json({ error: err }, { status: 400 });
      return HttpResponse.json({ ok: 1, value: body.value });
    }

    if (typeof body.value !== "string" || body.value.length < 8) {
      return HttpResponse.json({ error: "A chave não pode ser vazia." }, { status: 400 });
    }
    return HttpResponse.json({ ok: 1, value: "[validada]" });
  }),
];

// Localiza uma folha da árvore pela chave (spec do backend: config_item).
function acharFolha(key) {
  for (const cat of CONFIG_TREE.categories) {
    for (const grupo of cat.children) {
      for (const folha of grupo.children ?? (grupo.key === key ? [grupo] : [])) {
        if (folha.key === key) return folha;
      }
    }
  }
  return null;
}

// Validação espelhando o backend (AppConfig::config_validate por tipo).
function validarBot(key, value) {
  if (key.endsWith(".enabled")) {
    if (value !== "true" && value !== "false" && value !== true && value !== false && value !== 0 && value !== 1) {
      return 'O valor deve ser "true" ou "false".';
    }
    return null;
  }
  if (key.endsWith(".allowed_actions")) {
    if (!Array.isArray(value)) return "O valor deve ser uma lista de ações.";
    if (!value.length) return "A lista de ações não pode ser vazia.";
    if (value.some((a) => !BOT_ACTIONS.includes(a))) return "Ação desconhecida na lista.";
    if (new Set(value).size !== value.length) return "Ação duplicada na lista.";
    return null;
  }
  // token (secret) e chat_id (text)
  const min = key.endsWith(".token") ? 8 : 1;
  if (typeof value !== "string" || value.trim().length < min) {
    return key.endsWith(".token") ? "A chave não pode ser vazia." : "O valor não pode ser vazio.";
  }
  return null;
}