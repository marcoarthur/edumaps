// src/features/gestor/mocks/handlers.js
// MSW handlers do módulo de pesquisas do gestor (base /api/gestor/pesquisas).
import { http, HttpResponse } from "msw";
import { GESTOR_SURVEY_PERFIL, SURVEY_FIXTURES, SURVEY_DETAIL } from "./fixtures.js";

const BASE = "/api/gestor/pesquisas";

export const gestorPesquisasHandlers = [
  // upsert do gestor por e-mail
  http.post(`${BASE}/perfil`, async ({ request }) => {
    const body = await request.json();
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

  // detail
  http.get(`${BASE}/:id`, ({ params }) => {
    if (params.id === "1") return HttpResponse.json(SURVEY_DETAIL);
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
];