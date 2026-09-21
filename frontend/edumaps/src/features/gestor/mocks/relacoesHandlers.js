// src/features/gestor/mocks/relacoesHandlers.js
// MSW handlers das Relações Institucionais (base /api/gestor/:cod_inep/relacoes).
// Exigem a sessão do gestor (Bearer SESSION_TOKEN) — espelha o backend.
import { http, HttpResponse } from "msw";
import {
  CATEGORIAS_RELACOES,
  ENTIDADES_RELACOES,
  RELACOES_RELACOES,
  INEP_RELACOES,
} from "./relacoesFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/relacoes";

function okAuth(request) {
  const auth = request.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
  }
  return null;
}

const clone = (x) => JSON.parse(JSON.stringify(x));

const mem = new Map();
function stateFor(inep) {
  if (!mem.has(inep)) {
    mem.set(inep, {
      categorias: clone(CATEGORIAS_RELACOES),
      entidades: clone(ENTIDADES_RELACOES),
      relacoes: clone(RELACOES_RELACOES),
      proximos: { categoria: 100, entidade: 100, relacao: 500 },
    });
  }
  return mem.get(inep);
}

function entNome(estab, id) {
  return estab.entidades.find((e) => e.id === id)?.nome ?? null;
}
function entTipo(estab, id) {
  return estab.entidades.find((e) => e.id === id)?.tipo ?? null;
}

function relacaoOut(estab, r) {
  return {
    ...r,
    entidade_nome: entNome(estab, r.entidade_id),
    entidade_tipo: entTipo(estab, r.entidade_id),
  };
}

export const gestorRelacoesHandlers = [
  // ------------------------------ índice -----------------------------------
  http.get(BASE, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_RELACOES) {
      return HttpResponse.json({ categorias: [], entidades: [], relacoes: [] });
    }
    const estab = stateFor(params.cod_inep);
    const url = new URL(request.url);
    const status = url.searchParams.get("status");
    const prioridade = url.searchParams.get("prioridade");
    const entidade = url.searchParams.get("entidade_id");
    const vencidas = url.searchParams.get("vencidas");
    const q = url.searchParams.get("q");

    let relacoes = estab.relacoes.map((r) => relacaoOut(estab, r));
    if (status) relacoes = relacoes.filter((r) => r.status === status);
    if (prioridade) relacoes = relacoes.filter((r) => r.prioridade === prioridade);
    if (entidade) relacoes = relacoes.filter((r) => r.entidade_id === Number(entidade));
    if (vencidas) relacoes = relacoes.filter((r) => r.vencida);
    if (q) {
      const t = q.toLowerCase();
      relacoes = relacoes.filter(
        (r) =>
          r.assunto.toLowerCase().includes(t) ||
          (r.entidade_nome ?? "").toLowerCase().includes(t),
      );
    }

    return HttpResponse.json({
      categorias: estab.categorias,
      entidades: estab.entidades,
      relacoes,
    });
  }),

  // ---------------------------- categorias ---------------------------------
  http.post(`${BASE}/categorias`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.eixo || !body.nome) {
      return HttpResponse.json({ error: "Informe eixo e nome da categoria." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    if (estab.categorias.some((c) => c.eixo === body.eixo && c.nome.toLowerCase() === body.nome.toLowerCase())) {
      return HttpResponse.json({ error: "Já existe uma categoria com este nome para este eixo." }, { status: 409 });
    }
    const cat = { id: estab.proximos.categoria++, eixo: body.eixo, nome: body.nome, origem: "manual", n_entidades: 0 };
    estab.categorias.push(cat);
    return HttpResponse.json(cat, { status: 201 });
  }),

  http.put(`${BASE}/categorias/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const cat = estab.categorias.find((c) => c.id === Number(params.id));
    if (!cat) return HttpResponse.json({ error: "Categoria não encontrada" }, { status: 404 });
    cat.eixo = body.eixo;
    cat.nome = body.nome;
    return HttpResponse.json(cat);
  }),

  http.delete(`${BASE}/categorias/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.categorias.findIndex((c) => c.id === Number(params.id));
    if (idx !== -1) estab.categorias.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // ----------------------------- entidades ---------------------------------
  http.get(`${BASE}/entidades`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const url = new URL(request.url);
    const tipo = url.searchParams.get("tipo");
    const q = url.searchParams.get("q");
    let lista = estab.entidades;
    if (tipo) lista = lista.filter((e) => e.tipo === tipo);
    if (q) lista = lista.filter((e) => e.nome.toLowerCase().includes(q.toLowerCase()));
    return HttpResponse.json(lista);
  }),

  http.post(`${BASE}/entidades`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.nome || !body.nome.trim()) {
      return HttpResponse.json({ error: "Informe o nome da entidade." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    if (estab.entidades.some((e) => e.nome.toLowerCase() === body.nome.toLowerCase())) {
      return HttpResponse.json({ error: "Já existe uma entidade com este nome nesta escola." }, { status: 409 });
    }
    const ent = {
      id: estab.proximos.entidade++,
      tipo: body.tipo ?? null,
      nome: body.nome,
      identificador: body.identificador ?? null,
      responsavel_externo: body.responsavel_externo ?? null,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      site: body.site ?? null,
      endereco: body.endereco ?? null,
      observacoes: body.observacoes ?? null,
      atributos: body.atributos ?? {},
      n_relacoes: 0,
      updated_at: new Date().toISOString(),
    };
    estab.entidades.push(ent);
    return HttpResponse.json(ent, { status: 201 });
  }),

  http.get(`${BASE}/entidades/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const ent = estab.entidades.find((e) => e.id === Number(params.id));
    if (!ent) return HttpResponse.json({ error: "Entidade não encontrada" }, { status: 404 });
    return HttpResponse.json(ent);
  }),

  http.put(`${BASE}/entidades/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const ent = estab.entidades.find((e) => e.id === Number(params.id));
    if (!ent) return HttpResponse.json({ error: "Entidade não encontrada" }, { status: 404 });
    Object.assign(ent, {
      tipo: body.tipo ?? null,
      nome: body.nome,
      identificador: body.identificador ?? null,
      responsavel_externo: body.responsavel_externo ?? null,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      site: body.site ?? null,
      endereco: body.endereco ?? null,
      observacoes: body.observacoes ?? null,
      atributos: body.atributos ?? {},
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(ent);
  }),

  http.delete(`${BASE}/entidades/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    if (estab.relacoes.some((r) => r.entidade_id === id)) {
      return HttpResponse.json({ error: "Não é possível excluir: a entidade tem relações registradas." }, { status: 409 });
    }
    const idx = estab.entidades.findIndex((e) => e.id === id);
    if (idx !== -1) estab.entidades.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // ------------------------------ relações ---------------------------------
  http.post(BASE, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.entidade_id || !body.assunto) {
      return HttpResponse.json({ error: "Informe a entidade e o assunto." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    if (!estab.entidades.some((e) => e.id === body.entidade_id)) {
      return HttpResponse.json({ error: "Entidade não encontrada para esta escola" }, { status: 404 });
    }
    const rel = {
      id: estab.proximos.relacao++,
      entidade_id: body.entidade_id,
      finalidade: body.finalidade ?? null,
      assunto: body.assunto,
      descricao: body.descricao ?? null,
      status: body.status ?? "aberta",
      prioridade: body.prioridade ?? "media",
      responsavel_interno: body.responsavel_interno ?? null,
      inicio: body.inicio ?? null,
      proxima_acao: body.proxima_acao ?? null,
      prazo: body.prazo ?? null,
      vencida: 0,
      atributos: body.atributos ?? {},
      updated_at: new Date().toISOString(),
    };
    estab.relacoes.unshift(rel);
    return HttpResponse.json(relacaoOut(estab, rel), { status: 201 });
  }),

  http.get(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (!rel) return HttpResponse.json({ error: "Relação não encontrada" }, { status: 404 });
    return HttpResponse.json(relacaoOut(estab, rel));
  }),

  http.put(`${BASE}/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (!rel) return HttpResponse.json({ error: "Relação não encontrada" }, { status: 404 });
    Object.assign(rel, {
      entidade_id: body.entidade_id,
      finalidade: body.finalidade ?? null,
      assunto: body.assunto,
      descricao: body.descricao ?? null,
      status: body.status ?? "aberta",
      prioridade: body.prioridade ?? "media",
      responsavel_interno: body.responsavel_interno ?? null,
      inicio: body.inicio ?? null,
      proxima_acao: body.proxima_acao ?? null,
      prazo: body.prazo ?? null,
      atributos: body.atributos ?? {},
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(relacaoOut(estab, rel));
  }),

  http.delete(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.relacoes.findIndex((r) => r.id === Number(params.id));
    if (idx !== -1) estab.relacoes.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),
];
