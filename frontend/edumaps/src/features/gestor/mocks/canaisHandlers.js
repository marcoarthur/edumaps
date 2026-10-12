// src/features/gestor/mocks/canaisHandlers.js
// MSW handlers do módulo Listas & QR (issue #208, Fase 0) + confirmação de
// posse do telefone (issue #212) + e-mail e LGPD (issue #214, onda 1: `coleta`,
// confirmação por contato, canal e-mail, consentimento versionado,
// `exclusao_url`, QR com validade/limite).
//
// Cobre as faces do contrato congelado:
//   - gestão  /api/gestor/:cod_inep/canais/listas  (Bearer SESSION_TOKEN + posse)
//   - público /api/canais/inscricao/:token         (sem auth; capability = token)
//   - público /api/canais/confirmacao/:ref[/whatsapp|/email[/verificar]] (capability = ref)
//   - público /api/canais/consentimento             (texto vigente)
//
// Helpers de teste: `ultimaRefConfirmacao()` devolve a última ref emitida e
// `confirmarRefMock(ref, via)` simula a confirmação fora da página (Telegram);
// `setCanaisConfirmacaoMock([...])` escolhe os canais disponíveis;
// `setEmailDisponivelMock(bool)` liga/desliga o canal e-mail (SMTP configurado);
// `setConsentimentoVigenteMock({versao, texto})` publica outra versão.
//
// O estado é em memória por escola para as páginas criarem/rotacionarem QR sem
// recarregar. `resetCanaisMockState()` volta tudo ao fixture inicial (chamar no
// `beforeEach` de quem muta estado).
import { http, HttpResponse } from "msw";
import {
  CAMPOS_POR_COLETA,
  CANAIS_ESCOLA_NOME,
  COLETAS_VALIDAS,
  CONSENTIMENTO_VIGENTE,
  EMAIL_CODIGO_MOCK,
  INSCRICAO_TOKEN_AMBOS,
  INSCRICAO_TOKEN_EMAIL,
  INSCRICAO_TOKEN_QUALQUER,
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
const CONSENTIMENTO = "/api/canais/consentimento";

// Origem pública (no dev a SPA roda em 5173). O backend real monta a URL a
// partir de $PUBLIC_BASE_URL.
const PUBLIC_BASE = "http://localhost:5173";
const publicUrl = (token) => `${PUBLIC_BASE}/inscricao/${token}`;
const exclusaoUrl = () =>
  `${PUBLIC_BASE}/privacidade/exclusao/${crypto.randomUUID().replace(/-/g, "")}`;

// ---------------------------------------------------------------------------
// estado em memória
// ---------------------------------------------------------------------------

const mem = new Map(); // inep -> { listas, membros: {listaId: [...]}, proximos }
const tokens = new Map(); // token -> { lista_id, cod_inep, usos, max_usos, status }
// ref -> { cod_inep, lista_id, membro_id, expira_em, usada: bool,
//          wa: {codigo, envios, tentativas}, em: {codigo, envios, tentativas} }
const refs = new Map();
let ultimaRef = null;
const CANAIS_PADRAO = ["telegram", "whatsapp"];
let canaisDisponiveis = [...CANAIS_PADRAO];
let emailDisponivel = true;
let consentimentoVigente = { ...CONSENTIMENTO_VIGENTE };

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
  for (const [token, listaId] of [
    [INSCRICAO_TOKEN_AMBOS, 4],
    [INSCRICAO_TOKEN_QUALQUER, 5],
    [INSCRICAO_TOKEN_EMAIL, 6],
  ]) {
    tokens.set(token, {
      lista_id: listaId,
      cod_inep: INEP_CANAIS,
      usos: 0,
      max_usos: null,
      expira_em: null,
      status: "ativo",
    });
  }
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
  emailDisponivel = true;
  consentimentoVigente = { ...CONSENTIMENTO_VIGENTE };
}

/** Liga/desliga o canal e-mail (canais.email.enabled + smtp_host + from). */
export function setEmailDisponivelMock(disponivel) {
  emailDisponivel = Boolean(disponivel);
}

/** Publica outra versão do consentimento (a anterior deixa de ser vigente). */
export function setConsentimentoVigenteMock(versao) {
  consentimentoVigente = { publicada_em: new Date().toISOString(), ...versao };
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
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Contatos presentes na inscrição e o estado de cada um (contrato #214).
// confirmado_em/confirmado_via = telefone; email_confirmado_em = e-mail.
function contatosDoMembro(lista, m) {
  const coleta = lista?.coleta ?? "telefone";
  const exige = Boolean(lista?.exige_confirmacao);
  const estadoDe = (confirmadoEm) =>
    confirmadoEm ? "confirmado" : exige ? "pendente" : "nao_exigida";
  const contatos = {};
  if (coleta !== "email" && m.telefone) {
    contatos.telefone = {
      estado: estadoDe(m.confirmado_em),
      via: m.confirmado_em ? (m.confirmado_via ?? null) : null,
    };
  }
  if (coleta !== "telefone" && m.email) {
    contatos.email = {
      estado: estadoDe(m.email_confirmado_em),
      via: m.email_confirmado_em ? "email" : null,
    };
  }
  return contatos;
}

// estado geral do membro (contratos #212/#214)
function estadoMembro(lista, m) {
  const contatos = Object.values(contatosDoMembro(lista, m));
  const confirmados = contatos.filter((c) => c.estado === "confirmado").length;
  if (contatos.length > 0 && confirmados === contatos.length) return "confirmado";
  if (!lista?.exige_confirmacao) return confirmados > 0 ? "confirmado" : "nao_exigida";
  return confirmados > 0 ? "parcial" : "pendente";
}

function comEstado(lista, m) {
  const contatos = contatosDoMembro(lista, m);
  return {
    ...m,
    telefone: m.telefone ?? null,
    email: m.email ?? null,
    estado: estadoMembro(lista, m),
    telefone_estado: contatos.telefone?.estado ?? null,
    email_estado: contatos.email?.estado ?? null,
    confirmado_via: m.confirmado_via ?? (m.email_confirmado_em ? "email" : null),
    confirmado_em: m.confirmado_em ?? m.email_confirmado_em ?? null,
    email_confirmado_em: m.email_confirmado_em ?? null,
  };
}

function comContadores(inep, lista) {
  const membros = estadoFor(inep).membros[lista.id] ?? [];
  const exige = Boolean(lista.exige_confirmacao);
  const estados = membros.map((m) => estadoMembro(lista, m));
  const confirmados = estados.filter((e) => e === "confirmado").length;
  return {
    ...lista,
    coleta: lista.coleta ?? "telefone",
    exige_confirmacao: exige,
    n_membros: membros.length,
    membros_confirmados: confirmados,
    membros_pendentes: exige ? estados.filter((e) => e === "pendente" || e === "parcial").length : 0,
  };
}

const novaRef = () => crypto.randomUUID().replace(/-/g, "");

function membroDaRef(entry) {
  return (estadoFor(entry.cod_inep).membros[entry.lista_id] ?? []).find(
    (m) => m.id === entry.membro_id,
  );
}

// canais aplicáveis: telegram/whatsapp só com telefone; e-mail só com e-mail
// e o canal disponível
function canaisDaRef(ref, contatos) {
  const canais = [];
  if (contatos.telefone) {
    for (const canal of canaisDisponiveis) {
      canais.push(
        canal === "telegram"
          ? { canal, url: `https://t.me/${TELEGRAM_BOT_CONFIRMACAO}?start=${ref}` }
          : { canal },
      );
    }
  }
  if (contatos.email && emailDisponivel) canais.push({ canal: "email" });
  return canais;
}

function situacaoRef(ref, entry) {
  const lista = listaDe(entry.cod_inep, entry.lista_id);
  const membro = membroDaRef(entry);
  const contatos = membro ? contatosDoMembro(lista, membro) : {};
  const estado = membro ? estadoMembro(lista, membro) : "pendente";
  return { estado, contatos, canais: canaisDaRef(ref, contatos) };
}

function abrirRef(inep, listaId, membroId) {
  // reinscrição de pendente: a ref anterior é invalidada
  for (const [r, e] of refs) {
    if (e.membro_id === membroId && !e.usada) refs.delete(r);
  }
  const ref = novaRef();
  const expira_em = new Date(Date.now() + 24 * 3600 * 1000).toISOString();
  const entry = {
    cod_inep: inep,
    lista_id: listaId,
    membro_id: membroId,
    expira_em,
    usada: false,
    wa: { codigo: null, envios: 0, tentativas: 0 },
    em: { codigo: null, envios: 0, tentativas: 0 },
  };
  refs.set(ref, entry);
  ultimaRef = ref;
  const { estado, contatos, canais } = situacaoRef(ref, entry);
  return { ref, estado, expira_em, canais, contatos };
}

// Confirma um contato da ref (via telegram/whatsapp = telefone; email = e-mail).
// A ref só é marcada usada quando o estado geral fica `confirmado`.
function concluirRef(entry, via) {
  const membro = membroDaRef(entry);
  if (membro) {
    const agora = new Date().toISOString();
    if (via === "email") {
      membro.email_confirmado_em = agora;
    } else {
      membro.confirmado_em = agora;
      membro.confirmado_via = via;
    }
    membro.validado = true;
  }
  const lista = listaDe(entry.cod_inep, entry.lista_id);
  const estado = membro ? estadoMembro(lista, membro) : "confirmado";
  if (estado === "confirmado") entry.usada = true;
  return { estado, contatos: membro ? contatosDoMembro(lista, membro) : {} };
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
    const coleta = body.coleta ?? "telefone";
    if (!COLETAS_VALIDAS.includes(coleta)) {
      return HttpResponse.json({ error: "coleta inválida." }, { status: 400 });
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
      coleta,
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
    if (body.coleta !== undefined) {
      if (!COLETAS_VALIDAS.includes(body.coleta)) {
        return HttpResponse.json({ error: "coleta inválida." }, { status: 400 });
      }
      mudancas.coleta = body.coleta;
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
  http.post(`${BASE}/:id/qrcode`, async ({ request, params }) => {
    const denied = negarAuth(request) ?? negarPosse(params);
    if (denied) return denied;
    const lista = listaDe(params.cod_inep, params.id);
    if (!lista) {
      return HttpResponse.json({ error: "Lista não encontrada" }, { status: 404 });
    }
    // #214: validade e limite opcionais
    const body = await request.json().catch(() => ({}));
    const expiraEm = body?.expira_em ?? null;
    const maxUsos = body?.max_usos ?? null;
    if (expiraEm != null) {
      const t = Date.parse(expiraEm);
      if (Number.isNaN(t) || t <= Date.now()) {
        return HttpResponse.json(
          { error: "expira_em deve ser uma data futura (ISO 8601)." },
          { status: 400 },
        );
      }
    }
    if (maxUsos != null && !(Number.isInteger(maxUsos) && maxUsos > 0)) {
      return HttpResponse.json(
        { error: "max_usos deve ser um inteiro maior que zero." },
        { status: 400 },
      );
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
      cod_inep: String(lista.cod_inep),
      usos: 0,
      max_usos: maxUsos,
      expira_em: expiraEm,
      status: "ativo",
    };
    tokens.set(token, entry);
    const qrcode = {
      token,
      url: publicUrl(token),
      expira_em: expiraEm,
      usos: 0,
      max_usos: maxUsos,
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
    const coleta = lista?.coleta ?? "telefone";
    return HttpResponse.json({
      ...INSCRICAO_PUBLICA_FORM,
      ...CAMPOS_POR_COLETA[coleta],
      lista_nome: lista?.nome ?? INSCRICAO_PUBLICA_FORM.lista_nome,
      escola_nome: CANAIS_ESCOLA_NOME,
      expira_em: entry.expira_em ?? null,
      consentimento: { versao: consentimentoVigente.versao, texto: consentimentoVigente.texto },
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
    const lista = listaDe(entry.cod_inep, entry.lista_id);
    const coleta = lista?.coleta ?? "telefone";
    const { campos, obrigatorios } = CAMPOS_POR_COLETA[coleta];
    const nome = String(body.nome ?? "").trim();
    const telefone = campos.includes("telefone") ? String(body.telefone ?? "").trim() : "";
    const email = campos.includes("email") ? String(body.email ?? "").trim() : "";
    if (!nome || nome.length > 120) {
      return HttpResponse.json({ error: "Informe um nome válido." }, { status: 400 });
    }
    if ((obrigatorios.includes("telefone") && !telefone) || (telefone && normalizar(telefone).length < 8)) {
      return HttpResponse.json({ error: "Informe nome e telefone válidos." }, { status: 400 });
    }
    if ((obrigatorios.includes("email") && !email) || (email && !EMAIL_RE.test(email))) {
      return HttpResponse.json({ error: "Informe um e-mail válido." }, { status: 400 });
    }
    if (coleta === "qualquer" && !telefone && !email) {
      return HttpResponse.json({ error: "Informe telefone ou e-mail." }, { status: 400 });
    }
    if (body.consentimento !== true) {
      return HttpResponse.json(
        { error: "É necessário consentir com o uso dos dados." },
        { status: 400 },
      );
    }
    if (
      body.consentimento_versao != null &&
      body.consentimento_versao !== consentimentoVigente.versao
    ) {
      return HttpResponse.json(
        {
          error: "O texto de consentimento mudou. Leia e aceite a versão vigente.",
          consentimento: { versao: consentimentoVigente.versao, texto: consentimentoVigente.texto },
        },
        { status: 409 },
      );
    }

    const estab = estadoFor(entry.cod_inep);
    const membros = estab.membros[entry.lista_id] ?? (estab.membros[entry.lista_id] = []);
    const normTel = normalizar(telefone);
    const normEmail = email.toLowerCase();
    const existente = membros.find(
      (m) =>
        (normTel && normalizar(m.telefone) === normTel) ||
        (normEmail && String(m.email ?? "").toLowerCase() === normEmail),
    );

    entry.usos += 1;
    const exige = Boolean(lista?.exige_confirmacao);
    const exclusao_url = exclusaoUrl();

    if (existente) {
      if (!exige) return HttpResponse.json({ ok: 1, duplicado: 1, exclusao_url }, { status: 201 });
      const confirmacao =
        estadoMembro(lista, existente) === "confirmado"
          ? { estado: "confirmado" }
          : abrirRef(entry.cod_inep, entry.lista_id, existente.id);
      return HttpResponse.json({ ok: 1, duplicado: 1, confirmacao, exclusao_url }, { status: 201 });
    }

    const novo = {
      id: estab.proximos.membro++,
      contato_id: estab.proximos.contato++,
      nome,
      telefone: telefone || null,
      email: email || null,
      quando: new Date().toISOString(),
      validado: false,
      conflito: false,
      origem: "qrcode",
      confirmado_via: null,
      confirmado_em: null,
      email_confirmado_em: null,
      consentimento_versao: consentimentoVigente.versao,
    };
    membros.push(novo);
    if (lista) lista.n_membros = membros.length;
    if (!exige) return HttpResponse.json({ ok: 1, exclusao_url }, { status: 201 });
    const confirmacao = abrirRef(entry.cod_inep, entry.lista_id, novo.id);
    return HttpResponse.json({ ok: 1, confirmacao, exclusao_url }, { status: 201 });
  }),

  // --------------------- confirmação de posse (#212) -----------------------
  http.get(CONFIRMACAO, ({ params }) => {
    const entry = refs.get(params.ref);
    if (!entry || new Date(entry.expira_em).getTime() < Date.now()) return refNaoEncontrada();
    const { estado, contatos, canais } = situacaoRef(params.ref, entry);
    if (entry.usada) {
      return HttpResponse.json({ estado: "confirmado", canais: [], expira_em: entry.expira_em, contatos });
    }
    return HttpResponse.json({ estado, canais, expira_em: entry.expira_em, contatos });
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
    const { estado, contatos } = concluirRef(entry, "whatsapp");
    // inscrição só com telefone: resposta idêntica à da #212
    if (!contatos.email) return HttpResponse.json({ estado });
    return HttpResponse.json({ estado, contatos });
  }),

  // ------------------------ confirmação por e-mail (#214) -----------------
  http.post(`${CONFIRMACAO}/email`, ({ params }) => {
    const entry = refValida(params.ref);
    if (!entry) return refNaoEncontrada();
    const membro = membroDaRef(entry);
    if (!emailDisponivel || !membro?.email || membro.email_confirmado_em) {
      return HttpResponse.json({ error: "E-mail indisponível para esta confirmação." }, { status: 409 });
    }
    if (entry.em.envios >= 3) {
      return HttpResponse.json(
        { error: "Muitas tentativas. Aguarde para pedir outro código." },
        { status: 429 },
      );
    }
    entry.em = { codigo: EMAIL_CODIGO_MOCK, envios: entry.em.envios + 1, tentativas: 0 };
    const expira_em = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    return HttpResponse.json({ enviado: 1, expira_em }, { status: 202 });
  }),

  http.post(`${CONFIRMACAO}/email/verificar`, async ({ request, params }) => {
    const entry = refValida(params.ref);
    if (!entry || !entry.em.codigo) {
      return HttpResponse.json({ error: "Código expirado." }, { status: 410 });
    }
    if (entry.em.tentativas >= 5) {
      return HttpResponse.json({ error: "Tentativas excedidas." }, { status: 410 });
    }
    const body = await request.json().catch(() => ({}));
    if (String(body.codigo ?? "") !== entry.em.codigo) {
      entry.em.tentativas += 1;
      return HttpResponse.json({ error: "Código inválido." }, { status: 400 });
    }
    return HttpResponse.json(concluirRef(entry, "email"));
  }),

  // ------------------------ consentimento vigente (#214) ------------------
  http.get(CONSENTIMENTO, () => HttpResponse.json({ ...consentimentoVigente })),
];

export { PUBLIC_BASE };
