// src/features/gestor/mocks/reunioesHandlers.js
// MSW handlers do módulo Reuniões & Atas (base /api/gestor/:cod_inep).
// Exigem a sessão do gestor (Bearer SESSION_TOKEN) — espelha o backend.
import { http, HttpResponse } from "msw";
import {
  CONTATOS_FIXTURE,
  GRUPOS_FIXTURE,
  REUNIOES_FIXTURE,
  REUNIAO_DETAIL,
  INEP_REUNIOES,
} from "./reunioesFixtures.js";
import { SESSION_TOKEN } from "./fixtures.js";

const BASE = "/api/gestor/:cod_inep";

function okAuth(request, { code = 401 } = {}) {
  const auth = request.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Faça login como gestor." }, { status: code });
  }
  return null;
}

// Estado em memória por escola (contatos, grupos, reuniões) para as páginas
// poderem criar/atualizar sem recarregar.
const mem = new Map();
function stateFor(inep) {
  if (!mem.has(inep)) {
    let nextContato = 100;
    let nextGrupo = 100;
    let nextReuniao = 500;
    mem.set(inep, {
      contatos: CONTATOS_FIXTURE.map((c) => ({ ...c })),
      grupos: GRUPOS_FIXTURE.map((g) => ({ ...g })),
      reunioes: REUNIOES_FIXTURE.map((r) => ({ ...r })),
      proximos: { contato: nextContato, grupo: nextGrupo, reuniao: nextReuniao },
    });
  }
  return mem.get(inep);
}

export const gestorReunioesHandlers = [
  // ---------------------------- contatos -----------------------------------
  http.get(`${BASE}/contatos`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    if (params.cod_inep !== INEP_REUNIOES) return HttpResponse.json([]);
    return HttpResponse.json(stateFor(params.cod_inep).contatos);
  }),

  http.post(`${BASE}/contatos`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.nome || body.nome.trim().length < 1) {
      return HttpResponse.json({ error: "Informe o nome do contato." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    const id = estab.proximos.contato++;
    const contato = {
      id,
      nome: body.nome,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      cargo: body.cargo ?? null,
      grupo_id: body.grupo_id ?? null,
      grupo_nome: estab.grupos.find((g) => g.id === body.grupo_id)?.nome ?? null,
      updated_at: new Date().toISOString(),
    };
    estab.contatos.push(contato);
    return HttpResponse.json(contato, { status: 201 });
  }),

  http.put(`${BASE}/contatos/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const contato = estab.contatos.find((c) => c.id === Number(params.id));
    if (!contato) {
      return HttpResponse.json({ error: "Contato não encontrado" }, { status: 404 });
    }
    Object.assign(contato, {
      nome: body.nome,
      email: body.email ?? null,
      telefone: body.telefone ?? null,
      cargo: body.cargo ?? null,
      grupo_id: body.grupo_id ?? null,
      grupo_nome: estab.grupos.find((g) => g.id === body.grupo_id)?.nome ?? null,
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(contato);
  }),

  http.delete(`${BASE}/contatos/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.contatos.findIndex((c) => c.id === Number(params.id));
    if (idx === -1) return new HttpResponse(null, { status: 204 });
    estab.contatos.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  http.post(`${BASE}/contatos/import`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!Array.isArray(body.contatos)) {
      return HttpResponse.json({ error: "contatos deve ser uma lista" }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    let nInseridos = 0;
    for (const c of body.contatos.slice(0, 200)) {
      if (!c.nome) continue;
      let grupoId = null;
      if (c.grupo) {
        const grupo = estab.grupos.find((g) => g.nome.toLowerCase() === c.grupo.toLowerCase());
        if (grupo) {
          grupoId = grupo.id;
          grupo.n_contatos += 1;
        } else {
          grupoId = estab.proximos.grupo++;
          estab.grupos.push({ id: grupoId, nome: c.grupo, origem: "manual", n_contatos: 1, created_at: new Date().toISOString() });
        }
      }
      estab.contatos.push({
        id: estab.proximos.contato++,
        nome: c.nome,
        email: c.email ?? null,
        telefone: c.telefone ?? null,
        cargo: c.cargo ?? null,
        grupo_id: grupoId,
        grupo_nome: c.grupo ?? null,
        updated_at: new Date().toISOString(),
      });
      nInseridos += 1;
    }
    return HttpResponse.json({ n_inseridos: nInseridos, n_pulados: 0 });
  }),

  // ----------------------------- grupos ------------------------------------
  http.get(`${BASE}/grupos`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    return HttpResponse.json(stateFor(params.cod_inep).grupos);
  }),

  http.post(`${BASE}/grupos`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.nome || !body.nome.trim()) {
      return HttpResponse.json({ error: "Informe o nome do grupo." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    const grupo = {
      id: estab.proximos.grupo++,
      nome: body.nome,
      origem: "manual",
      n_contatos: 0,
      created_at: new Date().toISOString(),
    };
    estab.grupos.push(grupo);
    return HttpResponse.json(grupo, { status: 201 });
  }),

  http.put(`${BASE}/grupos/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const grupo = estab.grupos.find((g) => g.id === Number(params.id));
    if (!grupo) {
      return HttpResponse.json({ error: "Grupo não encontrado" }, { status: 404 });
    }
    grupo.nome = body.nome;
    return HttpResponse.json(grupo);
  }),

  http.delete(`${BASE}/grupos/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.grupos.findIndex((g) => g.id === Number(params.id));
    if (idx === -1) return new HttpResponse(null, { status: 204 });
    estab.grupos.splice(idx, 1);
    return new HttpResponse(null, { status: 204 });
  }),

  // ----------------------------- reuniões ----------------------------------
  http.get(`${BASE}/reunioes`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    let lista = stateFor(params.cod_inep).reunioes;
    const url = new URL(request.url);
    const q = url.searchParams.get("q");
    const status = url.searchParams.get("status");
    if (q) lista = lista.filter((r) => r.titulo.toLowerCase().includes(q.toLowerCase()));
    if (status) lista = lista.filter((r) => r.status === status);
    return HttpResponse.json(lista);
  }),

  http.post(`${BASE}/reunioes`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    if (!body.titulo || body.titulo.trim().length < 3 || !body.quando) {
      return HttpResponse.json({ error: "Título e data/hora são obrigatórios." }, { status: 400 });
    }
    const estab = stateFor(params.cod_inep);
    const id = estab.proximos.reuniao++;
    const reuniao = {
      id,
      titulo: body.titulo,
      quando: body.quando.replace(" ", "T") + ":00",
      duracao_min: body.duracao_min ?? 60,
      onde_label: body.onde_label ?? null,
      onde_link: body.onde_link ?? null,
      aviso_metodo: body.aviso_metodo ?? "todos",
      pauta_texto: body.pauta_texto ?? null,
      status: "agendada",
      n_participantes: (body.contato_ids ?? []).length,
      tem_ata: 0,
      anexos: [],
      participantes: [],
      gestor: { nome: "Marina Souza" },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    estab.reunioes.unshift(reuniao);
    return HttpResponse.json(reuniao, { status: 201 });
  }),

  http.get(`${BASE}/reunioes/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const encontrada = stateFor(params.cod_inep).reunioes.find(
      (r) => r.id === Number(params.id),
    );
    if (!encontrada) {
      return HttpResponse.json({ error: "Reunião não encontrada" }, { status: 404 });
    }
    return HttpResponse.json({ ...REUNIAO_DETAIL, ...encontrada });
  }),

  http.put(`${BASE}/reunioes/:id`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    if (!reuniao) {
      return HttpResponse.json({ error: "Reunião não encontrada" }, { status: 404 });
    }
    Object.assign(reuniao, {
      titulo: body.titulo,
      quando: body.quando.replace(" ", "T") + ":00",
      duracao_min: body.duracao_min ?? 60,
      onde_label: body.onde_label ?? null,
      onde_link: body.onde_link ?? null,
      aviso_metodo: body.aviso_metodo ?? "todos",
      pauta_texto: body.pauta_texto ?? null,
      n_participantes: (body.contato_ids ?? []).length,
      updated_at: new Date().toISOString(),
    });
    return HttpResponse.json(reuniao);
  }),

  http.post(`${BASE}/reunioes/:id/ata`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const body = await request.json();
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    if (!reuniao) {
      return HttpResponse.json({ error: "Reunião não encontrada" }, { status: 404 });
    }
    reuniao.ata_texto = body.ata_texto;
    reuniao.tem_ata = body.ata_texto ? 1 : 0;
    reuniao.updated_at = new Date().toISOString();
    return HttpResponse.json({ ...REUNIAO_DETAIL, ...reuniao });
  }),

  http.post(`${BASE}/reunioes/:id/marcar-realizada`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    if (!reuniao || reuniao.status !== "agendada") {
      return HttpResponse.json({ error: "Só reuniões agendadas podem ser marcadas como realizadas" }, { status: 409 });
    }
    reuniao.status = "realizada";
    reuniao.updated_at = new Date().toISOString();
    return HttpResponse.json({ ...REUNIAO_DETAIL, ...reuniao });
  }),

  http.post(`${BASE}/reunioes/:id/cancelar`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    if (!reuniao || reuniao.status !== "agendada") {
      return HttpResponse.json({ error: "Só reuniões agendadas podem ser canceladas" }, { status: 409 });
    }
    reuniao.status = "cancelada";
    reuniao.updated_at = new Date().toISOString();
    return HttpResponse.json({ ...REUNIAO_DETAIL, ...reuniao });
  }),

  http.delete(`${BASE}/reunioes/:id`, ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const idx = estab.reunioes.findIndex((r) => r.id === Number(params.id));
    if (idx !== -1 && estab.reunioes[idx].status !== "realizada") {
      estab.reunioes.splice(idx, 1);
    }
    return new HttpResponse(null, { status: 204 });
  }),

  // ------------------------------ anexos -----------------------------------
  // Upload multipart: campo "arquivo". Registra/sobrescreve por tipo.
  http.post(`${BASE}/reunioes/:id/anexos/:tipo`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    if (!reuniao) {
      return HttpResponse.json({ error: "Reunião inexistente" }, { status: 404 });
    }
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
    const demais = (reuniao.anexos ?? []).filter((a) => a.tipo !== params.tipo);
    reuniao.anexos = [
      ...demais,
      { id: Date.now(), tipo: params.tipo, nome_original: nome, mime: "application/octet-stream", tamanho: file.size ?? 0, criado_em: new Date().toISOString() },
    ];
    reuniao.updated_at = new Date().toISOString();
    return HttpResponse.json({ ...REUNIAO_DETAIL, ...reuniao, anexos: reuniao.anexos }, { status: 201 });
  }),

  http.get(`${BASE}/reunioes/:id/anexos/:tipo`, async ({ request, params }) => {
    const denied = okAuth(request);
    if (denied) return denied;
    const estab = stateFor(params.cod_inep);
    const reuniao = estab.reunioes.find((r) => r.id === Number(params.id));
    const anexo = (reuniao?.anexos ?? []).find((a) => a.tipo === params.tipo);
    if (!anexo) {
      return HttpResponse.json({ error: "Anexo não encontrado" }, { status: 404 });
    }
    return new HttpResponse("conteudo-do-anexo-mock", {
      status: 200,
      headers: { "Content-Disposition": `attachment; filename="${anexo.nome_original}"` },
    });
  }),
];