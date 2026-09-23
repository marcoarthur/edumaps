// src/features/gestor/mocks/documentosHandlers.js
// MSW handlers do módulo Documentos e Planos Escolares
// (base /api/gestor/:cod_inep/documentos). Exigem sessão do gestor
// (Bearer SESSION_TOKEN) — espelha o backend.
import { http, HttpResponse } from "msw";
import {
  DOCUMENTOS_ARVORE_INICIAL,
  DOCUMENTOS_AUDITORIA_INICIAL,
  INEP_DOCUMENTOS,
} from "./documentosFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep/documentos";

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
      pastas: clone(DOCUMENTOS_ARVORE_INICIAL.pastas),
      documentos: clone(DOCUMENTOS_ARVORE_INICIAL.documentos).map((d) => ({
        ...d,
        versoes: [
          { versao: d.versao_atual, nome_original: d.nome, mime: d.mime, tamanho: d.tamanho, gestor: d.atualizado_por, criado_em: d.atualizado_em },
          ...(d.versao_atual > 1
            ? [{ versao: d.versao_atual - 1, nome_original: d.nome, mime: d.mime, tamanho: 500000, gestor: d.atualizado_por, criado_em: d.criado_em }]
            : []),
        ],
      })),
      auditoria: clone(DOCUMENTOS_AUDITORIA_INICIAL),
      proximos: { pasta: 100, documento: 500 , auditoria: 100 },
    });
  }
  return mem.get(inep);
}

function arvoreOut(estab) {
  const documentos = estab.documentos.map((d) => {
    const { versoes, ...rest } = d;
    const v = versoes[0];
    return { ...rest, versao_atual: v.versao, tamanho: v.tamanho, mime: v.mime, atualizado_por: v.gestor };
  });
  const tags = [...new Set(documentos.flatMap((d) => d.tags ?? []))].sort();
  return { pastas: estab.pastas, documentos, tags };
}

function auditar(estab, { entidade, entidade_id, acao, nome, detalhes }) {
  estab.auditoria.unshift({
    id: estab.proximos.auditoria++,
    entidade,
    entidade_id,
    acao,
    nome,
    gestor: "Marina Souza",
    criado_em: new Date().toISOString(),
    detalhes,
  });
}

function isCiclo(pastas, id, novoPai) {
  if (id === novoPai) return true;
  let atual = novoPai;
  const vistos = new Set();
  while (atual != null) {
    if (atual === id) return true;
    if (vistos.has(atual)) return false;
    vistos.add(atual);
    const p = pastas.find((x) => x.id === atual);
    atual = p ? p.pasta_pai_id : null;
  }
  return false;
}

function docPorId(estab, id) {
  return estab.documentos.find((d) => d.id === id);
}

export const gestorDocumentosHandlers = [
  // ----------------------------- árvore ------------------------------------
  http.get(BASE, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_DOCUMENTOS) {
      return HttpResponse.json({ error: "Escola não encontrada" }, { status: 404 });
    }
    return HttpResponse.json(arvoreOut(stateFor(params.cod_inep)));
  }),

  // --------------------------- feed de atividade ---------------------------
  http.get(`${BASE}/auditoria`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    return HttpResponse.json({ auditoria: stateFor(params.cod_inep).auditoria });
  }),

  // ------------------------------- pastas ----------------------------------
  http.post(`${BASE}/pastas`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const pai = body.pasta_pai_id ? Number(body.pasta_pai_id) : null;
    const nome = String(body.nome ?? "").trim();
    if (!nome || nome.length > 200) {
      return HttpResponse.json({ error: "O nome da pasta é obrigatório (máx. 200 caracteres)." }, { status: 400 });
    }
    if (estab.pastas.some((p) => p.nome.toLowerCase() === nome.toLowerCase() && (p.pasta_pai_id ?? null) === pai)) {
      return HttpResponse.json({ error: "Já existe uma pasta com este nome neste local." }, { status: 409 });
    }
    const pasta = { id: estab.proximos.pasta++, nome, pasta_pai_id: pai, gestor_id: 7, created_at: new Date().toISOString(), updated_at: new Date().toISOString() };
    estab.pastas.push(pasta);
    auditar(estab, { entidade: "pasta", entidade_id: pasta.id, acao: "criado", nome, detalhes: { nome } });
    return HttpResponse.json({ id: pasta.id, nome: pasta.nome, pasta_pai_id: pai }, { status: 201 });
  }),

  http.patch(`${BASE}/pastas/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const pasta = estab.pastas.find((p) => p.id === id);
    if (!pasta) return HttpResponse.json({ error: "Pasta não encontrada" }, { status: 404 });

    if (body.nome !== undefined) {
      const nome = String(body.nome ?? "").trim();
      if (!nome || nome.length > 200) {
        return HttpResponse.json({ error: "O nome da pasta deve ter de 1 a 200 caracteres." }, { status: 400 });
      }
      const pai = pasta.pasta_pai_id ?? null;
      if (estab.pastas.some((p) => p.id !== id && p.nome.toLowerCase() === nome.toLowerCase() && (p.pasta_pai_id ?? null) === pai)) {
        return HttpResponse.json({ error: "Já existe uma pasta com este nome neste local." }, { status: 409 });
      }
      auditar(estab, { entidade: "pasta", entidade_id: id, acao: "renomeado", nome, detalhes: { de: pasta.nome, para: nome } });
      pasta.nome = nome;
    }

    if (body.pasta_pai_id !== undefined) {
      const novoPai = body.pasta_pai_id === "" || body.pasta_pai_id == null ? null : Number(body.pasta_pai_id);
      if (isCiclo(estab.pastas, id, novoPai)) {
        return HttpResponse.json({ error: "A pasta não pode ser movida para dentro dela mesma." }, { status: 409 });
      }
      if (novoPai !== null && !estab.pastas.some((p) => p.id === novoPai)) {
        return HttpResponse.json({ error: "Pasta pai não encontrada." }, { status: 404 });
      }
      auditar(estab, { entidade: "pasta", entidade_id: id, acao: "movido", nome: pasta.nome, detalhes: { de: pasta.pasta_pai_id, para: novoPai } });
      pasta.pasta_pai_id = novoPai;
    }

    pasta.updated_at = new Date().toISOString();
    return HttpResponse.json({ id: pasta.id, nome: pasta.nome, pasta_pai_id: pasta.pasta_pai_id, updated_at: pasta.updated_at });
  }),

  http.delete(`${BASE}/pastas/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const pasta = estab.pastas.find((p) => p.id === id);
    if (!pasta) return HttpResponse.json({ error: "Pasta não encontrada" }, { status: 404 });
    const filhos = estab.pastas.filter((p) => p.pasta_pai_id === id);
    const docs = estab.documentos.filter((d) => d.pasta_id === id);
    if (filhos.length || docs.length) {
      return HttpResponse.json({ error: "A pasta não está vazia. Remova os arquivos e subpastas antes de excluí-la." }, { status: 409 });
    }
    estab.pastas = estab.pastas.filter((p) => p.id !== id);
    auditar(estab, { entidade: "pasta", entidade_id: id, acao: "excluido", nome: pasta.nome, detalhes: { nome: pasta.nome } });
    return new HttpResponse(null, { status: 204 });
  }),

  // ---------------------------- versões / histórico ------------------------
  http.get(`${BASE}/:id/versoes`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const doc = docPorId(stateFor(params.cod_inep), Number(params.id));
    if (!doc) return HttpResponse.json({ versoes: [] });
    return HttpResponse.json({ versoes: [...doc.versoes] });
  }),

  http.get(`${BASE}/:id/historico`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    if (!docPorId(estab, id)) return HttpResponse.json({ historico: [] });
    return HttpResponse.json({ historico: estab.auditoria.filter((a) => a.entidade === "documento" && a.entidade_id === id) });
  }),

  http.get(`${BASE}/:id/download`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const doc = docPorId(estab, id);
    if (!doc) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });
    const url = new URL(request.url);
    const versao = Number(url.searchParams.get("versao") ?? 0);
    const v = doc.versoes.find((x) => x.versao === versao) ?? doc.versoes[0];
    if (!v) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });
    return new HttpResponse(`conteudo-do-documento-v${v.versao}`, {
      status: 200,
      headers: { "Content-Disposition": `attachment; filename="${v.nome_original}"` },
    });
  }),

  // ---------------------------- upload (multipart) -------------------------
  http.post(BASE, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const form = await request.formData();
    const arquivo = form.get("arquivo");
    const file = typeof arquivo === "string" ? null : arquivo;
    const nomePart = form.get("_original_nome");
    const nome = (nomePart?.toString() || file?.name || file?.filename || "").split("/").pop().split("\\").pop();
    if (!file || !nome) {
      return HttpResponse.json({ error: 'O arquivo é obrigatório (campo "arquivo").' }, { status: 400 });
    }
    const ext = (nome.split(".").pop() ?? "").toLowerCase();
    const permitidas = ["pdf", "docx", "xlsx", "png", "jpg", "jpeg", "txt"];
    if (!permitidas.includes(ext)) {
      return HttpResponse.json({ error: "Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT." }, { status: 400 });
    }
    const tags = form.getAll("tags").map((t) => String(t).trim()).filter(Boolean);
    const pastaRaw = form.get("pasta_id");
    const pasta_id = pastaRaw ? Number(pastaRaw) : null;

    const existente = estab.documentos.find((d) => d.nome === nome && (d.pasta_id ?? null) === pasta_id);
    if (existente) {
      const versao = existente.versoes[0].versao + 1;
      existente.versoes.unshift({ versao, nome_original: nome, mime: "application/octet-stream", tamanho: file.size ?? 0, gestor: "Marina Souza", criado_em: new Date().toISOString() });
      existente.tags = tags.length ? tags : existente.tags;
      auditar(estab, { entidade: "documento", entidade_id: existente.id, acao: "sobrescrito", nome, detalhes: { versao, tamanho: file.size ?? 0 } });
      return HttpResponse.json({ documento_id: existente.id, versao, novo: 0, nome, pasta_id }, { status: 201 });
    }

    const doc = {
      id: estab.proximos.documento++,
      pasta_id,
      gestor_id: 7,
      nome,
      tags,
      criado_em: new Date().toISOString(),
      atualizado_em: new Date().toISOString(),
      versoes: [{ versao: 1, nome_original: nome, mime: "application/octet-stream", tamanho: file.size ?? 0, gestor: "Marina Souza", criado_em: new Date().toISOString() }],
    };
    estab.documentos.push(doc);
    auditar(estab, { entidade: "documento", entidade_id: doc.id, acao: "criado", nome, detalhes: { nome, versao: 1, tamanho: file.size ?? 0 } });
    return HttpResponse.json({ documento_id: doc.id, versao: 1, novo: 1, nome, pasta_id }, { status: 201 });
  }),

  // --------------------------- atualizar documento -------------------------
  http.patch(`${BASE}/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const doc = docPorId(estab, id);
    if (!doc) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });

    if (body.nome !== undefined) {
      const nome = String(body.nome ?? "").trim();
      if (!nome || nome.length > 200) {
        return HttpResponse.json({ error: "O nome do documento deve ter de 1 a 200 caracteres." }, { status: 400 });
      }
      const pai = doc.pasta_id ?? null;
      if (estab.documentos.some((d) => d.id !== id && d.nome.toLowerCase() === nome.toLowerCase() && (d.pasta_id ?? null) === pai)) {
        return HttpResponse.json({ error: "Já existe um documento com este nome nesta pasta." }, { status: 409 });
      }
      auditar(estab, { entidade: "documento", entidade_id: id, acao: "renomeado", nome, detalhes: { de: doc.nome, para: nome } });
      doc.nome = nome;
    }

    if (body.pasta_id !== undefined) {
      const novoPai = body.pasta_id === "" || body.pasta_id == null ? null : Number(body.pasta_id);
      if (novoPai !== null && !estab.pastas.some((p) => p.id === novoPai)) {
        return HttpResponse.json({ error: "Pasta não encontrada." }, { status: 404 });
      }
      auditar(estab, { entidade: "documento", entidade_id: id, acao: "movido", nome: doc.nome, detalhes: { de: doc.pasta_id, para: novoPai } });
      doc.pasta_id = novoPai;
    }

    doc.atualizado_em = new Date().toISOString();
    return HttpResponse.json({ id: doc.id, nome: doc.nome, pasta_id: doc.pasta_id, atualizado_em: doc.atualizado_em });
  }),

  // -------------------------------- tags ------------------------------------
  http.put(`${BASE}/:id/tags`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const doc = docPorId(estab, id);
    if (!doc) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });
    const tags = (body.tags ?? []).map((t) => String(t).trim()).filter(Boolean);
    if (tags.some((t) => t.length > 40) || tags.length > 20) {
      return HttpResponse.json({ error: "Tags inválidas: máx. 20 tags de 40 caracteres." }, { status: 400 });
    }
    const anteriores = doc.tags ?? [];
    auditar(estab, {
      entidade: "documento", entidade_id: id, acao: "tags", nome: doc.nome,
      detalhes: { adicionadas: tags.filter((t) => !anteriores.includes(t)), removidas: anteriores.filter((t) => !tags.includes(t)) },
    });
    doc.tags = tags;
    return HttpResponse.json({ tags });
  }),

  // ------------------------------- exclusão --------------------------------
  http.delete(`${BASE}/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const id = Number(params.id);
    const doc = docPorId(estab, id);
    if (!doc) return HttpResponse.json({ error: "Documento não encontrado" }, { status: 404 });
    auditar(estab, { entidade: "documento", entidade_id: id, acao: "excluido", nome: doc.nome, detalhes: { nome: doc.nome } });
    estab.documentos = estab.documentos.filter((d) => d.id !== id);
    return new HttpResponse(null, { status: 204 });
  }),
];