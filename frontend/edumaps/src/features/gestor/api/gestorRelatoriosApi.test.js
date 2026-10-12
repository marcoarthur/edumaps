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
} from "../mocks/relatoriosHandlers.js";
import { server } from "../../../mocks/server.js";
import {
  getRecortePadrao,
  listTemasRelatorio,
  gerarRelatorio,
  getJobRelatorio,
  limparOpcoes,
} from "./gestorRelatoriosApi.js";

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
});
