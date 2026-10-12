// src/features/gestor/mocks/relatoriosHandlers.js
// MSW do Assistente de Relatório (issue #219): recorte-padrão, temas por
// nível, POST de geração (202 {job_id}) e o job, que passa por
// inactive → active → finished (ou failed) a cada consulta.
import { http, HttpResponse } from "msw";
import { SESSION_TOKEN } from "./fixtures.js";
import {
  RECORTE_PADRAO_FIXTURE,
  TEMAS_FIXTURE,
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_LLM_INDISPONIVEL_FIXTURE,
  RELATORIOS_POR_TEMA_FIXTURE,
} from "./relatoriosFixtures.js";

const BASE = "/api/gestor/:cod_inep/relatorios";

const GEOTAG_RE = {
  municipio: /^\d{7}$/,
  uf: /^[A-Z]{2}$/,
  regiao: /^(N|NE|SE|S|CO)$/,
  escola: /^\d{8}$/,
};

const PADRAO = () => ({
  // consultas até o fim: 1ª → inactive, 2ª → active, 3ª → final
  consultasAteFim: 3,
  falha: null, // mensagem → job failed
  llmIndisponivel: false,
  cacheHit: false,
});

let config = PADRAO();
let jobs = new Map();
let proximoJob = 900;
let pedidos = [];

export function resetRelatoriosMockState() {
  config = PADRAO();
  jobs = new Map();
  proximoJob = 900;
  pedidos = [];
}

/** Ajusta o comportamento dos próximos jobs (falha, llm, cache, ritmo). */
export function configurarRelatoriosMock(parcial = {}) {
  config = { ...config, ...parcial };
}

/** Corpos dos POST recebidos (para os testes conferirem o geotag). */
export function getPedidosRelatorioMock() {
  return pedidos;
}

/** Quantas vezes o job foi consultado. */
export function getConsultasJobMock(id) {
  return jobs.get(Number(id))?.consultas ?? 0;
}

const naoAutorizado = (request) =>
  (request.headers.get("Authorization") ?? "") !== `Bearer ${SESSION_TOKEN}`;

const erro401 = () => HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 });
const erro400 = (msg) => HttpResponse.json({ error: msg }, { status: 400 });

export const gestorRelatoriosHandlers = [
  http.get(`${BASE}/recorte-padrao`, ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    return HttpResponse.json({
      ...RECORTE_PADRAO_FIXTURE,
      escola: { ...RECORTE_PADRAO_FIXTURE.escola, cod_inep: String(params.cod_inep) },
    });
  }),

  http.get(`${BASE}/temas`, ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    const nivel = new URL(request.url).searchParams.get("nivel");
    const temas = nivel ? TEMAS_FIXTURE.filter((t) => t.niveis.includes(nivel)) : TEMAS_FIXTURE;
    return HttpResponse.json({ temas });
  }),

  http.post(BASE, async ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    const body = await request.json();
    pedidos.push(body);
    const { geotag, tema } = body ?? {};
    const re = GEOTAG_RE[geotag?.nivel];
    if (!re || !re.test(String(geotag?.codigo ?? ""))) return erro400("Recorte inválido.");
    if (geotag.nivel === "escola" && String(geotag.codigo) !== String(params.cod_inep)) {
      return erro400("Só é possível gerar relatório da sua escola.");
    }
    const def = TEMAS_FIXTURE.find((t) => t.id === tema);
    if (!def || !def.niveis.includes(geotag.nivel)) {
      return erro400("Tema indisponível para este nível.");
    }
    const id = proximoJob++;
    jobs.set(id, { id, consultas: 0, config: { ...config }, pedido: body });
    return HttpResponse.json({ job_id: id }, { status: 202 });
  }),

  http.get(`${BASE}/jobs/:job_id`, ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    const job = jobs.get(Number(params.job_id));
    if (!job) return HttpResponse.json({ error: "Job não encontrado." }, { status: 404 });
    job.consultas += 1;
    const c = job.config;
    if (job.consultas < c.consultasAteFim) {
      const state = job.consultas === 1 ? "inactive" : "active";
      return HttpResponse.json({ state, progress: state === "active" ? 50 : 0 });
    }
    if (c.falha) return HttpResponse.json({ state: "failed", error: c.falha });
    const base = c.llmIndisponivel
      ? RELATORIO_LLM_INDISPONIVEL_FIXTURE
      : (RELATORIOS_POR_TEMA_FIXTURE[job.pedido?.tema] ?? RELATORIO_RESULT_FIXTURE);
    return HttpResponse.json({
      state: "finished",
      progress: 100,
      result: { ...base, cache_hit: !!c.cacheHit },
    });
  }),
];
