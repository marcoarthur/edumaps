// src/features/gestor/pages/RelatorioSalvoPage.test.js
// Relatório salvo (#219, fase 3): fotografia, ações, excluir, gerar de novo.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
} from "../mocks/relatoriosFixtures.js";
import {
  resetRelatoriosMockState,
  semearSalvosMock,
  getSalvosMock,
} from "../mocks/relatoriosHandlers.js";
import { server } from "../../../mocks/server.js";
import RelatorioSalvoPage from "./RelatorioSalvoPage.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

describe("RelatorioSalvoPage", () => {
  beforeEach(() => {
    resetRelatoriosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    window.history.replaceState({}, "", "/");
  });

  it("sem sessão mostra o login", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(RelatorioSalvoPage, { props: { id: "1" } });
    expect(await screen.findByText("Entre para ver os seus relatórios.")).toBeInTheDocument();
  });

  it("mostra a fotografia com a data, o relatório e as ações sem \"Salvar\"", async () => {
    const [s] = semearSalvosMock([
      {
        relatorio: RELATORIO_RESULT_FIXTURE,
        opcoes: { etapa: "fundamental_ii", rede: "Municipal" },
      },
    ]);
    render(RelatorioSalvoPage, { props: { id: String(s.id) } });
    const aviso = await screen.findByTestId("aviso-fotografia");
    expect(aviso).toHaveTextContent(/Fotografia de \d{2}\/10\/2026.*: os números são os daquela data\./);
    const view = screen.getByTestId("relatorio-view");
    expect(within(view).getByRole("heading", { name: RELATORIO_RESULT_FIXTURE.titulo })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Imprimir / salvar PDF" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Baixar Markdown" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Salvar relatório" })).toBeNull();

    const href = screen.getByRole("link", { name: "Gerar de novo com os dados atuais" }).getAttribute("href");
    const [path, query] = href.split("?");
    expect(path).toBe("/gestor/relatorios");
    expect(Object.fromEntries(new URLSearchParams(query))).toEqual({
      nivel: "municipio",
      codigo: "1100205",
      nome: "Porto Velho",
      tema: "ideb_territorio",
      etapa: "fundamental_ii",
      rede: "Municipal",
      gerar: "1",
    });
  });

  it("lê o :id da URL quando não vem por prop", async () => {
    semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
    const [s] = semearSalvosMock([{ relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE }]);
    window.history.replaceState({}, "", `/gestor/relatorios/salvos/${s.id}`);
    render(RelatorioSalvoPage);
    expect(
      await screen.findByRole("heading", { name: RELATORIO_INFRAESTRUTURA_FIXTURE.titulo }),
    ).toBeInTheDocument();
  });

  it("imprimir abre as tabelas técnicas durante a impressão", async () => {
    const [s] = semearSalvosMock([{ relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE }]);
    render(RelatorioSalvoPage, { props: { id: String(s.id) } });
    await screen.findByTestId("relatorio-view");
    const recolhidas = screen.getAllByTestId("tabela-recolhida");
    const original = window.print;
    let durante = null;
    window.print = vi.fn(() => {
      window.dispatchEvent(new Event("beforeprint"));
      durante = recolhidas.map((d) => d.open);
      window.dispatchEvent(new Event("afterprint"));
    });
    await fireEvent.click(screen.getByRole("button", { name: "Imprimir / salvar PDF" }));
    window.print = original;
    expect(durante).toEqual([true, true]);
    expect(recolhidas.map((d) => d.open)).toEqual([false, false]);
  });

  it("404 → Relatório não encontrado", async () => {
    render(RelatorioSalvoPage, { props: { id: "999" } });
    expect(await screen.findByTestId("salvo-nao-encontrado")).toHaveTextContent("Relatório não encontrado.");
    expect(screen.queryByTestId("relatorio-view")).toBeNull();
  });

  it("id inválido também é não encontrado, sem chamar a API", async () => {
    render(RelatorioSalvoPage, { props: { id: "abc" } });
    expect(await screen.findByTestId("salvo-nao-encontrado")).toBeInTheDocument();
  });

  it("401 volta ao login", async () => {
    server.use(
      http.get("/api/gestor/:cod_inep/relatorios/salvos/:id", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    render(RelatorioSalvoPage, { props: { id: "1" } });
    expect(await screen.findByText("Entre para ver os seus relatórios.")).toBeInTheDocument();
  });

  it("excluir confirma, apaga e volta para a lista", async () => {
    const [s] = semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
    window.history.replaceState({}, "", `/gestor/relatorios/salvos/${s.id}`);
    render(RelatorioSalvoPage, { props: { id: String(s.id) } });
    await screen.findByTestId("relatorio-view");
    await fireEvent.click(screen.getByRole("button", { name: "Excluir" }));
    const dlg = screen.getByTestId("confirmar-excluir-salvo");
    expect(dlg).toHaveTextContent(RELATORIO_RESULT_FIXTURE.titulo);
    await fireEvent.click(within(dlg).getByRole("button", { name: "Excluir" }));
    await vi.waitFor(() => expect(window.location.pathname).toBe("/gestor/relatorios/salvos"));
    expect(getSalvosMock()).toHaveLength(0);
  });
});
