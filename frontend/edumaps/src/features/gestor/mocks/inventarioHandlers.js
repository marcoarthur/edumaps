// src/features/gestor/mocks/inventarioHandlers.js
// MSW handlers do Painel de Inventário Escolar (base /api/gestor/:cod_inep).
// Exigem a sessão do gestor (Bearer SESSION_TOKEN) — espelha o backend.
import { http, HttpResponse } from "msw";
import {
  CENSO_INVENTARIO,
  CATEGORIAS_INVENTARIO,
  FORNECEDORES_INVENTARIO,
  ITENS_INVENTARIO,
  INEP_INVENTARIO,
} from "./inventarioFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/inventario";

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
      categorias: clone(CATEGORIAS_INVENTARIO),
      fornecedores: clone(FORNECEDORES_INVENTARIO),
      itens: clone(ITENS_INVENTARIO).map((i) => ({ ...i, anexos: i.n_anexos ? [{ id: 1, nome_original: "nota-giz.pdf", mime: "application/pdf", tamanho: 1234, created_at: "2026-09-20T10:00:00" }] : [] })),
      proximos: { categoria: 100, fornecedor: 100, item: 500, anexo: 100 },
    });
  }
  return mem.get(inep);
}

function catNome(estab, id) {
  return estab.categorias.find((c) => c.id === id)?.nome ?? null;
}
function catTipo(estab, id) {
  return estab.categorias.find((c) => c.id === id)?.tipo ?? null;
}
function fornNome(estab, id) {
  return estab.fornecedores.find((f) => f.id === id)?.nome ?? null;
}

function itemOut(estab, item) {
  const { anexos, ...rest } = item;
  return {
    ...rest,
    categoria_nome: catNome(estab, item.categoria_id),
    categoria_tipo: catTipo(estab, item.categoria_id),
    fornecedor_nome: item.fornecedor_id ? fornNome(estab, item.fornecedor_id) : null,
    n_anexos: (anexos ?? []).length,
  };
}

export const gestorInventarioHandlers = [
  // ------------------------- visão geral -----------------------------------
  http.get(BASE, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_INVENTARIO) {
      return HttpResponse.json({ error: "Escola não encontrada" }, { status: 404 });
    }
    const estab = stateFor(params.cod_inep);
    return HttpResponse.json({
      ano: CENSO_INVENTARIO.ano,
      censo: CENSO_INVENTARIO,
      categorias: estab.categorias,
      fornecedores: estab.fornecedores,
      itens: estab.itens.map((i) => itemOut(estab, i)),
    });
  }),

  http.post(`${BASE}/importar-censo`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    let importados = 0;
    for (const grupo of CENSO_INVENTARIO.grupos) {
      for (const it of grupo.itens) {
        if (estab.itens.some((i) => i.censo_ref === it.key)) continue;
        const cat = estab.categorias.find((c) => c.nome === it.categoria);
        if (!cat) continue;
        estab.itens.push({
          id: estab.proximos.item++,
          nome: it.label,
          descricao: null,
          quantidade: it.qtd || 1,
          unidade: null,
          estado: null,
          identificador: null,
          periodicidade: null,
          valor: null,
          data_aquisicao: null,
          censo_ref: it.key,
          atributos: { origem: "censo", grupo: grupo.label },
          categoria_id: cat.id,
          fornecedor_id: null,
          anexos: [],
        });
        importados += 1;
      }
    }
    return HttpResponse.json({ importados, ano: CENSO_INVENTARIO.ano });
  }),

  // ---------------------------- categorias ---------------------------------
  http.post(`${BASE}/categorias`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.nome || !body.tipo) {
      return HttpResponse.json({ error: "Informe tipo e nome da categoria." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    if (estab.categorias.some((c) => c.tipo === body.tipo && c.nome.toLowerCase() === body.nome.toLowerCase())) {
      return HttpResponse.json({ error: "Já existe uma categoria com este nome para este tipo." }, { status: 409 });
    }
    const cat = { id: estab.proximos.categoria++, tipo: body.tipo, nome: body.nome, origem: "manual", n_itens: 0 };
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
    cat.tipo = body.tipo;
    cat.nome = body.nome;
    return HttpResponse.json(cat);
  }),

  http.delete(`${BASE}/categorias/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    if (estab.itens.some((i) => i.categoria_id === id)) {
      return HttpResponse.json({ error: "Não é possível excluir: a categoria tem itens no inventário." }, { status: 409 });
    }
    const idx = estab.categorias.findIndex((c) => c.id === id);
    if (idx !== -1) estab.categorias.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // --------------------------- fornecedores --------------------------------
  http.post(`${BASE}/fornecedores`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.nome || !body.nome.trim()) {
      return HttpResponse.json({ error: "Informe o nome do fornecedor." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    if (estab.fornecedores.some((f) => f.nome.toLowerCase() === body.nome.toLowerCase())) {
      return HttpResponse.json({ error: "Já existe um fornecedor com este nome nesta escola." }, { status: 409 });
    }
    const f = {
      id: estab.proximos.fornecedor++,
      nome: body.nome,
      tipo_servico: body.tipo_servico ?? null,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      site: body.site ?? null,
      documento: body.documento ?? null,
      observacoes: body.observacoes ?? null,
      atributos: body.atributos ?? {},
      n_itens: 0,
      updated_at: new Date().toISOString(),
    };
    estab.fornecedores.push(f);
    return HttpResponse.json(f, { status: 201 });
  }),

  http.put(`${BASE}/fornecedores/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const f = estab.fornecedores.find((x) => x.id === Number(params.id));
    if (!f) return HttpResponse.json({ error: "Fornecedor não encontrado" }, { status: 404 });
    Object.assign(f, {
      nome: body.nome,
      tipo_servico: body.tipo_servico ?? null,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      site: body.site ?? null,
      documento: body.documento ?? null,
      observacoes: body.observacoes ?? null,
      atributos: body.atributos ?? {},
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(f);
  }),

  http.delete(`${BASE}/fornecedores/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.fornecedores.findIndex((f) => f.id === Number(params.id));
    if (idx !== -1) estab.fornecedores.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // ------------------------------- itens -----------------------------------
  http.get(`${BASE}/itens`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const url = new URL(request.url);
    const tipo = url.searchParams.get("tipo");
    const categoria = url.searchParams.get("categoria_id");
    const q = url.searchParams.get("q");
    let lista = estab.itens.map((i) => itemOut(estab, i));
    if (tipo) lista = lista.filter((i) => i.categoria_tipo === tipo);
    if (categoria) lista = lista.filter((i) => i.categoria_id === Number(categoria));
    if (q) lista = lista.filter((i) => i.nome.toLowerCase().includes(q.toLowerCase()));
    return HttpResponse.json(lista);
  }),

  http.post(`${BASE}/itens`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.categoria_id || !body.nome) {
      return HttpResponse.json({ error: "Informe categoria e nome do item." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    const item = {
      id: estab.proximos.item++,
      nome: body.nome,
      descricao: body.descricao ?? null,
      quantidade: body.quantidade ?? 1,
      unidade: body.unidade ?? null,
      estado: body.estado ?? null,
      identificador: body.identificador ?? null,
      periodicidade: body.periodicidade ?? null,
      valor: body.valor ?? null,
      data_aquisicao: body.data_aquisicao ?? null,
      censo_ref: null,
      atributos: body.atributos ?? {},
      categoria_id: body.categoria_id,
      fornecedor_id: body.fornecedor_id ?? null,
      anexos: [],
    };
    estab.itens.push(item);
    return HttpResponse.json({ ...itemOut(estab, item), anexos: [] }, { status: 201 });
  }),

  http.get(`${BASE}/itens/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const item = estab.itens.find((i) => i.id === Number(params.id));
    if (!item) return HttpResponse.json({ error: "Item não encontrado" }, { status: 404 });
    return HttpResponse.json({ ...itemOut(estab, item), anexos: item.anexos ?? [] });
  }),

  http.put(`${BASE}/itens/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const item = estab.itens.find((i) => i.id === Number(params.id));
    if (!item) return HttpResponse.json({ error: "Item não encontrado" }, { status: 404 });
    Object.assign(item, {
      nome: body.nome,
      descricao: body.descricao ?? null,
      quantidade: body.quantidade ?? 1,
      unidade: body.unidade ?? null,
      estado: body.estado ?? null,
      identificador: body.identificador ?? null,
      periodicidade: body.periodicidade ?? null,
      valor: body.valor ?? null,
      data_aquisicao: body.data_aquisicao ?? null,
      atributos: body.atributos ?? {},
      categoria_id: body.categoria_id,
      fornecedor_id: body.fornecedor_id ?? null,
    });
    return HttpResponse.json({ ...itemOut(estab, item), anexos: item.anexos ?? [] });
  }),

  http.delete(`${BASE}/itens/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.itens.findIndex((i) => i.id === Number(params.id));
    if (idx !== -1) estab.itens.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // ------------------------------ anexos -----------------------------------
  http.post(`${BASE}/itens/:id/anexos`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const item = estab.itens.find((i) => i.id === Number(params.id));
    if (!item) return HttpResponse.json({ error: "Item não encontrado" }, { status: 404 });
    const form = await request.formData();
    const arquivo = form.get("arquivo");
    const nomePart = form.get("_original_nome");
    const file = typeof arquivo === "string" ? null : arquivo;
    const nome = (nomePart?.toString() || file?.name || file?.filename || "")
      .split("\\")
      .pop()
      .split("/")
      .pop();
    if (!file || !nome) {
      return HttpResponse.json({ error: 'O anexo é obrigatório (campo "arquivo").' }, { status: 400 });
    }
    const ext = (nome.split(".").pop() ?? "").toLowerCase();
    const permitidas = ["pdf", "docx", "xlsx", "png", "jpg", "jpeg", "txt"];
    if (!permitidas.includes(ext)) {
      return HttpResponse.json({ error: "Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT." }, { status: 400 });
    }
    const anexo = {
      id: estab.proximos.anexo++,
      nome_original: nome,
      mime: "application/octet-stream",
      tamanho: file.size ?? 0,
      created_at: new Date().toISOString(),
    };
    item.anexos = [...(item.anexos ?? []), anexo];
    return HttpResponse.json({ id: anexo.id, anexos: item.anexos }, { status: 201 });
  }),

  http.get(`${BASE}/itens/:id/anexos/:anexo_id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const item = estab.itens.find((i) => i.id === Number(params.id));
    const anexo = (item?.anexos ?? []).find((a) => a.id === Number(params.anexo_id));
    if (!anexo) return HttpResponse.json({ error: "Anexo não encontrado" }, { status: 404 });
    return new HttpResponse("conteudo-do-anexo-mock", {
      status: 200,
      headers: { "Content-Disposition": `attachment; filename="${anexo.nome_original}"` },
    });
  }),

  http.delete(`${BASE}/itens/:id/anexos/:anexo_id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const item = estab.itens.find((i) => i.id === Number(params.id));
    if (item) item.anexos = (item.anexos ?? []).filter((a) => a.id !== Number(params.anexo_id));
    return new HttpResponse(null, { status: 204 });
  }),
];
