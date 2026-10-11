// src/features/gestor/mocks/canaisHandlers.js
// MSW handlers do módulo Listas & QR (issue #208, Fase 0).
//
// Cobre as duas faces do contrato congelado:
//   - gestão  /api/gestor/:cod_inep/canais/listas  (Bearer SESSION_TOKEN + posse)
//   - público /api/canais/inscricao/:token         (sem auth; capability = token)
//
// O estado é em memória por escola para as páginas criarem/rotacionarem QR sem
// recarregar. `resetCanaisMockState()` volta tudo ao fixture inicial (chamar no
// `beforeEach` de quem muta estado).
import { http, HttpResponse } from "msw";
import {
  CANAIS_ESCOLA_NOME,
  INEP_CANAIS,
  INSCRICAO_PUBLICA_FORM,
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_REVOGADO,
  INSCRICAO_TOKEN_VALIDO,
  LISTAS_CANAIS_FIXTURE,
  MEMBROS_CANAIS_FIXTURE,
  QRCODE_CANAIS_FIXTURE,
} from "./canaisFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/canais/listas";
const PUBLICO = "/api/canais/inscricao/:token";

// Origem pública (no dev a SPA roda em 5173). O backend real monta a URL a
// partir de $PUBLIC_BASE_URL.
const PUBLIC_BASE = "http://localhost:5173";
const publicUrl = (token) => `${PUBLIC_BASE}/inscricao/${token}`;

// ---------------------------------------------------------------------------
// estado em memória
// ---------------------------------------------------------------------------

const mem = new Map(); // inep -> { listas, membros: {listaId: [...]}, proximos }
const tokens = new Map(); // token -> { lista_id, cod_inep, usos, max_usos, status }

function baseState() {
  const listas = LISTAS_CANAIS_FIXTURE.map((l) => ({ ...l }));
  const membros = {};
  for (const [id, rows] of Object.entries(MEMBROS_CANAIS_FIXTURE)) {
    membros[id] = rows.map((m) => ({ ...m }));
  }
  return { listas, membros, proximos: { lista: 100, membro: 1000, contato: 2000 } };
}

function estadoFor(inep) {
  if (!mem.has(inep)) mem.set(inep, baseState());
  return mem.get(inep);
}

function semearTokens() {
  tokens.clear();
  const expiraPassado = "2026-10-01T00:00:00";
  tokens.set(INSCRICAO_TOKEN_VALIDO, {
    lista_id: 1,
    cod_inep: INEP_CANAIS,
    usos: 0,
    max_usos: null,
    expira_em: null,
    status: "ativo",
  });
  tokens.set(INSCRICAO_TOKEN_EXPIRADO, {
    lista_id: 1,
    cod_inep: INEP_CANAIS,
    usos: 0,
    max_usos: null,
    expira_em: expiraPassado,
    status: "expirado",
  });
  tokens.set(INSCRICAO_TOKEN_REVOGADO, {
    lista_id: 1,
    cod_inep: INEP_CANAIS,
    usos: 0,
    max_usos: null,
    expira_em: null,
    status: "revogado",
  });
  tokens.set(INSCRICAO_TOKEN_LIMITE, {
    lista_id: 1,
    cod_inep: INEP_CANAIS,
    usos: 0,
    max_usos: 1,
    expira_em: null,
    status: "ativo",
  });
}

/** Volta o mock ao estado inicial dos fixtures. */
export function resetCanaisMockState() {
  mem.clear();
  semearTokens();
}
resetCanaisMockState();

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function negarAuth(request) {
  const auth = request.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
  }
  return null;
}

function negarPosse(params) {
  if (params.cod_inep !== INEP_CANAIS) {
    return HttpResponse.json({ error: "Escola fora do seu acesso." }, { status: 403 });
  }
  return null;
}

const normalizar = (bruto) => String(bruto ?? "").replace(/\D/g, "");

function listaDe(inep, id) {
  return estadoFor(inep).listas.find((l) => l.id === Number(id));
}

function resolverToken(token) {
  return tokens.get(token) ?? null;
}

function tokenIndisponivel(entry) {
  if (!entry) return HttpResponse.json({ error: "Link inválido ou expirado." }, { status: 404 });
  const expirou =
    entry.status !== "ativo" ||
    (entry.expira_em && new Date(entry.expira_em).getTime() < Date.now());
  if (expirou) {
    return HttpResponse.json({ error: "Link expirado ou revogado." }, { status: 410 });
  }
  return null;
}

// ---------------------------------------------------------------------------
// handlers
// ---------------------------------------------------------------------------

export const gestorCanaisHandlers = [
  // ------------------------------ gestão -----------------------------------
  http.get(BASE, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    return HttpResponse.json(estadoFor(params.cod_inep).listas);
  }),

  http.post(BASE, async ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const body = await request.json();
    const nome = String(body.nome ?? "").trim();
    if (!nome) {
      return HttpResponse.json({ error: "Informe o nome da lista." }, { status: 400 });
    }
    const estab = estadoFor(params.cod_inep);
    const repetida = estab.listas.some(
      (l) => l.nome.trim().toLowerCase() === nome.toLowerCase(),
    );
    if (repetida) {
      return HttpResponse.json({ error: "Já existe uma lista com esse nome." }, { status: 409 });
    }
    const criada = {
      id: estab.proximos.lista++,
      cod_inep: Number(params.cod_inep),
      nome,
      canal: "telefone",
      descricao: body.descricao ?? null,
      ativo: true,
      n_membros: 0,
      qrcode: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    estab.listas.push(criada);
    estab.membros[criada.id] = [];
    return HttpResponse.json(criada, { status: 201 });
  }),

  http.get(`${BASE}/:id`, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (!lista) {
      return HttpResponse.json({ error: "Lista não encontrada" }, { status: 404 });
    }
    return HttpResponse.json({ ...lista, n_membros: estadoFor(params.cod_inep).membros[lista.id]?.length ?? 0 });
  }),

  http.delete(`${BASE}/:id`, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const estab = estadoFor(params.cod_inep);
    const idx = estab.listas.findIndex((l) => l.id === Number(params.id));
    if (idx !== -1) {
      const [removida] = estab.listas.splice(idx, 1);
      delete estab.membros[removida.id];
      for (const [token, entry] of tokens) {
        if (entry.lista_id === removida.id) tokens.delete(token);
      }
    }
    return new HttpResponse(null, { status: 204 });
  }),

  // rotaciona: revoga o QR ativo e cria outro
  http.post(`${BASE}/:id/qrcode`, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (!lista) {
      return HttpResponse.json({ error: "Lista não encontrada" }, { status: 404 });
    }
    for (const [token, entry] of tokens) {
      if (entry.lista_id === lista.id && entry.status === "ativo") {
        entry.status = "revogado";
        tokens.delete(token);
      }
    }
    const token = crypto.randomUUID();
    const entry = {
      lista_id: lista.id,
      cod_inep: lista.cod_inep,
      usos: 0,
      max_usos: null,
      expira_em: null,
      status: "ativo",
    };
    tokens.set(token, entry);
    const qrcode = {
      token,
      url: publicUrl(token),
      expira_em: null,
      usos: 0,
      max_usos: null,
      status: "ativo",
    };
    lista.qrcode = qrcode;
    return HttpResponse.json(qrcode, { status: 201 });
  }),

  http.delete(`${BASE}/:id/qrcode`, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (lista) {
      for (const [token, entry] of tokens) {
        if (entry.lista_id === lista.id) {
          entry.status = "revogado";
          tokens.delete(token);
        }
      }
      lista.qrcode = null;
    }
    return new HttpResponse(null, { status: 204 });
  }),

  http.get(`${BASE}/:id/inscricoes`, ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (!lista) {
      return HttpResponse.json({ error: "Lista não encontrada" }, { status: 404 });
    }
    return HttpResponse.json(estadoFor(params.cod_inep).membros[lista.id] ?? []);
  }),

  // ------------------------------ público ----------------------------------
  http.get(PUBLICO, ({ params }) => {
    const entry = resolverToken(params.token);
    const indisponivel = tokenIndisponivel(entry);
    if (indisponivel) return indisponivel;
    const lista = listaDe(entry.cod_inep, entry.lista_id);
    return HttpResponse.json({
      ...INSCRICAO_PUBLICA_FORM,
      lista_nome: lista?.nome ?? INSCRICAO_PUBLICA_FORM.lista_nome,
      escola_nome: CANAIS_ESCOLA_NOME,
      expira_em: entry.expira_em ?? null,
    });
  }),

  http.post(PUBLICO, async ({ request, params }) => {
    const entry = resolverToken(params.token);
    const indisponivel = tokenIndisponivel(entry);
    if (indisponivel) return indisponivel;

    if (entry.max_usos != null && entry.usos >= entry.max_usos) {
      return HttpResponse.json(
        { error: "Muitas inscrições por este link. Tente mais tarde." },
        { status: 429 },
      );
    }

    const body = await request.json();
    // honeypot: campo escondido preenchido = bot; responde 201 sem gravar
    if (body._hp) {
      return HttpResponse.json({ ok: 1 }, { status: 201 });
    }
    const nome = String(body.nome ?? "").trim();
    const telefone = String(body.telefone ?? "").trim();
    if (!nome || nome.length > 120 || !telefone || normalizar(telefone).length < 8) {
      return HttpResponse.json({ error: "Informe nome e telefone válidos." }, { status: 400 });
    }
    if (body.consentimento !== true) {
      return HttpResponse.json(
        { error: "É necessário consentir com o uso dos dados." },
        { status: 400 },
      );
    }

    const estab = estadoFor(entry.cod_inep);
    const membros = estab.membros[entry.lista_id] ?? (estab.membros[entry.lista_id] = []);
    const norm = normalizar(telefone);
    const existente = membros.find((m) => normalizar(m.telefone) === norm);

    entry.usos += 1;

    if (existente) {
      return HttpResponse.json({ ok: 1, duplicado: 1 }, { status: 201 });
    }

    membros.push({
      id: estab.proximos.membro++,
      contato_id: estab.proximos.contato++,
      nome,
      telefone,
      quando: new Date().toISOString(),
      validado: false,
      conflito: false,
      origem: "qrcode",
    });
    const lista = listaDe(entry.cod_inep, entry.lista_id);
    if (lista) lista.n_membros = membros.length;
    return HttpResponse.json({ ok: 1 }, { status: 201 });
  }),
];

export { PUBLIC_BASE };
