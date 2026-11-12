// src/features/rede/mocks/redeHandlers.js
// MSW da conta de rede (#394): convite (anônimo), /api/rede (sessão REDE_TOKEN;
// a sessão de admin recebe 403) e /api/admin/rede/contas (sessão de admin).
import { http, HttpResponse } from "msw";
import { CONVITES, REDE_TOKEN, REDE_CONTA, REDE_ESCOLAS, ADMIN_REDE_CONTAS, MUNICIPIOS } from "./redeFixtures.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";

const clone = (x) => JSON.parse(JSON.stringify(x));
let convites;
let contas;
let auditoria;
let proximo;
export function resetRedeMock() {
  convites = clone(CONVITES);
  contas = clone(ADMIN_REDE_CONTAS);
  auditoria = {};
  proximo = 700;
}
resetRedeMock();

const auth = (request) => request.headers.get("Authorization") ?? "";
const audita = (id, acao) => (auditoria[id] ??= []).unshift({ id: proximo++, acao, ator: "Admin", detalhes: {}, criado_em: "2026-11-12T12:00:00" });
const tokenNovo = () => `N${String(proximo++).padStart(42, "0")}`;

function exigeAdmin(request) {
  if (auth(request) !== `Bearer ${SESSION_TOKEN}`) {
    return HttpResponse.json({ error: "Acesso restrito a administradores da instalação." }, { status: 403 });
  }
  return null;
}

export const redeHandlers = [
  // --- convite (anônimo) ---
  http.get("/api/rede/convite/:token", ({ params }) => {
    const c = convites[params.token];
    return c ? HttpResponse.json(c) : HttpResponse.json({ error: "Convite não encontrado." }, { status: 404 });
  }),
  http.post("/api/rede/convite/:token", async ({ params, request }) => {
    const { senha } = await request.json();
    const c = convites[params.token];
    if (!c || c.situacao !== "valido") {
      return HttpResponse.json({ error: "Este convite não vale mais (vencido, já usado ou substituído). Peça um novo ao administrador." }, { status: 400 });
    }
    if (!senha || senha.length < 6) return HttpResponse.json({ error: "Dados inválidos" }, { status: 400 });
    c.situacao = "usado";
    return HttpResponse.json({ ok: 1, email: c.email });
  }),

  // --- conta de rede ---
  http.get("/api/rede/me", ({ request }) => {
    if (auth(request) === `Bearer ${REDE_TOKEN}`) return HttpResponse.json(clone(REDE_CONTA));
    if (auth(request) === `Bearer ${SESSION_TOKEN}`) {
      return HttpResponse.json({ error: "Acesso restrito às contas de rede." }, { status: 403 });
    }
    return HttpResponse.json({ error: "Faça login com a conta da rede." }, { status: 401 });
  }),
  http.get("/api/rede/escolas", ({ request }) => {
    if (auth(request) !== `Bearer ${REDE_TOKEN}`) return HttpResponse.json({ error: "Acesso restrito às contas de rede." }, { status: 403 });
    return HttpResponse.json({ escolas: clone(REDE_ESCOLAS) });
  }),

  // --- admin ---
  http.get("/api/admin/rede/contas", ({ request }) => exigeAdmin(request) ?? HttpResponse.json({ contas: clone(contas) })),
  http.post("/api/admin/rede/contas", async ({ request }) => {
    const negado = exigeAdmin(request);
    if (negado) return negado;
    const b = await request.json();
    if (contas.some((c) => c.email === b.email)) {
      return HttpResponse.json({ error: "Este e-mail já tem conta na plataforma." }, { status: 409 });
    }
    const conta = { id: proximo++, nome: b.nome, email: b.email, cargo: b.cargo ?? null, senha_definida: false,
                    convite_pendente: { expira_em: "2026-11-19T12:00:00" }, vinculos: [], criada_em: "2026-11-12T12:00:00" };
    contas.push(conta);
    audita(conta.id, "conta_criada");
    audita(conta.id, "convite_gerado");
    return HttpResponse.json({ conta, convite: { token: tokenNovo(), expira_em: "2026-11-19T12:00:00" } }, { status: 201 });
  }),
  http.post("/api/admin/rede/contas/:id/convite", ({ request, params }) => {
    const negado = exigeAdmin(request);
    if (negado) return negado;
    const c = contas.find((x) => x.id === Number(params.id));
    if (!c) return HttpResponse.json({ error: "Conta de rede não encontrada." }, { status: 404 });
    c.convite_pendente = { expira_em: "2026-11-19T12:00:00" };
    audita(c.id, "convite_gerado");
    return HttpResponse.json({ token: tokenNovo(), expira_em: "2026-11-19T12:00:00" }, { status: 201 });
  }),
  http.post("/api/admin/rede/contas/:id/vinculos", async ({ request, params }) => {
    const negado = exigeAdmin(request);
    if (negado) return negado;
    const c = contas.find((x) => x.id === Number(params.id));
    const { tp_dependencia, co_municipio } = await request.json();
    const mun = MUNICIPIOS[co_municipio];
    if (!mun) return HttpResponse.json({ error: "Município não encontrado no Censo." }, { status: 400 });
    if (c.vinculos.some((v) => v.tp_dependencia === tp_dependencia && v.co_municipio === co_municipio)) {
      return HttpResponse.json({ error: "Esta conta já tem esta rede." }, { status: 409 });
    }
    const v = { id: proximo++, tp_dependencia, dependencia: tp_dependencia === 2 ? "Estadual" : "Municipal",
                co_municipio, municipio: mun.municipio, uf: mun.uf, concedido_em: "2026-11-12T12:00:00" };
    c.vinculos.push(v);
    audita(c.id, "vinculo_concedido");
    return HttpResponse.json(v, { status: 201 });
  }),
  http.delete("/api/admin/rede/contas/:id/vinculos/:vid", ({ request, params }) => {
    const negado = exigeAdmin(request);
    if (negado) return negado;
    const c = contas.find((x) => x.id === Number(params.id));
    c.vinculos = c.vinculos.filter((v) => v.id !== Number(params.vid));
    audita(c.id, "vinculo_revogado");
    return HttpResponse.json({ revogado: true });
  }),
  http.get("/api/admin/rede/contas/:id/auditoria", ({ request, params }) => exigeAdmin(request)
    ?? HttpResponse.json({ auditoria: clone(auditoria[Number(params.id)] ?? []) })),
];
