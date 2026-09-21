// src/features/gestor/mocks/relacoesHandlers.js
// MSW handlers das Relações Institucionais (base /api/gestor/:cod_inep/relacoes).
// Exigem a sessão do gestor (Bearer SESSION_TOKEN) — espelha o backend.
import { http, HttpResponse } from "msw";
import {
  CATEGORIAS_RELACOES,
  ENTIDADES_RELACOES,
  RELACOES_RELACOES,
  INTERACOES_RELACAO,
  DOCUMENTOS_RELACAO,
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
      relacoes: clone(RELACOES_RELACOES).map((r) => ({
        ...r,
        interacoes: r.id === 1 ? clone(INTERACOES_RELACAO) : [],
        documentos: r.id === 1 ? clone(DOCUMENTOS_RELACAO) : [],
      })),
      proximos: { categoria: 100, entidade: 100, relacao: 500, interacao: 100, documento: 100 },
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
  const { interacoes, documentos, ...rest } = r;
  return {
    ...rest,
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

  http.get(`${BASE}/agenda`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const url = new URL(request.url);
    const de = url.searchParams.get("de");
    const ate = url.searchParams.get("ate");

    let lista = estab.relacoes
      .map((r) => relacaoOut(estab, r))
      .filter((r) => !["concluida", "cancelada"].includes(r.status))
      .filter((r) => r.prazo || r.proxima_acao);
    if (de) lista = lista.filter((r) => r.prazo && r.prazo >= de);
    if (ate) lista = lista.filter((r) => r.prazo && r.prazo <= ate);
    lista.sort((a, b) => (a.prazo ?? "9999") .localeCompare(b.prazo ?? "9999"));

    return HttpResponse.json({
      de,
      ate,
      total: lista.length,
      vencidas: lista.filter((r) => r.vencida).length,
      itens: lista.filter((r) => r.prazo),
      sem_prazo: lista.filter((r) => !r.prazo),
    });
  }),

  http.get(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (!rel) return HttpResponse.json({ error: "Relação não encontrada" }, { status: 404 });
    return HttpResponse.json({
      ...relacaoOut(estab, rel),
      interacoes: rel.interacoes ?? [],
      documentos: rel.documentos ?? [],
    });
  }),

  // --------------------------- interações ---------------------------------
  http.post(`${BASE}/:id/interacoes`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.assunto || !body.assunto.trim()) {
      return HttpResponse.json({ error: "Informe o assunto da interação." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (!rel) return HttpResponse.json({ error: "Relação não encontrada" }, { status: 404 });
    const inter = {
      id: estab.proximos.interacao++,
      data: body.data ?? null,
      canal: body.canal ?? null,
      participante: body.participante ?? null,
      assunto: body.assunto,
      descricao: body.descricao ?? null,
      resultado: body.resultado ?? null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    rel.interacoes = [...(rel.interacoes ?? []), inter];
    return HttpResponse.json(inter, { status: 201 });
  }),

  http.put(`${BASE}/:id/interacoes/:interacao_id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    const inter = (rel?.interacoes ?? []).find((i) => i.id === Number(params.interacao_id));
    if (!inter) return HttpResponse.json({ error: "Interação não encontrada" }, { status: 404 });
    Object.assign(inter, {
      data: body.data ?? null,
      canal: body.canal ?? null,
      participante: body.participante ?? null,
      assunto: body.assunto,
      descricao: body.descricao ?? null,
      resultado: body.resultado ?? null,
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(inter);
  }),

  http.delete(`${BASE}/:id/interacoes/:interacao_id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (rel) rel.interacoes = (rel.interacoes ?? []).filter((i) => i.id !== Number(params.interacao_id));
    return new HttpResponse(null, { status: 204 });
  }),

  // --------------------------- documentos ---------------------------------
  http.post(`${BASE}/:id/documentos`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (!rel) return HttpResponse.json({ error: "Relação não encontrada" }, { status: 404 });

    const form = await request.formData();
    const arquivo = form.get("arquivo");
    const nomePart = form.get("_original_nome");
    const file = typeof arquivo === "string" ? null : arquivo;
    const nome = (nomePart?.toString() || file?.name || file?.filename || "").split("\\").pop().split("/").pop();
    if (!file || !nome) {
      return HttpResponse.json({ error: 'O documento é obrigatório (campo "arquivo").' }, { status: 400 });
    }
    const ext = (nome.split(".").pop() ?? "").toLowerCase();
    const permitidas = ["pdf", "docx", "xlsx", "png", "jpg", "jpeg", "txt"];
    if (!permitidas.includes(ext)) {
      return HttpResponse.json({ error: "Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT." }, { status: 400 });
    }
    const doc = {
      id: estab.proximos.documento++,
      tipo: form.get("tipo")?.toString() || null,
      data: form.get("data")?.toString() || null,
      referencia: form.get("referencia")?.toString() || null,
      nome_original: nome,
      mime: "application/octet-stream",
      tamanho: file.size ?? 0,
      created_at: new Date().toISOString(),
    };
    rel.documentos = [doc, ...(rel.documentos ?? [])];
    return HttpResponse.json({ id: doc.id, documentos: rel.documentos }, { status: 201 });
  }),

  http.get(`${BASE}/:id/documentos/:documento_id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    const doc = (rel?.documentos ?? []).find((d) => d.id === Number(params.documento_id));
    if (!doc) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });
    return new HttpResponse("conteudo-do-documento-mock", {
      status: 200,
      headers: { "Content-Disposition": `attachment; filename="${doc.nome_original}"` },
    });
  }),

  http.delete(`${BASE}/:id/documentos/:documento_id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const rel = estab.relacoes.find((r) => r.id === Number(params.id));
    if (rel) rel.documentos = (rel.documentos ?? []).filter((d) => d.id !== Number(params.documento_id));
    return new HttpResponse(null, { status: 204 });
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
