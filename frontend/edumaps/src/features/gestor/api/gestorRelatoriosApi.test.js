// src/features/gestor/api/gestorRelatoriosApi.test.js
// Camada API do Assistente de Relatório (#219) contra os handlers MSW.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { http, HttpResponse } from "msw";
import { setApiToken, ApiError } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_RELATORIOS, RECORTE_PADRAO_FIXTURE } from "../mocks/relatoriosFixtures.js";
import {
  resetRelatoriosMockState,
  configurarRelatoriosMock,
  getPedidosRelatorioMock,
  getSalvosMock,
  semearSalvosMock,
} from "../mocks/relatoriosHandlers.js";
import { server } from "../../../mocks/server.js";
import {
  getRecortePadrao,
  listTemasRelatorio,
  gerarRelatorio,
  getJobRelatorio,
  limparOpcoes,
  salvarRelatorio,
  listarSalvos,
  getSalvo,
  excluirSalvo,
  listarAssistentes,
  ASSISTENTE_PADRAO,
} from "./gestorRelatoriosApi.js";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
  RELATORIO_EDA_FIXTURE,
} from "../mocks/relatoriosFixtures.js";

describe("gestorRelatoriosApi", () => {
  beforeEach(() => {
    resetRelatoriosMockState();
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => setApiToken(null));

  it("lê o recorte-padrão da escola", async () => {
    const r = await getRecortePadrao(INEP_RELATORIOS);
    expect(r.escola.cod_inep).toBe(INEP_RELATORIOS);
    expect(r.municipio).toEqual(RECORTE_PADRAO_FIXTURE.municipio);
    expect(r.regiao.codigo).toBe("N");
  });

  it("sem sessão o recorte-padrão responde 401", async () => {
    setApiToken(null);
    await expect(getRecortePadrao(INEP_RELATORIOS)).rejects.toMatchObject({ status: 401 });
  });

  it("lista os temas do nível (desembrulha {temas})", async () => {
    const regiao = await listTemasRelatorio(INEP_RELATORIOS, "regiao");
    expect(regiao.map((t) => t.id)).toContain("tendencia_ideb");
    const escola = await listTemasRelatorio(INEP_RELATORIOS, "escola");
    expect(escola.map((t) => t.id)).toEqual(["minha_escola", "historico_escola", "escolas_parecidas"]);
    const municipio = await listTemasRelatorio(INEP_RELATORIOS, "municipio");
    expect(municipio.map((t) => t.id)).not.toContain("gestores_territorio");
  });

  it("envia ?nivel na consulta de temas", async () => {
    let nivel = null;
    server.use(
      http.get("/api/gestor/:cod_inep/relatorios/temas", ({ request }) => {
        nivel = new URL(request.url).searchParams.get("nivel");
        return HttpResponse.json({});
      }),
    );
    expect(await listTemasRelatorio(INEP_RELATORIOS, "uf")).toEqual([]);
    expect(nivel).toBe("uf");
  });

  it("gera: corpo no formato do contrato, sem opções vazias, 202 {job_id}", async () => {
    const r = await gerarRelatorio(INEP_RELATORIOS, {
      geotag: { nivel: "municipio", codigo: 1100205 },
      tema: "ideb_territorio",
      opcoes: { etapa: "fundamental_i", rede: "" },
    });
    expect(r.job_id).toBeGreaterThan(0);
    expect(getPedidosRelatorioMock()[0]).toEqual({
      geotag: { nivel: "municipio", codigo: "1100205" },
      tema: "ideb_territorio",
      opcoes: { etapa: "fundamental_i" },
    });
  });

  it("omite opcoes quando todas estão vazias", async () => {
    await gerarRelatorio(INEP_RELATORIOS, {
      geotag: { nivel: "escola", codigo: INEP_RELATORIOS },
      tema: "minha_escola",
      opcoes: {},
    });
    expect(getPedidosRelatorioMock()[0]).not.toHaveProperty("opcoes");
  });

  it("400 traz a mensagem do servidor", async () => {
    const err = await gerarRelatorio(INEP_RELATORIOS, {
      geotag: { nivel: "regiao", codigo: "N" },
      tema: "minha_escola",
    }).catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(400);
    expect(err.message).toBe("Tema indisponível para este nível.");
  });

  it("o job passa por inactive → active → finished com o ReportResult", async () => {
    const { job_id } = await gerarRelatorio(INEP_RELATORIOS, {
      geotag: { nivel: "uf", codigo: "RO" },
      tema: "ideb_territorio",
    });
    expect((await getJobRelatorio(INEP_RELATORIOS, job_id)).state).toBe("inactive");
    expect((await getJobRelatorio(INEP_RELATORIOS, job_id)).state).toBe("active");
    const fim = await getJobRelatorio(INEP_RELATORIOS, job_id);
    expect(fim.state).toBe("finished");
    expect(fim.result.secoes.map((s) => s.tipo)).toEqual(
      expect.arrayContaining(["texto", "indicadores", "tabela", "grafico"]),
    );
    expect(fim.result.cache_hit).toBe(false);
  });

  it("job failed devolve a mensagem de erro", async () => {
    configurarRelatoriosMock({ falha: "eduBR ausente", consultasAteFim: 1 });
    const { job_id } = await gerarRelatorio(INEP_RELATORIOS, {
      geotag: { nivel: "uf", codigo: "RO" },
      tema: "ideb_territorio",
    });
    expect(await getJobRelatorio(INEP_RELATORIOS, job_id)).toEqual({
      state: "failed",
      error: "eduBR ausente",
    });
  });

  it("job inexistente responde 404", async () => {
    await expect(getJobRelatorio(INEP_RELATORIOS, 1)).rejects.toMatchObject({ status: 404 });
  });

  it("limparOpcoes remove vazios e nulos", () => {
    expect(limparOpcoes({ a: "", b: null, c: undefined, d: "x" })).toEqual({ d: "x" });
    expect(limparOpcoes(undefined)).toEqual({});
  });

  describe("salvos (fase 3)", () => {
    async function jobTerminado(tema = "ideb_territorio") {
      configurarRelatoriosMock({ consultasAteFim: 1 });
      const { job_id } = await gerarRelatorio(INEP_RELATORIOS, {
        geotag: { nivel: "municipio", codigo: "1100205" },
        tema,
        opcoes: { etapa: "fundamental_ii" },
      });
      await getJobRelatorio(INEP_RELATORIOS, job_id);
      return job_id;
    }

    it("salva o job terminado (201) e devolve o resumo; de novo devolve o mesmo (200)", async () => {
      let status = [];
      server.events.on("response:mocked", ({ response, request }) => {
        if (request.url.endsWith("/relatorios/salvos") && request.method === "POST") {
          status.push(response.status);
        }
      });
      const jobId = await jobTerminado();
      const salvo = await salvarRelatorio(INEP_RELATORIOS, jobId);
      expect(salvo).toMatchObject({
        id: 1,
        titulo: RELATORIO_RESULT_FIXTURE.titulo,
        tema: { id: "ideb_territorio", titulo: "IDEB do território" },
        recorte: { nivel: "municipio", codigo: "1100205", nome: "Porto Velho" },
        opcoes: { etapa: "fundamental_ii" },
        gerado_em: RELATORIO_RESULT_FIXTURE.gerado_em,
      });
      expect(salvo.salvo_em).toBeTruthy();
      const outra = await salvarRelatorio(INEP_RELATORIOS, jobId);
      expect(outra.id).toBe(1);
      expect(getSalvosMock()).toHaveLength(1);
      server.events.removeAllListeners();
      expect(status).toEqual([201, 200]);
    });

    it("o POST só leva o job_id (o conteúdo vem do servidor)", async () => {
      let corpo = null;
      server.use(
        http.post("/api/gestor/:cod_inep/relatorios/salvos", async ({ request }) => {
          corpo = await request.json();
          return HttpResponse.json({ salvo: { id: 9 } }, { status: 201 });
        }),
      );
      expect(await salvarRelatorio(INEP_RELATORIOS, "77")).toEqual({ id: 9 });
      expect(corpo).toEqual({ job_id: 77 });
    });

    it("job inexistente → 404; job ainda rodando ou falho → 409", async () => {
      await expect(salvarRelatorio(INEP_RELATORIOS, 12345)).rejects.toMatchObject({ status: 404 });
      const { job_id } = await gerarRelatorio(INEP_RELATORIOS, {
        geotag: { nivel: "uf", codigo: "RO" },
        tema: "ideb_territorio",
      });
      const err = await salvarRelatorio(INEP_RELATORIOS, job_id).catch((e) => e);
      expect(err).toBeInstanceOf(ApiError);
      expect(err.status).toBe(409);
      expect(err.message).toMatch(/ainda não terminou/);
    });

    it("lista paginada, mais recentes primeiro, com page/per_page", async () => {
      semearSalvosMock(
        Array.from({ length: 3 }, (_, i) => ({
          relatorio: { ...RELATORIO_RESULT_FIXTURE, titulo: `Relatório ${i + 1}` },
        })),
      );
      let consulta = null;
      server.events.on("request:start", ({ request }) => {
        if (request.url.includes("/salvos?")) consulta = new URL(request.url).searchParams;
      });
      const p1 = await listarSalvos(INEP_RELATORIOS, { page: 1, per_page: 2 });
      server.events.removeAllListeners();
      expect(consulta.get("page")).toBe("1");
      expect(consulta.get("per_page")).toBe("2");
      expect(p1.total).toBe(3);
      expect(p1.items.map((i) => i.titulo)).toEqual(["Relatório 3", "Relatório 2"]);
      expect(p1.items[0]).not.toHaveProperty("relatorio");
      const p2 = await listarSalvos(INEP_RELATORIOS, { page: 2, per_page: 2 });
      expect(p2.items.map((i) => i.titulo)).toEqual(["Relatório 1"]);
      expect(p2.page).toBe(2);
    });

    it("lista vazia tem defaults", async () => {
      expect(await listarSalvos(INEP_RELATORIOS)).toEqual({
        items: [],
        total: 0,
        page: 1,
        per_page: 20,
      });
    });

    it("detalhe traz o resumo e o relatório; aceita também {salvo, relatorio}", async () => {
      const [s] = semearSalvosMock([{ relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE }]);
      const det = await getSalvo(INEP_RELATORIOS, s.id);
      expect(det.id).toBe(s.id);
      expect(det.relatorio.titulo).toBe(RELATORIO_INFRAESTRUTURA_FIXTURE.titulo);
      expect(det.recorte).toMatchObject({ nivel: "uf", codigo: "RO" });

      server.use(
        http.get("/api/gestor/:cod_inep/relatorios/salvos/:id", () =>
          HttpResponse.json({ salvo: { id: 3, titulo: "X" }, relatorio: { titulo: "X" } }),
        ),
      );
      expect(await getSalvo(INEP_RELATORIOS, 3)).toEqual({
        id: 3,
        titulo: "X",
        relatorio: { titulo: "X" },
      });
    });

    it("detalhe e exclusão de id inexistente → 404; exclusão remove", async () => {
      await expect(getSalvo(INEP_RELATORIOS, 99)).rejects.toMatchObject({ status: 404 });
      await expect(excluirSalvo(INEP_RELATORIOS, 99)).rejects.toMatchObject({ status: 404 });
      const [s] = semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
      expect(await excluirSalvo(INEP_RELATORIOS, s.id)).toEqual({ ok: 1 });
      expect(getSalvosMock()).toHaveLength(0);
    });

    it("sem sessão a lista responde 401", async () => {
      setApiToken(null);
      await expect(listarSalvos(INEP_RELATORIOS)).rejects.toMatchObject({ status: 401 });
    });
  });

  describe("assistentes (fase 4)", () => {
    it("lista os assistentes (desembrulha {assistentes})", async () => {
      const lista = await listarAssistentes(INEP_RELATORIOS);
      expect(lista.map((a) => [a.id, a.modo])).toEqual([
        ["relatorio", "tema"],
        ["eda_municipio", "composto"],
      ]);
      expect(lista[1].niveis).toEqual(["municipio"]);
      expect(lista[1].capitulos[0]).toEqual({ tema: "ideb_territorio", titulo: "IDEB do município" });
      expect(ASSISTENTE_PADRAO).toBe("relatorio");
    });

    it("sem sessão /assistentes responde 401; corpo vazio vira []", async () => {
      setApiToken(null);
      await expect(listarAssistentes(INEP_RELATORIOS)).rejects.toMatchObject({ status: 401 });
      setApiToken(SESSION_TOKEN);
      server.use(http.get("/api/gestor/:cod_inep/relatorios/assistentes", () => HttpResponse.json({})));
      expect(await listarAssistentes(INEP_RELATORIOS)).toEqual([]);
    });

    it("temas: ?assistente só fora do padrão", async () => {
      const vistos = [];
      server.use(
        http.get("/api/gestor/:cod_inep/relatorios/temas", ({ request }) => {
          vistos.push(new URL(request.url).searchParams.get("assistente"));
          return HttpResponse.json({ temas: [] });
        }),
      );
      await listTemasRelatorio(INEP_RELATORIOS, "municipio");
      await listTemasRelatorio(INEP_RELATORIOS, "municipio", "relatorio");
      await listTemasRelatorio(INEP_RELATORIOS, "municipio", "eda_municipio");
      expect(vistos).toEqual([null, null, "eda_municipio"]);
    });

    it("temas do assistente composto são os dos capítulos no nível", async () => {
      const temas = await listTemasRelatorio(INEP_RELATORIOS, "municipio", "eda_municipio");
      expect(temas.map((t) => t.id).sort()).toEqual(
        ["docentes_territorio", "ideb_escolas", "ideb_territorio", "redes_territorio"].sort(),
      );
    });

    it("gera no modo composto: sem tema, com assistente; o job devolve a EDA", async () => {
      configurarRelatoriosMock({ consultasAteFim: 1 });
      const { job_id } = await gerarRelatorio(INEP_RELATORIOS, {
        geotag: { nivel: "municipio", codigo: "1100205" },
        opcoes: { etapa: "fundamental_i" },
        assistente: "eda_municipio",
      });
      expect(getPedidosRelatorioMock()[0]).toEqual({
        geotag: { nivel: "municipio", codigo: "1100205" },
        opcoes: { etapa: "fundamental_i" },
        assistente: "eda_municipio",
      });
      const job = await getJobRelatorio(INEP_RELATORIOS, job_id);
      expect(job.state).toBe("finished");
      expect(job.result.capitulos).toEqual(RELATORIO_EDA_FIXTURE.capitulos);
      expect(job.result.assistente.id).toBe("eda_municipio");
    });

    it("assistente padrão não vai no corpo", async () => {
      await gerarRelatorio(INEP_RELATORIOS, {
        geotag: { nivel: "uf", codigo: "RO" },
        tema: "ideb_territorio",
        assistente: "relatorio",
      });
      expect(getPedidosRelatorioMock()[0]).toEqual({ geotag: { nivel: "uf", codigo: "RO" }, tema: "ideb_territorio" });
    });

    it("composto fora do nível do assistente → 400", async () => {
      await expect(
        gerarRelatorio(INEP_RELATORIOS, { geotag: { nivel: "uf", codigo: "RO" }, assistente: "eda_municipio" }),
      ).rejects.toMatchObject({ status: 400 });
    });

    it("salvo da EDA leva assistente {id, titulo}; o padrão também", async () => {
      const [eda, tema] = semearSalvosMock([
        { relatorio: RELATORIO_EDA_FIXTURE },
        { relatorio: RELATORIO_RESULT_FIXTURE },
      ]);
      expect(eda.assistente).toEqual({ id: "eda_municipio", titulo: "EDA do município" });
      expect(tema.assistente).toEqual({ id: "relatorio", titulo: "Relatório por tema" });
      const lista = await listarSalvos(INEP_RELATORIOS);
      expect(lista.items.map((i) => i.assistente.id)).toEqual(["relatorio", "eda_municipio"]);
    });
  });
});
