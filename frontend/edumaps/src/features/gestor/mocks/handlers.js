// src/features/gestor/mocks/handlers.js
// MSW handlers do módulo de pesquisas do gestor (base /api/gestor/pesquisas).
// Fase 2: token público, login do gestor e resultados.
import { http, HttpResponse } from "msw";
import {
  GESTOR_SURVEY_PERFIL,
  SURVEY_FIXTURES,
  SURVEY_DETAIL,
  SURVEY_PUBLIC_FORM,
  PUBLIC_TOKEN,
  SESSION_TOKEN,
  SESSION_GESTOR,
  RESULTADOS_FIXTURE,
} from "./fixtures.js";

const BASE = "/api/gestor/pesquisas";

const answeredDispositivos = new Set();

export const gestorPesquisasHandlers = [
  // upsert do gestor por e-mail (fase 2: senha obrigatória)
  http.post(`${BASE}/perfil`, async ({ request }) => {
    const body = await request.json();
    if (!body.senha || body.senha.length < 6) {
      return HttpResponse.json({ error: "Senha com mínimo de 6 caracteres." }, { status: 400 });
    }
    return HttpResponse.json({
      ...GESTOR_SURVEY_PERFIL,
      nome: body.nome,
      email: body.email,
      telefone: body.telefone ?? GESTOR_SURVEY_PERFIL.telefone,
      cargo: body.cargo ?? GESTOR_SURVEY_PERFIL.cargo,
    });
  }),

  // lista por escola
  http.get(BASE, ({ request }) => {
    const url = new URL(request.url);
    const inep = url.searchParams.get("inep");
    if (!inep) {
      return HttpResponse.json({ error: "inep é obrigatório" }, { status: 400 });
    }
    if (inep !== "11000040") return HttpResponse.json([]);
    return HttpResponse.json(SURVEY_FIXTURES);
  }),

  // create (rascunho)
  http.post(BASE, async ({ request }) => {
    const body = await request.json();
    if (!body.gestor_id) {
      return HttpResponse.json({ error: "gestor_id é obrigatório" }, { status: 400 });
    }
    const created = {
      ...SURVEY_DETAIL,
      id: 99,
      titulo: body.titulo,
      descricao: body.descricao ?? null,
      status: "rascunho",
      perguntas: (body.perguntas ?? []).map((p, i) => ({
        id: 900 + i,
        ordem: i + 1,
        texto: p.texto,
        tipo: p.tipo,
        obrigatoria: !!p.obrigatoria,
        opcoes: p.opcoes ?? null,
      })),
    };
    return HttpResponse.json(created, { status: 201 });
  }),

  // ---- fase 2: link público (ANTES de /:id para o match @ msw) -----------
  http.get(`${BASE}/publica/:token`, ({ params }) => {
    if (params.token !== PUBLIC_TOKEN) {
      return HttpResponse.json({ error: "Pesquisa não encontrada ou não publicada" }, { status: 404 });
    }
    return HttpResponse.json(SURVEY_PUBLIC_FORM);
  }),

  http.post(`${BASE}/publica/:token/resposta`, async ({ params, request }) => {
    if (params.token !== PUBLIC_TOKEN) {
      return HttpResponse.json({ error: "Pesquisa não encontrada ou não aberta" }, { status: 404 });
    }
    const body = await request.json();
    if (answeredDispositivos.has(body.identificador_dispositivo)) {
      return HttpResponse.json(
        { error: "Você já respondeu esta pesquisa neste dispositivo." },
        { status: 409 },
      );
    }
    answeredDispositivos.add(body.identificador_dispositivo);
    return HttpResponse.json({ ok: true, id: 500 }, { status: 201 });
  }),

  // ---- fase 2: resultados (exige sessão do gestor da escola) -------------
  http.get(`${BASE}/:id/resultados`, ({ request }) => {
    const auth = request.headers.get("Authorization") ?? "";
    if (auth !== `Bearer ${SESSION_TOKEN}`) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    return HttpResponse.json(RESULTADOS_FIXTURE);
  }),

  // detail
  http.get(`${BASE}/:id`, ({ params }) => {
    if (params.id === "1") return HttpResponse.json(SURVEY_DETAIL);
    if (params.id === "2") {
      return HttpResponse.json({ ...SURVEY_PUBLIC_FORM, status: "publicada" });
    }
    return HttpResponse.json({ error: "Pesquisa não encontrada" }, { status: 404 });
  }),

  // update (autosave)
  http.put(`${BASE}/:id`, async ({ params, request }) => {
    const body = await request.json();
    return HttpResponse.json({
      ...SURVEY_DETAIL,
      id: Number(params.id),
      titulo: body.titulo,
      descricao: body.descricao ?? null,
      perguntas: (body.perguntas ?? []).map((p, i) => ({
        id: 900 + i,
        ordem: i + 1,
        texto: p.texto,
        tipo: p.tipo,
        obrigatoria: !!p.obrigatoria,
        opcoes: p.opcoes ?? null,
      })),
    });
  }),

  // finalizar
  http.post(`${BASE}/:id/finalizar`, () => {
    return HttpResponse.json({ ...SURVEY_DETAIL, id: 1, status: "publicada" });
  }),

  // delete (só rascunho)
  http.delete(`${BASE}/:id`, () => {
    return new HttpResponse(null, { status: 204 });
  }),

  // ---- fase 2: autenticação do gestor ------------------------------------
  http.post("/api/gestor/login", async ({ request }) => {
    const body = await request.json();
    if (body.email !== SESSION_GESTOR.email || body.senha !== "senha123") {
      return HttpResponse.json({ error: "E-mail ou senha inválidos" }, { status: 401 });
    }
    return HttpResponse.json({
      token: SESSION_TOKEN,
      expira_em: "2026-10-19T00:00:00",
      gestor: SESSION_GESTOR,
    });
  }),

  http.get("/api/gestor/me", ({ request }) => {
    const auth = request.headers.get("Authorization") ?? "";
    if (auth !== `Bearer ${SESSION_TOKEN}`) {
      return HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
    }
    return HttpResponse.json(SESSION_GESTOR);
  }),

  http.post("/api/gestor/logout", () => {
    return new HttpResponse(null, { status: 204 });
  }),
];