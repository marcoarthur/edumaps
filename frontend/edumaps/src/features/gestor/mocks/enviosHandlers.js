// src/features/gestor/mocks/enviosHandlers.js
// MSW handlers do envio por e-mail para listas (issue #216, Fase 3, onda 1):
//   gestão /api/gestor/:cod_inep/canais/envios[...]    (Bearer SESSION_TOKEN + posse)
//   gestão /api/gestor/:cod_inep/canais/segmentos[...]
//
// Estado em memória por escola; `resetEnviosMockState()` volta aos fixtures.
// Helpers de teste:
//   `setLimitesEnvioMock({...})`   muda limites (saldo, SMTP, suspensão, enabled)
//   `avancarEnvioMock(id, n)`      processa n pendentes (simula o job); sem
//                                  pendentes o envio vira `concluido`
//   `getEnviosMock()`              estado atual dos envios
//   `getChamadasEnvioMock(id)`     quantos GET /envios/:id já foram feitos
import { http, HttpResponse } from "msw";
import { CANAIS_ESCOLA_NOME, INEP_CANAIS, LISTAS_CANAIS_FIXTURE } from "./canaisFixtures.js";
import {
  DESTINATARIOS_ENVIOS_FIXTURE,
  DESTINATARIOS_LISTAS_FIXTURE,
  ENVIOS_FIXTURE,
  ENVIOS_GESTOR,
  LIMITES_ENVIO_FIXTURE,
  PRIVACIDADE_BASE,
  SEGMENTOS_FIXTURE,
} from "./enviosFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/canais";
const ENVIOS = `${BASE}/envios`;
const SEGMENTOS = `${BASE}/segmentos`;

const OPERACOES = ["aviso", "informacao", "pedido", "convite", "lembrete", "alerta"];
const ROTULO_OPERACAO = {
  aviso: "Aviso",
  informacao: "Informação",
  pedido: "Pedido",
  convite: "Convite",
  lembrete: "Lembrete",
  alerta: "Alerta",
};
const ESTADOS_MEMBRO = ["pendente", "parcial", "confirmado", "nao_exigida"];
const DATA_RE = /^\d{4}-\d{2}-\d{2}$/;

const clone = (o) => JSON.parse(JSON.stringify(o));

// ---------------------------------------------------------------------------
// estado em memória
// ---------------------------------------------------------------------------

let estado = null;
let limites = clone(LIMITES_ENVIO_FIXTURE);
const chamadasGet = new Map(); // envio id -> n

function baseState() {
  return {
    envios: clone(ENVIOS_FIXTURE),
    segmentos: clone(SEGMENTOS_FIXTURE),
    destinatarios: clone(DESTINATARIOS_ENVIOS_FIXTURE),
    testes: {}, // envio id -> n
    proximos: { envio: 100, segmento: 100, destinatario: 5000 },
  };
}

export function resetEnviosMockState() {
  estado = baseState();
  limites = clone(LIMITES_ENVIO_FIXTURE);
  chamadasGet.clear();
}
resetEnviosMockState();

export const setLimitesEnvioMock = (parcial) => {
  limites = { ...limites, ...parcial };
};
export const getEnviosMock = () => clone(estado.envios);
export const getChamadasEnvioMock = (id) => chamadasGet.get(Number(id)) ?? 0;

/** Simula o job: processa `n` pendentes; sem pendentes, conclui. */
export function avancarEnvioMock(id, n = 1) {
  const envio = estado.envios.find((e) => e.id === Number(id));
  if (!envio) return;
  if (envio.status === "agendado") {
    envio.status = "enviando";
    envio.iniciado_em = agora();
  }
  const rows = estado.destinatarios[envio.id] ?? [];
  for (const r of rows.filter((d) => d.status === "pendente").slice(0, n)) {
    r.status = "enviado";
    r.processado_em = agora();
  }
  recontar(envio);
  if (envio.contadores.pendentes === 0) {
    envio.status = "concluido";
    envio.concluido_em = agora();
  }
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

const agora = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

function negar(request, params) {
  const auth = request.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
  }
  if (params.cod_inep !== INEP_CANAIS) {
    return HttpResponse.json({ error: "Escola fora do seu acesso." }, { status: 403 });
  }
  return null;
}

const erro = (status, error, extra = {}) => HttpResponse.json({ error, ...extra }, { status });
const conflito = (motivo, extra = {}) =>
  HttpResponse.json({ error: `Não é possível disparar (${motivo}).`, motivo, ...extra }, { status: 409 });

/** j***@d***.org */
export function mascarar(email) {
  const [local = "", dominio = ""] = String(email ?? "").split("@");
  const partes = dominio.split(".");
  const tld = partes.length > 1 ? partes.pop() : "";
  return `${local.slice(0, 1)}***@${(partes.join(".") || "").slice(0, 1)}***${tld ? `.${tld}` : ""}`;
}

const listaDe = (id) => LISTAS_CANAIS_FIXTURE.find((l) => l.id === Number(id)) ?? null;
const segmentoDe = (id) => estado.segmentos.find((s) => s.id === Number(id)) ?? null;

function comListas(seg) {
  return {
    ...seg,
    listas: seg.criterios.listas.map((id) => {
      const l = listaDe(id);
      return { id, nome: l?.nome ?? null, existe: Boolean(l) };
    }),
  };
}

/** Membros com e-mail das listas (dedupe por e-mail; origem = menor id). */
function resolverCriterios(c) {
  const listas = [...new Set(c.listas.map(Number))].sort((a, b) => a - b);
  const ignoradas = listas.filter((id) => !listaDe(id));
  const vistos = new Map();
  let duplicados = 0;
  for (const id of listas.filter((i) => listaDe(i))) {
    for (const m of DESTINATARIOS_LISTAS_FIXTURE[id] ?? []) {
      if (c.estado?.length && !c.estado.includes(m.estado)) continue;
      if (c.email_confirmado === true && !m.email_confirmado) continue;
      if (c.email_confirmado === false && m.email_confirmado) continue;
      if (c.inscritos_desde && m.inscrito_em < c.inscritos_desde) continue;
      if (c.inscritos_ate && m.inscrito_em > c.inscritos_ate) continue;
      if (vistos.has(m.email)) {
        duplicados += 1;
        continue;
      }
      vistos.set(m.email, { ...m, lista_id: id });
    }
  }
  return { unicos: [...vistos.values()], duplicados, listas_ignoradas: ignoradas };
}

function resolverAlvo(envio) {
  if (envio.alvo.tipo === "lista") {
    if (!listaDe(envio.alvo.id)) return null;
    return resolverCriterios({ listas: [envio.alvo.id] });
  }
  const seg = segmentoDe(envio.alvo.id);
  return seg ? resolverCriterios(seg.criterios) : null;
}

function nomeAlvo(tipo, id) {
  return tipo === "lista" ? (listaDe(id)?.nome ?? null) : (segmentoDe(id)?.nome ?? null);
}

function recontar(envio) {
  const rows = estado.destinatarios[envio.id] ?? [];
  const n = (s) => rows.filter((r) => r.status === s).length;
  envio.contadores = {
    ...envio.contadores,
    destinatarios: rows.length,
    enviados: n("enviado"),
    falhas: n("falhou"),
    pendentes: n("pendente"),
    cancelados: n("cancelado"),
    optouts: n("ignorado_optout"),
  };
}

function validarEnvio(body, parcial = false) {
  const has = (k) => body[k] !== undefined;
  if (!parcial || has("alvo_tipo")) {
    if (!["lista", "segmento"].includes(body.alvo_tipo)) return "alvo_tipo inválido.";
  }
  if (!parcial || has("alvo_id")) {
    if (!Number.isInteger(Number(body.alvo_id)) || Number(body.alvo_id) <= 0) return "alvo_id inválido.";
  }
  if (!parcial || has("operacao")) {
    if (!OPERACOES.includes(body.operacao)) return "operacao inválida.";
  }
  if (!parcial || has("assunto")) {
    const a = String(body.assunto ?? "").trim();
    if (a.length < 1 || a.length > 200) return "assunto deve ter de 1 a 200 caracteres.";
  }
  if (!parcial || has("corpo")) {
    const c = String(body.corpo ?? "").trim();
    if (c.length < 1 || c.length > 20000) return "corpo deve ter de 1 a 20000 caracteres.";
  }
  return null;
}

function validarCriterios(c) {
  if (!c || !Array.isArray(c.listas) || c.listas.length < 1 || c.listas.length > 50) {
    return "Escolha de 1 a 50 listas.";
  }
  if (!c.listas.every((id) => Number.isInteger(id))) return "listas inválidas.";
  if (c.estado && !c.estado.every((e) => ESTADOS_MEMBRO.includes(e))) return "estado inválido.";
  for (const k of ["inscritos_desde", "inscritos_ate"]) {
    if (c[k] && !DATA_RE.test(c[k])) return `${k} inválida.`;
  }
  if (c.inscritos_desde && c.inscritos_ate && c.inscritos_desde > c.inscritos_ate) {
    return "A data inicial deve ser anterior à final.";
  }
  return null;
}

const semCorpo = ({ corpo: _corpo, ...resto }) => resto;

function rodape(envio) {
  const res = resolverAlvo(envio);
  const listaId = res?.unicos[0]?.lista_id ?? (envio.alvo.tipo === "lista" ? envio.alvo.id : null);
  const lista = listaDe(listaId)?.nome ?? envio.alvo.nome ?? "";
  return [
    "--",
    `Você recebe este e-mail porque se inscreveu na lista "${lista}" da escola ${CANAIS_ESCOLA_NOME}.`,
    `Motivo: ${ROTULO_OPERACAO[envio.operacao] ?? envio.operacao}.`,
    `Não quer mais receber mensagens desta lista? ${PRIVACIDADE_BASE}/privacidade/sair/EXEMPLO`,
    `Privacidade e remoção dos seus dados: ${PRIVACIDADE_BASE}/privacidade`,
  ].join("\n");
}

function paginar(rows, url) {
  const page = Math.max(1, Number(url.searchParams.get("page") ?? 1) || 1);
  const per = Math.min(100, Math.max(1, Number(url.searchParams.get("per_page") ?? 20) || 20));
  return {
    items: rows.slice((page - 1) * per, page * per),
    total: rows.length,
    page,
    per_page: per,
  };
}

const envioDe = (id) => estado.envios.find((e) => e.id === Number(id)) ?? null;
const naoEncontrado = () => erro(404, "Envio não encontrado.");

// ---------------------------------------------------------------------------
// handlers
// ---------------------------------------------------------------------------

export const gestorEnviosHandlers = [
  // ------------------------------ envios -----------------------------------
  http.get(ENVIOS, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const url = new URL(request.url);
    const status = url.searchParams.get("status");
    const rows = estado.envios
      .filter((e) => !status || e.status === status)
      .sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
      .map(semCorpo);
    return HttpResponse.json(paginar(rows, url));
  }),

  http.get(`${ENVIOS}/limites`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    return HttpResponse.json(clone(limites));
  }),

  http.post(ENVIOS, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const body = await request.json().catch(() => ({}));
    const msg = validarEnvio(body);
    if (msg) return erro(400, msg);
    const nome = nomeAlvo(body.alvo_tipo, body.alvo_id);
    if (nome == null) return erro(404, "Alvo não encontrado nesta escola.");
    const envio = {
      id: estado.proximos.envio++,
      cod_inep: Number(INEP_CANAIS),
      alvo: { tipo: body.alvo_tipo, id: Number(body.alvo_id), nome },
      canal: "email",
      operacao: body.operacao,
      assunto: body.assunto.trim(),
      corpo: body.corpo,
      status: "rascunho",
      agendado_para: null,
      iniciado_em: null,
      concluido_em: null,
      cancelado_em: null,
      contadores: { destinatarios: 0, enviados: 0, falhas: 0, ignorados: 0, pendentes: 0, cancelados: 0, optouts: 0 },
      autor: ENVIOS_GESTOR,
      created_at: agora(),
      updated_at: agora(),
    };
    estado.envios.push(envio);
    return HttpResponse.json(envio, { status: 201 });
  }),

  http.get(`${ENVIOS}/:id`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    chamadasGet.set(envio.id, (chamadasGet.get(envio.id) ?? 0) + 1);
    // rascunho mostra o nome atual do alvo
    if (envio.status === "rascunho") envio.alvo.nome = nomeAlvo(envio.alvo.tipo, envio.alvo.id);
    return HttpResponse.json(envio);
  }),

  http.patch(`${ENVIOS}/:id`, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    if (envio.status !== "rascunho") return conflito("status");
    const body = await request.json().catch(() => ({}));
    const msg = validarEnvio(body, true);
    if (msg) return erro(400, msg);
    const tipo = body.alvo_tipo ?? envio.alvo.tipo;
    const alvoId = body.alvo_id !== undefined ? Number(body.alvo_id) : envio.alvo.id;
    const nome = nomeAlvo(tipo, alvoId);
    if (nome == null) return erro(404, "Alvo não encontrado nesta escola.");
    envio.alvo = { tipo, id: alvoId, nome };
    for (const k of ["operacao", "assunto", "corpo"]) if (body[k] !== undefined) envio[k] = body[k];
    envio.updated_at = agora();
    return HttpResponse.json(envio);
  }),

  http.delete(`${ENVIOS}/:id`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    if (envio.status !== "rascunho") return conflito("status");
    estado.envios = estado.envios.filter((e) => e.id !== envio.id);
    return HttpResponse.json({ ok: 1 });
  }),

  http.post(`${ENVIOS}/:id/previa`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    const res = resolverAlvo(envio) ?? { unicos: [], duplicados: 0 };
    return HttpResponse.json({
      assunto: envio.assunto,
      texto: `${envio.corpo}\n\n${rodape(envio)}`,
      estimativa: {
        destinatarios: res.unicos.length,
        ignorados_optout: 0,
        ignorados_duplicado: res.duplicados,
      },
    });
  }),

  http.post(`${ENVIOS}/:id/teste`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    if (!limites.smtp_disponivel) return conflito("smtp_indisponivel");
    const n = (estado.testes[envio.id] ?? 0) + 1;
    if (n > 5) return erro(429, "Limite de testes atingido.");
    estado.testes[envio.id] = n;
    return HttpResponse.json({ enviado: 1, para: "h***@e***.br" }, { status: 202 });
  }),

  http.post(`${ENVIOS}/:id/disparar`, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    const body = await request.json().catch(() => ({}));
    const quando = body?.agendado_para ? new Date(body.agendado_para) : null;
    if (quando) {
      const delta = quando.getTime() - Date.now();
      if (Number.isNaN(delta) || delta <= 0 || delta > 90 * 86400000) {
        return erro(400, "A data do agendamento deve ser futura e em até 90 dias.");
      }
    }
    if (envio.status !== "rascunho") return conflito("status");
    if (!limites.enabled) return conflito("envio_desligado");
    if (!limites.smtp_disponivel) return conflito("smtp_indisponivel");
    if (limites.suspensao) return conflito("escola_suspensa");
    const res = resolverAlvo(envio);
    if (!res) return conflito("alvo_inexistente");
    const n = res.unicos.length;
    if (n === 0) return conflito("sem_destinatarios");
    if (n > limites.max_destinatarios) return conflito("acima_do_teto", { teto: limites.max_destinatarios });
    if (!quando && n > limites.saldo_hoje) return conflito("cota_insuficiente", { saldo: limites.saldo_hoje });
    if (quando && n > limites.cota_diaria) return conflito("cota_insuficiente", { saldo: limites.cota_diaria });

    estado.destinatarios[envio.id] = res.unicos.map((m) => ({
      id: estado.proximos.destinatario++,
      nome: m.nome,
      email: mascarar(m.email),
      lista_id: m.lista_id,
      status: "pendente",
      erro: null,
      processado_em: null,
    }));
    envio.alvo.nome = nomeAlvo(envio.alvo.tipo, envio.alvo.id); // fotografia
    envio.contadores.ignorados = res.duplicados;
    recontar(envio);
    if (quando) {
      envio.status = "agendado";
      envio.agendado_para = quando.toISOString().replace(/\.\d{3}Z$/, "Z");
    } else {
      envio.status = "enviando";
      envio.iniciado_em = agora();
    }
    envio.updated_at = agora();
    return HttpResponse.json(envio, { status: 202 });
  }),

  http.post(`${ENVIOS}/:id/cancelar`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    if (!["agendado", "enviando", "pausado_cota", "suspenso"].includes(envio.status)) {
      return conflito("status");
    }
    for (const r of estado.destinatarios[envio.id] ?? []) {
      if (r.status === "pendente") r.status = "cancelado";
    }
    recontar(envio);
    envio.status = "cancelado";
    envio.cancelado_em = agora();
    return HttpResponse.json(envio);
  }),

  http.get(`${ENVIOS}/:id/destinatarios`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const envio = envioDe(params.id);
    if (!envio) return naoEncontrado();
    const url = new URL(request.url);
    const status = url.searchParams.get("status");
    const rows = (estado.destinatarios[envio.id] ?? []).filter((r) => !status || r.status === status);
    return HttpResponse.json(paginar(rows, url));
  }),

  // ----------------------------- segmentos ---------------------------------
  http.get(SEGMENTOS, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const rows = [...estado.segmentos].sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));
    return HttpResponse.json(rows.map(comListas));
  }),

  http.post(`${SEGMENTOS}/previa`, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const body = await request.json().catch(() => ({}));
    const msg = validarCriterios(body?.criterios);
    if (msg) return erro(400, msg);
    const res = resolverCriterios(body.criterios);
    return HttpResponse.json({
      destinatarios: res.unicos.length,
      amostra: res.unicos.slice(0, 10).map((m) => ({ nome: m.nome, email: mascarar(m.email) })),
      listas_ignoradas: res.listas_ignoradas,
    });
  }),

  http.post(SEGMENTOS, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const body = await request.json().catch(() => ({}));
    const nome = String(body?.nome ?? "").trim();
    if (!nome) return erro(400, "Informe o nome.");
    const msg = validarCriterios(body?.criterios);
    if (msg) return erro(400, msg);
    if (body.criterios.listas.some((id) => !listaDe(id))) return erro(400, "Lista fora desta escola.");
    if (estado.segmentos.some((s) => s.nome.toLowerCase() === nome.toLowerCase())) {
      return erro(409, "Já existe uma lista dinâmica com esse nome.");
    }
    const seg = {
      id: estado.proximos.segmento++,
      nome,
      criterios: clone(body.criterios),
      created_at: agora(),
      updated_at: agora(),
    };
    estado.segmentos.push(seg);
    return HttpResponse.json(comListas(seg), { status: 201 });
  }),

  http.get(`${SEGMENTOS}/:id`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const seg = segmentoDe(params.id);
    if (!seg) return erro(404, "Lista dinâmica não encontrada.");
    return HttpResponse.json(comListas(seg));
  }),

  http.put(`${SEGMENTOS}/:id`, async ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const seg = segmentoDe(params.id);
    if (!seg) return erro(404, "Lista dinâmica não encontrada.");
    const body = await request.json().catch(() => ({}));
    const nome = String(body?.nome ?? "").trim();
    if (!nome) return erro(400, "Informe o nome.");
    const msg = validarCriterios(body?.criterios);
    if (msg) return erro(400, msg);
    if (body.criterios.listas.some((id) => !listaDe(id) && !seg.criterios.listas.includes(id))) {
      return erro(400, "Lista fora desta escola.");
    }
    if (estado.segmentos.some((s) => s.id !== seg.id && s.nome.toLowerCase() === nome.toLowerCase())) {
      return erro(409, "Já existe uma lista dinâmica com esse nome.");
    }
    seg.nome = nome;
    seg.criterios = clone(body.criterios);
    seg.updated_at = agora();
    return HttpResponse.json(comListas(seg));
  }),

  http.delete(`${SEGMENTOS}/:id`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const seg = segmentoDe(params.id);
    if (!seg) return erro(404, "Lista dinâmica não encontrada.");
    estado.segmentos = estado.segmentos.filter((s) => s.id !== seg.id);
    return HttpResponse.json({ ok: 1 });
  }),

  http.get(`${SEGMENTOS}/:id/previa`, ({ request, params }) => {
    const denied = negar(request, params);
    if (denied) return denied;
    const seg = segmentoDe(params.id);
    if (!seg) return erro(404, "Lista dinâmica não encontrada.");
    const res = resolverCriterios(seg.criterios);
    return HttpResponse.json({
      destinatarios: res.unicos.length,
      amostra: res.unicos.slice(0, 10).map((m) => ({ nome: m.nome, email: mascarar(m.email) })),
      listas_ignoradas: res.listas_ignoradas,
    });
  }),
];
