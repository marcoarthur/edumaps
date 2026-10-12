// src/features/config/mocks/configHandlers.js
// MSW handlers do Painel de Configuração (base /api/admin/config).
import { http, HttpResponse } from "msw";
import {
  CONFIG_TREE,
  CONFIG_KEY_API,
  CONFIG_SAVED_ITEM,
  TELEGRAM_STATUS_POLLING,
  TELEGRAM_WEBHOOK_URL,
  RETENCAO_STATUS,
  RETENCAO_JOB_ID,
  CONSENTIMENTO_VERSOES,
  ENVIOS_ADMIN,
} from "./configFixtures.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { setConsentimentoVigenteMock } from "@/features/gestor/mocks/canaisHandlers.js";

const BASE = "/api/admin/config";
const TELEGRAM_BASE = "/api/admin/canais/telegram";
const RETENCAO_BASE = "/api/admin/canais/retencao";
const CONSENTIMENTO_BASE = "/api/admin/consentimento/versoes";
const ENVIOS_BASE = "/api/admin/canais/envios";

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

// Retenção (issue #214): status + execução avulsa. Os prazos refletem as
// folhas canais.retencao.* gravadas no PUT (outrosState).
let retencaoState = clone(RETENCAO_STATUS);
let retencaoErro = null; // { status, error } forçado no POST executar
let retencaoStatusChamadas = 0;
export const setRetencaoMockState = (estado) => {
  retencaoState = clone(estado);
};
export const setRetencaoMockErro = (erro) => {
  retencaoErro = erro;
};
export const getRetencaoStatusChamadas = () => retencaoStatusChamadas;

// Envios por e-mail (issue #216, onda 2): volume por escola + suspensões.
// Os limites refletem as folhas canais.envio.* gravadas no PUT (outrosState).
let enviosAdminState = clone(ENVIOS_ADMIN);
let enviosAdminChamadas = 0;
let proximaSuspensaoId = 100;
export const setEnviosAdminMockState = (estado) => {
  enviosAdminState = clone(estado);
};
export const getEnviosAdminMockState = () => clone(enviosAdminState);
export const getEnviosAdminChamadas = () => enviosAdminChamadas;

// Versões do consentimento (issue #214): rascunho → vigente → arquivada.
let versoesState = clone(CONSENTIMENTO_VERSOES);
let proximaVersaoId = 100;
export const getConsentimentoVersoesMock = () => clone(versoesState);

// hash fictício (o backend usa sha256 do texto)
function hashFicticio(texto) {
  let h = 0;
  for (const ch of String(texto)) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return h.toString(16).padStart(8, "0").repeat(8);
}

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
  retencaoState = clone(RETENCAO_STATUS);
  retencaoErro = null;
  retencaoStatusChamadas = 0;
  versoesState = clone(CONSENTIMENTO_VERSOES);
  proximaVersaoId = 100;
  enviosAdminState = clone(ENVIOS_ADMIN);
  enviosAdminChamadas = 0;
  proximaSuspensaoId = 100;
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

const RETENCAO_CHAVES = {
  enabled: "canais.retencao.enabled",
  metadados_dias: "canais.retencao.metadados_dias",
  pendentes_dias: "canais.retencao.pendentes_dias",
  listas_inativas_meses: "canais.retencao.listas_inativas_meses",
};

export const retencaoHandlers = [
  http.get(RETENCAO_BASE, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    retencaoStatusChamadas += 1;
    const status = clone(retencaoState);
    for (const [campo, chave] of Object.entries(RETENCAO_CHAVES)) {
      if (outrosState[chave] === undefined) continue;
      const v = outrosState[chave];
      status[campo] = campo === "enabled" ? (v === true || v === 1 || v === "true" ? 1 : 0) : Number(v);
    }
    return HttpResponse.json(status);
  }),

  http.post(`${RETENCAO_BASE}/executar`, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    if (retencaoErro) return HttpResponse.json({ error: retencaoErro.error }, { status: retencaoErro.status });
    // execução "instantânea" no mock: nada além dos prazos → contagens zero
    retencaoState.ultima_execucao = {
      em: new Date().toISOString(),
      metadados: 0,
      pendentes: 0,
      listas_inativas: 0,
    };
    return HttpResponse.json({ ok: 1, job_id: RETENCAO_JOB_ID }, { status: 202 });
  }),
];

const ENVIO_CHAVES = {
  enabled: "canais.envio.enabled",
  ritmo_por_minuto: "canais.envio.ritmo_por_minuto",
  cota_diaria: "canais.envio.cota_diaria_escola",
  max_destinatarios: "canais.envio.max_destinatarios",
};

export const enviosAdminHandlers = [
  http.get(ENVIOS_BASE, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    enviosAdminChamadas += 1;
    const res = clone(enviosAdminState);
    for (const [campo, chave] of Object.entries(ENVIO_CHAVES)) {
      if (outrosState[chave] === undefined) continue;
      const v = outrosState[chave];
      res.limites[campo] = campo === "enabled" ? (v === true || v === 1 || v === "true" ? 1 : 0) : Number(v);
    }
    res.escolas.sort((a, b) => b.enviados_30d - a.enviados_30d);
    return HttpResponse.json(res);
  }),

  http.post(`${ENVIOS_BASE}/suspensoes`, async ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    const body = await request.json().catch(() => ({}));
    const motivo = String(body.motivo ?? "").trim();
    const cod = Number(body.cod_inep);
    if (!Number.isInteger(cod) || cod <= 0) {
      return HttpResponse.json({ error: "cod_inep inválido." }, { status: 400 });
    }
    if (motivo.length < 1 || motivo.length > 500) {
      return HttpResponse.json({ error: "Informe o motivo (até 500 caracteres)." }, { status: 400 });
    }
    let escola = enviosAdminState.escolas.find((e) => e.cod_inep === cod);
    if (escola?.suspensao) {
      return HttpResponse.json({ error: "A escola já está suspensa." }, { status: 409 });
    }
    const suspensao = {
      id: proximaSuspensaoId++,
      motivo,
      suspenso_em: new Date().toISOString(),
      suspenso_por: 1,
    };
    if (!escola) {
      escola = {
        cod_inep: cod,
        escola_nome: `Escola ${cod}`,
        enviados_hoje: 0,
        enviados_30d: 0,
        falhas_30d: 0,
        optouts_30d: 0,
        envios_em_curso: 0,
        suspensao: null,
      };
      enviosAdminState.escolas.push(escola);
    }
    escola.suspensao = suspensao;
    return HttpResponse.json({ suspensao }, { status: 201 });
  }),

  http.post(`${ENVIOS_BASE}/suspensoes/:cod_inep/reativar`, ({ request, params }) => {
    if (!authed(request)) return naoAutorizado();
    const escola = enviosAdminState.escolas.find((e) => e.cod_inep === Number(params.cod_inep));
    if (!escola?.suspensao) {
      return HttpResponse.json({ error: "A escola não tem suspensão ativa." }, { status: 404 });
    }
    escola.suspensao = null;
    return HttpResponse.json({ ok: 1, envios_retomados: escola.envios_em_curso });
  }),
];

const versaoNaoEncontrada = () =>
  HttpResponse.json({ error: "Versão não encontrada." }, { status: 404 });

export const consentimentoAdminHandlers = [
  http.get(CONSENTIMENTO_BASE, ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    return HttpResponse.json(clone(versoesState));
  }),

  http.post(CONSENTIMENTO_BASE, async ({ request }) => {
    if (!authed(request)) return naoAutorizado();
    const body = await request.json().catch(() => ({}));
    const versao = String(body.versao ?? "").trim();
    const texto = String(body.texto ?? "").trim();
    if (!versao || !texto) {
      return HttpResponse.json({ error: "Informe a versão e o texto." }, { status: 400 });
    }
    if (versoesState.some((v) => v.versao === versao)) {
      return HttpResponse.json({ error: `A versão ${versao} já existe.` }, { status: 409 });
    }
    const nova = {
      id: proximaVersaoId++,
      versao,
      texto,
      texto_hash: hashFicticio(texto),
      status: "rascunho",
      publicada_em: null,
      created_at: new Date().toISOString(),
    };
    versoesState.push(nova);
    return HttpResponse.json(nova, { status: 201 });
  }),

  http.put(`${CONSENTIMENTO_BASE}/:id`, async ({ request, params }) => {
    if (!authed(request)) return naoAutorizado();
    const v = versoesState.find((x) => x.id === Number(params.id));
    if (!v) return versaoNaoEncontrada();
    if (v.status !== "rascunho") {
      return HttpResponse.json(
        { error: "Só rascunhos podem ser editados; versões publicadas são imutáveis." },
        { status: 409 },
      );
    }
    const body = await request.json().catch(() => ({}));
    if (body.versao !== undefined) {
      const versao = String(body.versao ?? "").trim();
      if (!versao) return HttpResponse.json({ error: "Informe a versão." }, { status: 400 });
      if (versoesState.some((x) => x.id !== v.id && x.versao === versao)) {
        return HttpResponse.json({ error: `A versão ${versao} já existe.` }, { status: 409 });
      }
      v.versao = versao;
    }
    if (body.texto !== undefined) {
      const texto = String(body.texto ?? "").trim();
      if (!texto) return HttpResponse.json({ error: "Informe o texto." }, { status: 400 });
      v.texto = texto;
      v.texto_hash = hashFicticio(texto);
    }
    return HttpResponse.json(clone(v));
  }),

  http.post(`${CONSENTIMENTO_BASE}/:id/publicar`, ({ request, params }) => {
    if (!authed(request)) return naoAutorizado();
    const v = versoesState.find((x) => x.id === Number(params.id));
    if (!v) return versaoNaoEncontrada();
    if (v.status !== "rascunho") {
      return HttpResponse.json({ error: "Só rascunhos podem ser publicados." }, { status: 409 });
    }
    for (const x of versoesState) if (x.status === "vigente") x.status = "arquivada";
    v.status = "vigente";
    v.publicada_em = new Date().toISOString();
    setConsentimentoVigenteMock({ versao: v.versao, texto: v.texto, publicada_em: v.publicada_em });
    return HttpResponse.json(clone(v));
  }),
];

export const configHandlers = [
  ...telegramHandlers,
  ...retencaoHandlers,
  ...enviosAdminHandlers,
  ...consentimentoAdminHandlers,
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