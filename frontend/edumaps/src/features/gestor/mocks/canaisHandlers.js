// src/features/gestor/mocks/canaisHandlers.js
// MSW handlers do módulo Listas & QR (issue #208, Fase 0) + confirmação de
// posse do telefone (issue #212).
//
// Cobre as faces do contrato congelado:
//   - gestão  /api/gestor/:cod_inep/canais/listas  (Bearer SESSION_TOKEN + posse)
//   - público /api/canais/inscricao/:token         (sem auth; capability = token)
//   - público /api/canais/confirmacao/:ref[/whatsapp[/verificar]] (capability = ref)
//
// Helpers de teste: `ultimaRefConfirmacao()` devolve a última ref emitida e
// `confirmarRefMock(ref, via)` simula a confirmação fora da página (Telegram);
// `setCanaisConfirmacaoMock([...])` escolhe os canais disponíveis.
//
// O estado é em memória por escola para as páginas criarem/rotacionarem QR sem
// recarregar. `resetCanaisMockState()` volta tudo ao fixture inicial (chamar no
// `beforeEach` de quem muta estado).
import { http, HttpResponse } from "msw";
import {
  CANAIS_ESCOLA_NOME,
  INEP_CANAIS,
  INSCRICAO_PUBLICA_FORM,
  INSCRICAO_TOKEN_CONFIRMACAO,
  INSCRICAO_TOKEN_EXPIRADO,
  INSCRICAO_TOKEN_LIMITE,
  INSCRICAO_TOKEN_REVOGADO,
  INSCRICAO_TOKEN_VALIDO,
  LISTAS_CANAIS_FIXTURE,
  MEMBROS_CANAIS_FIXTURE,
  TELEGRAM_BOT_CONFIRMACAO,
  WHATSAPP_CODIGO_MOCK,
} from "./canaisFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/canais/listas";
const PUBLICO = "/api/canais/inscricao/:token";
const CONFIRMACAO = "/api/canais/confirmacao/:ref";

// Origem pública (no dev a SPA roda em 5173). O backend real monta a URL a
// partir de $PUBLIC_BASE_URL.
const PUBLIC_BASE = "http://localhost:5173";
const publicUrl = (token) => `${PUBLIC_BASE}/inscricao/${token}`;

// ---------------------------------------------------------------------------
// estado em memória
// ---------------------------------------------------------------------------

const mem = new Map(); // inep -> { listas, membros: {listaId: [...]}, proximos }
const tokens = new Map(); // token -> { lista_id, cod_inep, usos, max_usos, status }
// ref -> { cod_inep, lista_id, membro_id, expira_em, usada: bool, wa: {codigo, envios, tentativas} }
const refs = new Map();
let ultimaRef = null;
const CANAIS_PADRAO = ["telegram", "whatsapp"];
let canaisDisponiveis = [...CANAIS_PADRAO];

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
  tokens.set(INSCRICAO_TOKEN_CONFIRMACAO, {
    lista_id: 3,
    cod_inep: INEP_CANAIS,
    usos: 0,
    max_usos: null,
    expira_em: null,
    status: "ativo",
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
  refs.clear();
  ultimaRef = null;
  canaisDisponiveis = [...CANAIS_PADRAO];
}

/** Escolhe os canais de confirmação "configurados" (ordem: telegram, whatsapp). */
export function setCanaisConfirmacaoMock(canais) {
  canaisDisponiveis = CANAIS_PADRAO.filter((c) => canais.includes(c));
}

/** Última ref de confirmação emitida pelo POST de inscrição. */
export function ultimaRefConfirmacao() {
  return ultimaRef;
}

/** Simula a conclusão da confirmação fora da página (ex.: bot do Telegram). */
export function confirmarRefMock(ref, via = "telegram") {
  const entry = refs.get(ref);
  if (!entry) return false;
  concluirRef(entry, via);
  return true;
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

// estado derivado do membro (contrato #212)
function estadoMembro(lista, m) {
  if (m.confirmado_em) return "confirmado";
  return lista?.exige_confirmacao ? "pendente" : "nao_exigida";
}

function comEstado(lista, m) {
  return {
    ...m,
    estado: estadoMembro(lista, m),
    confirmado_via: m.confirmado_via ?? null,
    confirmado_em: m.confirmado_em ?? null,
  };
}

function comContadores(inep, lista) {
  const membros = estadoFor(inep).membros[lista.id] ?? [];
  const exige = Boolean(lista.exige_confirmacao);
  const confirmados = membros.filter((m) => m.confirmado_em).length;
  return {
    ...lista,
    exige_confirmacao: exige,
    n_membros: membros.length,
    membros_confirmados: confirmados,
    membros_pendentes: exige ? membros.length - confirmados : 0,
  };
}

const novaRef = () => crypto.randomUUID().replace(/-/g, "");

function canaisDaRef(ref) {
  return canaisDisponiveis.map((canal) =>
    canal === "telegram"
      ? { canal, url: `https://t.me/${TELEGRAM_BOT_CONFIRMACAO}?start=${ref}` }
      : { canal },
  );
}

function abrirRef(inep, listaId, membroId) {
  // reinscrição de pendente: a ref anterior é invalidada
  for (const [r, e] of refs) {
    if (e.membro_id === membroId && !e.usada) refs.delete(r);
  }
  const ref = novaRef();
  const expira_em = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  refs.set(ref, {
    cod_inep: inep,
    lista_id: listaId,
    membro_id: membroId,
    expira_em,
    usada: false,
    wa: { codigo: null, envios: 0, tentativas: 0 },
  });
  ultimaRef = ref;
  return { ref, estado: "pendente", expira_em, canais: canaisDaRef(ref) };
}

function concluirRef(entry, via) {
  entry.usada = true;
  const membro = (estadoFor(entry.cod_inep).membros[entry.lista_id] ?? []).find(
    (m) => m.id === entry.membro_id,
  );
  if (membro) {
    membro.confirmado_em = new Date().toISOString();
    membro.confirmado_via = via;
    membro.validado = true;
  }
}

const refNaoEncontrada = () =>
  HttpResponse.json({ error: "Confirmação não encontrada." }, { status: 404 });

function refValida(ref) {
  const entry = refs.get(ref);
  if (!entry || entry.usada || new Date(entry.expira_em).getTime() < Date.now()) return null;
  return entry;
}

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
    const inep = params.cod_inep;
    return HttpResponse.json(estadoFor(inep).listas.map((l) => comContadores(inep, l)));
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
      exige_confirmacao: body.exige_confirmacao === true,
      membros_confirmados: 0,
      membros_pendentes: 0,
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
    return HttpResponse.json(comContadores(params.cod_inep, lista));
  }),

  http.patch(`${BASE}/:id`, async ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (!lista) {
      return HttpResponse.json({ error: "Lista não encontrada" }, { status: 404 });
    }
    const body = await request.json().catch(() => ({}));
    const mudancas = {};
    if (body.nome !== undefined) {
      const nome = String(body.nome ?? "").trim();
      if (!nome) return HttpResponse.json({ error: "Informe o nome da lista." }, { status: 400 });
      const repetida = estadoFor(params.cod_inep).listas.some(
        (l) => l.id !== lista.id && l.nome.trim().toLowerCase() === nome.toLowerCase(),
      );
      if (repetida) {
        return HttpResponse.json({ error: "Já existe uma lista com esse nome." }, { status: 409 });
      }
      mudancas.nome = nome;
    }
    if (body.descricao !== undefined) mudancas.descricao = body.descricao || null;
    if (body.exige_confirmacao !== undefined) {
      if (typeof body.exige_confirmacao !== "boolean") {
        return HttpResponse.json({ error: "exige_confirmacao inválido." }, { status: 400 });
      }
      mudancas.exige_confirmacao = body.exige_confirmacao;
    }
    if (Object.keys(mudancas).length === 0) {
      return HttpResponse.json({ error: "Nada a alterar." }, { status: 400 });
    }
    Object.assign(lista, mudancas, { updated_at: new Date().toISOString() });
    return HttpResponse.json(comContadores(params.cod_inep, lista));
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
    const rows = estadoFor(params.cod_inep).membros[lista.id] ?? [];
    return HttpResponse.json(rows.map((m) => comEstado(lista, m)));
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
    const lista = listaDe(entry.cod_inep, entry.lista_id);
    const exige = Boolean(lista?.exige_confirmacao);

    if (existente) {
      if (!exige) return HttpResponse.json({ ok: 1, duplicado: 1 }, { status: 201 });
      const confirmacao = existente.confirmado_em
        ? { estado: "confirmado" }
        : abrirRef(entry.cod_inep, entry.lista_id, existente.id);
      return HttpResponse.json({ ok: 1, duplicado: 1, confirmacao }, { status: 201 });
    }

    const novo = {
      id: estab.proximos.membro++,
      contato_id: estab.proximos.contato++,
      nome,
      telefone,
      quando: new Date().toISOString(),
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
    };
    membros.push(novo);
    if (lista) lista.n_membros = membros.length;
    if (!exige) return HttpResponse.json({ ok: 1 }, { status: 201 });
    const confirmacao = abrirRef(entry.cod_inep, entry.lista_id, novo.id);
    return HttpResponse.json({ ok: 1, confirmacao }, { status: 201 });
  }),

  // --------------------- confirmação de posse (#212) -----------------------
  http.get(CONFIRMACAO, ({ params }) => {
    const entry = refs.get(params.ref);
    if (!entry || new Date(entry.expira_em).getTime() < Date.now()) return refNaoEncontrada();
    if (entry.usada) {
      return HttpResponse.json({ estado: "confirmado", canais: [], expira_em: entry.expira_em });
    }
    return HttpResponse.json({
      estado: "pendente",
      canais: canaisDaRef(params.ref),
      expira_em: entry.expira_em,
    });
  }),

  // onda 2 (mock): envia o código de 6 dígitos pelo WhatsApp
  http.post(`${CONFIRMACAO}/whatsapp`, ({ params }) => {
    const entry = refValida(params.ref);
    if (!entry) return refNaoEncontrada();
    if (!canaisDisponiveis.includes("whatsapp")) {
      return HttpResponse.json({ error: "Canal indisponível." }, { status: 409 });
    }
    if (entry.wa.envios >= 3) {
      return HttpResponse.json(
        { error: "Muitas tentativas. Aguarde para pedir outro código." },
        { status: 429 },
      );
    }
    entry.wa = { codigo: WHATSAPP_CODIGO_MOCK, envios: entry.wa.envios + 1, tentativas: 0 };
    const expira_em = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    return HttpResponse.json({ enviado: 1, expira_em }, { status: 202 });
  }),

  http.post(`${CONFIRMACAO}/whatsapp/verificar`, async ({ request, params }) => {
    const entry = refValida(params.ref);
    if (!entry || !entry.wa.codigo) {
      return HttpResponse.json({ error: "Código expirado." }, { status: 410 });
    }
    if (entry.wa.tentativas >= 5) {
      return HttpResponse.json({ error: "Tentativas excedidas." }, { status: 410 });
    }
    const body = await request.json().catch(() => ({}));
    if (String(body.codigo ?? "") !== entry.wa.codigo) {
      entry.wa.tentativas += 1;
      return HttpResponse.json({ error: "Código inválido." }, { status: 400 });
    }
    concluirRef(entry, "whatsapp");
    return HttpResponse.json({ estado: "confirmado" });
  }),
];

export { PUBLIC_BASE };
