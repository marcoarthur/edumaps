// src/features/gestor/mocks/planosHandlers.js
// MSW dos planos de gestão (base /api/gestor/:cod_inep/planos). Exigem a
// sessão do gestor (Bearer SESSION_TOKEN) e reproduzem as regras do backend
// que a tela precisa ver: plano encerrado → 409; "atrasada" derivada;
// progresso da meta (aumentar/reduzir/manter) e agregado com N de M;
// evidências (#372): origem de outra escola → 403, duplicata → 409.
import { http, HttpResponse } from "msw";
import { PLANOS_PLANOS, INDICADORES_PLANOS, INEP_PLANOS, HOJE_PLANOS, ORIGENS_PLANOS } from "./planosFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/planos";
const clone = (x) => JSON.parse(JSON.stringify(x));

function okAuth(request) {
  const auth = request.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
  }
  return null;
}

let estado = null;
let proximo = 5000;
export function resetPlanosMock() {
  estado = clone(PLANOS_PLANOS);
  proximo = 5000;
}
resetPlanosMock();

const ENCERRADO = () =>
  HttpResponse.json({ error: "Plano encerrado é só leitura. Reabra o plano para editar." }, { status: 409 });
const NAO_ACHOU = (o) => HttpResponse.json({ error: `${o} não encontrado.` }, { status: 404 });

export function progressoMeta(sentido, base, alvo, atual) {
  if (alvo == null || (sentido !== "manter" && base == null)) return [null, "rascunho"];
  if (atual == null) return [null, "sem_medicao"];
  let p;
  if (sentido === "manter") p = atual >= alvo ? 1 : 0;
  else if (sentido === "aumentar") { if (!(alvo > base)) return [null, "incoerente"]; p = (atual - base) / (alvo - base); }
  else { if (!(alvo < base)) return [null, "incoerente"]; p = (base - atual) / (base - alvo); }
  return [Math.round(Math.min(1, Math.max(0, p)) * 10000) / 10000, "medida"];
}

function agregar(metas) {
  const med = metas.filter((m) => m.progresso !== null);
  const soma = med.reduce((s, m) => s + m.progresso, 0);
  return { valor: med.length ? Math.round((soma / med.length) * 10000) / 10000 : null,
           n_medidas: med.length, n_metas: metas.length };
}

function metaOut(m) {
  const ind = INDICADORES_PLANOS.find((i) => i.codigo === m.indicador_codigo);
  const meds = [...m.medicoes].sort((a, b) => a.data_ref.localeCompare(b.data_ref));
  const atual = meds.at(-1) ?? null;
  let [progresso, estadoMeta] = progressoMeta(m.sentido, m.linha_base, m.alvo, atual?.valor ?? null);
  if (estadoMeta === "sem_medicao" && ind) estadoMeta = "sem_dado";
  return { ...m, medicoes: meds, atual, progresso, estado: estadoMeta,
           indicador: ind ? { codigo: ind.codigo, rotulo: ind.rotulo, unidade: ind.unidade, fonte: ind.fonte } : undefined };
}

const atrasada = (a) => ["nao_iniciada", "em_andamento"].includes(a.situacao) && !!a.prazo && a.prazo < HOJE_PLANOS;

function planoOut(p) {
  const objetivos = p.objetivos.map((o) => {
    const metas = o.metas.map(metaOut);
    return { ...o, metas, acoes: o.acoes.map((a) => ({ ...a, atrasada: atrasada(a) })), progresso: agregar(metas) };
  });
  const todasMetas = objetivos.flatMap((o) => o.metas);
  const todasAcoes = objetivos.flatMap((o) => o.acoes);
  return {
    ...p, objetivos,
    resumo: {
      n_objetivos: objetivos.length, n_metas: todasMetas.length, n_acoes: todasAcoes.length,
      n_acoes_concluidas: todasAcoes.filter((a) => a.situacao === "concluida").length,
      n_acoes_atrasadas: todasAcoes.filter((a) => a.atrasada).length,
      progresso: agregar(todasMetas),
    },
  };
}

const resumoLista = (p) => {
  const { objetivos, resumo, ...rest } = planoOut(p);
  const { progresso, ...r } = resumo;
  return { ...rest, resumo: r };
};

function achar(params) {
  if (params.cod_inep !== INEP_PLANOS) return null;
  return estado.find((p) => p.id === Number(params.id) && !p.arquivado) ?? null;
}

// Aplica o handler com plano existente e editável.
function editavel(fn) {
  return async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const p = achar(params);
    if (!p) return NAO_ACHOU("Plano");
    if (p.situacao === "encerrado") return ENCERRADO();
    const body = request.method === "DELETE" ? null : await request.json();
    return fn(p, body, params);
  };
}

const objetivoDe = (p, id) => p.objetivos.find((o) => o.id === Number(id));
const metaDe = (p, id) => p.objetivos.flatMap((o) => o.metas).find((m) => m.id === Number(id));
const acaoDe = (p, id) => p.objetivos.flatMap((o) => o.acoes).find((a) => a.id === Number(id));

export const gestorPlanosHandlers = [
  http.get(`${BASE}/indicadores`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    return HttpResponse.json({ indicadores: params.cod_inep === INEP_PLANOS ? clone(INDICADORES_PLANOS) : [] });
  }),

  http.get(`${BASE}/evidencias/origens`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_PLANOS) return HttpResponse.json({ error: "Acesso negado" }, { status: 403 });
    return HttpResponse.json(clone(ORIGENS_PLANOS));
  }),

  http.get(BASE, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_PLANOS) return HttpResponse.json({ planos: [] });
    const arq = new URL(request.url).searchParams.get("arquivados");
    return HttpResponse.json({ planos: estado.filter((p) => arq || !p.arquivado).map(resumoLista) });
  }),

  http.post(BASE, async ({ request }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const b = await request.json();
    if (!b.titulo || !b.tipo) {
      return HttpResponse.json({ error: "Dados inválidos", campos: { titulo: "obrigatório" } }, { status: 400 });
    }
    const p = { id: proximo++, descricao: null, inicio: null, fim: null, situacao: "rascunho", documento_id: null,
                alertas_ativos: true, arquivado: false, objetivos: [], ...b };
    estado.push(p);
    return HttpResponse.json(planoOut(p), { status: 201 });
  }),

  http.get(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const p = achar(params);
    return p ? HttpResponse.json(planoOut(p)) : NAO_ACHOU("Plano");
  }),

  http.put(`${BASE}/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const p = achar(params);
    if (!p) return NAO_ACHOU("Plano");
    const b = await request.json();
    if (p.situacao === "encerrado") {
      const reabre = b.situacao && b.situacao !== "encerrado" && Object.keys(b).length === 1;
      if (!reabre) return ENCERRADO();
    }
    Object.assign(p, b);
    return HttpResponse.json(planoOut(p));
  }),

  http.delete(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const p = achar(params);
    if (!p) return NAO_ACHOU("Plano");
    p.arquivado = true;
    return HttpResponse.json({ arquivado: true });
  }),

  http.post(`${BASE}/:id/objetivos`, editavel((p, b) => {
    const o = { id: proximo++, titulo: b.titulo, descricao: b.descricao ?? null,
                ordem: p.objetivos.length + 1, metas: [], acoes: [] };
    p.objetivos.push(o);
    return HttpResponse.json(o, { status: 201 });
  })),
  http.put(`${BASE}/:id/objetivos/:oid`, editavel((p, b, params) => {
    const o = objetivoDe(p, params.oid);
    if (!o) return NAO_ACHOU("Objetivo");
    Object.assign(o, b);
    return HttpResponse.json(o);
  })),
  http.delete(`${BASE}/:id/objetivos/:oid`, editavel((p, _b, params) => {
    p.objetivos = p.objetivos.filter((o) => o.id !== Number(params.oid));
    return HttpResponse.json({ excluido: true });
  })),

  http.post(`${BASE}/:id/metas`, editavel((p, b) => {
    const o = objetivoDe(p, b.objetivo_id);
    if (!o) return HttpResponse.json({ error: "Objetivo não encontrado neste plano." }, { status: 400 });
    const ind = INDICADORES_PLANOS.find((i) => i.codigo === b.indicador_codigo);
    const m = { id: proximo++, unidade: ind?.unidade ?? null, sentido: "aumentar", indicador_codigo: null,
                linha_base: ind?.ultimo?.valor ?? null, alvo: null, prazo: null, medicoes: [], ...b };
    if (ind?.ultimo) {
      m.medicoes = [{ id: proximo++, origem: "oficial", data_ref: `${ind.ultimo.ano}-12-31`,
                      ano_ref: ind.ultimo.ano, valor: ind.ultimo.valor, nota: null }];
    }
    o.metas.push(m);
    return HttpResponse.json(metaOut(m), { status: 201 });
  })),
  http.put(`${BASE}/:id/metas/:mid`, editavel((p, b, params) => {
    const m = metaDe(p, params.mid);
    if (!m) return NAO_ACHOU("Meta");
    Object.assign(m, b);
    return HttpResponse.json(metaOut(m));
  })),
  http.delete(`${BASE}/:id/metas/:mid`, editavel((p, _b, params) => {
    for (const o of p.objetivos) o.metas = o.metas.filter((m) => m.id !== Number(params.mid));
    return HttpResponse.json({ excluido: true });
  })),
  http.post(`${BASE}/:id/metas/:mid/medicoes`, editavel((p, b, params) => {
    const m = metaDe(p, params.mid);
    if (!m) return NAO_ACHOU("Meta");
    if (m.indicador_codigo) {
      return HttpResponse.json(
        { error: "Meta ligada a indicador oficial: o valor vem da fonte, não é informado à mão." }, { status: 400 });
    }
    m.medicoes.push({ id: proximo++, origem: "manual", data_ref: b.data_ref, ano_ref: null,
                      valor: Number(String(b.valor).replace(",", ".")), nota: b.nota ?? null });
    return HttpResponse.json(metaOut(m), { status: 201 });
  })),
  http.delete(`${BASE}/:id/metas/:mid/medicoes/:medid`, editavel((p, _b, params) => {
    const m = metaDe(p, params.mid);
    if (!m) return NAO_ACHOU("Meta");
    m.medicoes = m.medicoes.filter((x) => x.id !== Number(params.medid));
    return HttpResponse.json({ excluido: true });
  })),

  http.post(`${BASE}/:id/acoes`, editavel((p, b) => {
    const o = objetivoDe(p, b.objetivo_id);
    if (!o) return HttpResponse.json({ error: "Objetivo não encontrado neste plano." }, { status: 400 });
    const a = { id: proximo++, meta_id: null, responsavel: null, inicio: null, prazo: null, situacao: "nao_iniciada",
                concluida_em: null, custo_previsto: null, fonte_recurso: null, ...b };
    o.acoes.push(a);
    return HttpResponse.json({ ...a, atrasada: atrasada(a) }, { status: 201 });
  })),
  http.put(`${BASE}/:id/acoes/:aid`, editavel((p, b, params) => {
    const a = acaoDe(p, params.aid);
    if (!a) return NAO_ACHOU("Ação");
    Object.assign(a, b);
    a.concluida_em = a.situacao === "concluida" ? (a.concluida_em ?? `${HOJE_PLANOS}T10:00:00`) : null;
    return HttpResponse.json({ ...a, atrasada: atrasada(a) });
  })),
  http.delete(`${BASE}/:id/acoes/:aid`, editavel((p, _b, params) => {
    for (const o of p.objetivos) o.acoes = o.acoes.filter((a) => a.id !== Number(params.aid));
    return HttpResponse.json({ excluido: true });
  })),

  http.post(`${BASE}/:id/evidencias`, editavel((p, b) => {
    const dono = b.acao_id != null ? acaoDe(p, b.acao_id) : b.meta_id != null ? metaDe(p, b.meta_id) : null;
    if (!dono || (b.acao_id != null && b.meta_id != null)) {
      return HttpResponse.json({ error: "A evidência é de uma ação ou de uma meta (informe só uma)." }, { status: 400 });
    }
    let ev = { id: proximo++, tipo: b.tipo, titulo: null, texto: null, reuniao_id: null, quando: null,
               documento_id: null, documento_versao_id: null, versao: null, origem_removida: false,
               criado_em: `${HOJE_PLANOS}T10:00:00` };
    if (b.tipo === "ata") {
      const r = ORIGENS_PLANOS.reunioes.find((x) => x.id === b.reuniao_id);
      if (!r) return HttpResponse.json({ error: "A reunião é de outra escola." }, { status: 403 });
      ev = { ...ev, titulo: r.titulo, reuniao_id: r.id, quando: r.quando };
    } else if (b.tipo === "documento") {
      const d = ORIGENS_PLANOS.documentos.find((x) => x.versao_id === b.documento_versao_id);
      if (!d) return HttpResponse.json({ error: "O documento é de outra escola." }, { status: 403 });
      ev = { ...ev, titulo: `${d.nome} (v${d.versao})`, documento_id: d.documento_id,
             documento_versao_id: d.versao_id, versao: d.versao };
    } else {
      ev.texto = b.texto;
    }
    dono.evidencias ??= [];
    const dup = b.tipo !== "nota" && dono.evidencias.some((e) =>
      (b.tipo === "ata" && e.reuniao_id === ev.reuniao_id) ||
      (b.tipo === "documento" && e.documento_versao_id === ev.documento_versao_id));
    if (dup) return HttpResponse.json({ error: "Esta evidência já está ligada." }, { status: 409 });
    dono.evidencias.push(ev);
    return HttpResponse.json(ev, { status: 201 });
  })),
  http.delete(`${BASE}/:id/evidencias/:eid`, editavel((p, _b, params) => {
    const id = Number(params.eid);
    const donos = p.objetivos.flatMap((o) => [...o.metas, ...o.acoes]);
    const dono = donos.find((d) => (d.evidencias ?? []).some((e) => e.id === id));
    if (!dono) return NAO_ACHOU("Evidência");
    dono.evidencias = dono.evidencias.filter((e) => e.id !== id);
    return HttpResponse.json({ excluido: true });
  })),
];
