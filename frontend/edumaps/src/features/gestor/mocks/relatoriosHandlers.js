// src/features/gestor/mocks/relatoriosHandlers.js
// MSW do Assistente de Relatório (issue #219; salvos na fase 3): recorte-padrão, temas por
// nível, POST de geração (202 {job_id}) e o job, que passa por
// inactive → active → finished (ou failed) a cada consulta.
// Fase 4: assistentes (`relatorio` no modo tema e `eda_municipio` no modo
// composto), `?assistente` nos temas e `assistente` no POST e nos salvos.
import { http, HttpResponse } from "msw";
import { SESSION_TOKEN } from "./fixtures.js";
import {
  RECORTE_PADRAO_FIXTURE,
  TEMAS_FIXTURE,
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_LLM_INDISPONIVEL_FIXTURE,
  RELATORIOS_POR_TEMA_FIXTURE,
  ASSISTENTES_FIXTURE,
  RELATORIO_EDA_FIXTURE,
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
// fase 3: relatórios salvos do gestor da sessão (mais recentes no fim)
let salvos = [];
let proximoSalvo = 1;

export function resetRelatoriosMockState() {
  config = PADRAO();
  jobs = new Map();
  proximoJob = 900;
  pedidos = [];
  salvos = [];
  proximoSalvo = 1;
}

/** Relatórios salvos no mock (para os testes conferirem). */
export function getSalvosMock() {
  return salvos;
}

function resumoSalvo(s) {
  const { relatorio, job_id, ...resumo } = s;
  return resumo;
}

const assistentePorId = (id) => ASSISTENTES_FIXTURE.find((a) => a.id === (id || "relatorio")) ?? null;

function assistenteResumo(id) {
  const a = assistentePorId(id) ?? assistentePorId("relatorio");
  return { id: a.id, titulo: a.titulo };
}

function criarSalvo({ jobId, pedido, relatorio, salvoEm }) {
  const { cache_hit, ...conteudo } = relatorio ?? {};
  const salvo = {
    id: proximoSalvo++,
    job_id: jobId,
    titulo: conteudo.titulo,
    tema: { id: pedido?.tema ?? conteudo.tema?.id, titulo: conteudo.tema?.titulo },
    assistente: assistenteResumo(pedido?.assistente ?? conteudo.assistente?.id),
    recorte: {
      nivel: pedido?.geotag?.nivel ?? conteudo.recorte?.nivel,
      codigo: String(pedido?.geotag?.codigo ?? conteudo.recorte?.codigo ?? ""),
      nome: conteudo.recorte?.nome ?? null,
    },
    opcoes: pedido?.opcoes ?? {},
    gerado_em: conteudo.gerado_em,
    salvo_em: salvoEm ?? new Date(Date.UTC(2026, 9, 12, 13, 0, 0) + salvos.length * 60000).toISOString(),
    relatorio: conteudo,
  };
  salvos.push(salvo);
  return salvo;
}

/**
 * Semeia relatórios salvos (sem passar por um job). Cada item:
 * {relatorio, pedido?: {geotag, tema, opcoes}, salvoEm?}.
 * @returns {Array<object>} os salvos criados
 */
export function semearSalvosMock(itens = []) {
  return itens.map((item, i) =>
    criarSalvo({
      jobId: 5000 + proximoSalvo + i,
      pedido: item.pedido ?? {
        geotag: { nivel: item.relatorio?.recorte?.nivel, codigo: item.relatorio?.recorte?.codigo },
        tema: item.relatorio?.tema?.id,
        opcoes: item.opcoes ?? {},
        ...(item.relatorio?.assistente?.id ? { assistente: item.relatorio.assistente.id } : {}),
      },
      relatorio: item.relatorio,
      salvoEm: item.salvoEm,
    }),
  );
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
const erro404 = (msg) => HttpResponse.json({ error: msg }, { status: 404 });

/** Resultado final do job (o mesmo que o GET do job devolve ao terminar). */
function resultadoJob(job) {
  const c = job.config;
  if (job.pedido?.assistente === "eda_municipio") {
    return { ...RELATORIO_EDA_FIXTURE, cache_hit: !!c.cacheHit };
  }
  const base = c.llmIndisponivel
    ? RELATORIO_LLM_INDISPONIVEL_FIXTURE
    : (RELATORIOS_POR_TEMA_FIXTURE[job.pedido?.tema] ?? RELATORIO_RESULT_FIXTURE);
  return { ...base, cache_hit: !!c.cacheHit };
}

export const gestorRelatoriosHandlers = [
  http.get(`${BASE}/recorte-padrao`, ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    return HttpResponse.json({
      ...RECORTE_PADRAO_FIXTURE,
      escola: { ...RECORTE_PADRAO_FIXTURE.escola, cod_inep: String(params.cod_inep) },
    });
  }),

  http.get(`${BASE}/assistentes`, ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    return HttpResponse.json({ assistentes: ASSISTENTES_FIXTURE });
  }),

  http.get(`${BASE}/temas`, ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    const q = new URL(request.url).searchParams;
    const nivel = q.get("nivel");
    const a = assistentePorId(q.get("assistente"));
    if (!a) return erro400("Assistente desconhecido.");
    const ids = a.modo === "composto" ? a.capitulos.map((c) => c.tema) : a.temas;
    const doAssistente = TEMAS_FIXTURE.filter((t) => ids.includes(t.id));
    const temas = nivel ? doAssistente.filter((t) => t.niveis.includes(nivel)) : doAssistente;
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
    const a = assistentePorId(body?.assistente);
    if (!a) return erro400("Assistente desconhecido.");
    if (!a.niveis.includes(geotag.nivel)) return erro400("Assistente indisponível para este nível.");
    if (a.modo !== "composto") {
      const def = TEMAS_FIXTURE.find((t) => t.id === tema);
      if (!def || !def.niveis.includes(geotag.nivel)) {
        return erro400("Tema indisponível para este nível.");
      }
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
    return HttpResponse.json({ state: "finished", progress: 100, result: resultadoJob(job) });
  }),

  // ------------------------------------------------------------ salvos (fase 3)

  http.post(`${BASE}/salvos`, async ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    const body = await request.json().catch(() => ({}));
    const jobId = Number(body?.job_id);
    const job = jobs.get(jobId);
    if (!job) return erro404("Relatório não encontrado.");
    const terminou = job.consultas >= job.config.consultasAteFim && !job.config.falha;
    if (!terminou) {
      return HttpResponse.json(
        { error: "O relatório ainda não terminou de ser gerado." },
        { status: 409 },
      );
    }
    const existente = salvos.find((s) => s.job_id === jobId);
    if (existente) return HttpResponse.json(resumoSalvo(existente), { status: 200 });
    const salvo = criarSalvo({ jobId, pedido: job.pedido, relatorio: resultadoJob(job) });
    return HttpResponse.json(resumoSalvo(salvo), { status: 201 });
  }),

  http.get(`${BASE}/salvos`, ({ request }) => {
    if (naoAutorizado(request)) return erro401();
    const q = new URL(request.url).searchParams;
    const page = Math.max(1, Number(q.get("page") ?? 1) || 1);
    const perPage = Math.min(100, Math.max(1, Number(q.get("per_page") ?? 20) || 20));
    const ordenados = [...salvos].reverse(); // mais recentes primeiro
    const items = ordenados.slice((page - 1) * perPage, page * perPage).map(resumoSalvo);
    return HttpResponse.json({ items, total: salvos.length, page, per_page: perPage });
  }),

  http.get(`${BASE}/salvos/:id`, ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    const s = salvos.find((x) => x.id === Number(params.id));
    if (!s) return erro404("Relatório não encontrado.");
    return HttpResponse.json({ ...resumoSalvo(s), relatorio: s.relatorio });
  }),

  http.delete(`${BASE}/salvos/:id`, ({ request, params }) => {
    if (naoAutorizado(request)) return erro401();
    const i = salvos.findIndex((x) => x.id === Number(params.id));
    if (i < 0) return erro404("Relatório não encontrado.");
    salvos.splice(i, 1);
    return HttpResponse.json({ ok: 1 });
  }),
];
