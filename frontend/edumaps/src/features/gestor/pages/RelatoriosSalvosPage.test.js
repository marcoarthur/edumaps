// src/features/gestor/pages/RelatoriosSalvosPage.test.js
// Meus relatórios (#219, fase 3): lista paginada, abrir, excluir, vazio e sessão.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_INFRAESTRUTURA_FIXTURE,
  RELATORIO_EDA_FIXTURE,
} from "../mocks/relatoriosFixtures.js";
import {
  resetRelatoriosMockState,
  semearSalvosMock,
  getSalvosMock,
} from "../mocks/relatoriosHandlers.js";
import { server } from "../../../mocks/server.js";
import RelatoriosSalvosPage from "./RelatoriosSalvosPage.svelte";

const linhas = () => screen.getAllByTestId("salvo-item");

describe("RelatoriosSalvosPage", () => {
  beforeEach(() => {
    resetRelatoriosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => setApiToken(null));

  it("sem sessão mostra o login", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(RelatoriosSalvosPage);
    expect(await screen.findByText("Entre para ver os seus relatórios.")).toBeInTheDocument();
  });

  it("401 na lista volta ao login", async () => {
    server.use(
      http.get("/api/gestor/:cod_inep/relatorios/salvos", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    render(RelatoriosSalvosPage);
    expect(await screen.findByText("Entre para ver os seus relatórios.")).toBeInTheDocument();
  });

  it("estado vazio com link para gerar", async () => {
    render(RelatoriosSalvosPage);
    const vazio = await screen.findByTestId("salvos-vazio");
    expect(vazio).toHaveTextContent("Você ainda não salvou nenhum relatório.");
    expect(within(vazio).getByRole("link", { name: "Gerar um relatório" })).toHaveAttribute(
      "href",
      "/gestor/relatorios",
    );
  });

  it("lista título, tema, recorte, datas e o link Abrir (mais recentes primeiro)", async () => {
    semearSalvosMock([
      { relatorio: RELATORIO_RESULT_FIXTURE, salvoEm: "2026-10-12T13:00:00Z" },
      { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE, salvoEm: "2026-10-12T14:00:00Z" },
    ]);
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");
    expect(screen.getByRole("heading", { name: "Meus relatórios" })).toBeInTheDocument();
    const [primeira, segunda] = linhas();
    expect(primeira).toHaveTextContent("Infraestrutura e IDEB — Rondônia");
    expect(primeira).toHaveTextContent("Rondônia (Estado)");
    expect(segunda).toHaveTextContent("IDEB do território — Porto Velho (RO)");
    expect(segunda).toHaveTextContent("IDEB do território");
    expect(segunda).toHaveTextContent("Porto Velho (Município)");
    expect(segunda).toHaveTextContent(/12\/10\/2026/);
    expect(within(segunda).getByRole("link", { name: /Abrir IDEB do território/ })).toHaveAttribute(
      "href",
      "/gestor/relatorios/salvos/1",
    );
    expect(screen.queryByRole("navigation", { name: /Paginação/ })).toBeNull();
  });

  it("pagina de 20 em 20", async () => {
    semearSalvosMock(
      Array.from({ length: 23 }, (_, i) => ({
        relatorio: { ...RELATORIO_RESULT_FIXTURE, titulo: `Relatório ${i + 1}` },
      })),
    );
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");
    expect(linhas()).toHaveLength(20);
    expect(linhas()[0]).toHaveTextContent("Relatório 23");
    expect(screen.getByTestId("salvos-pagina")).toHaveTextContent("Página 1 de 2 · 23 relatórios");
    expect(screen.getByRole("button", { name: "← Anterior" })).toBeDisabled();
    await fireEvent.click(screen.getByRole("button", { name: "Próxima →" }));
    await waitFor(() => expect(linhas()).toHaveLength(3));
    expect(linhas()[2]).toHaveTextContent("Relatório 1");
    expect(screen.getByTestId("salvos-pagina")).toHaveTextContent("Página 2 de 2");
    expect(screen.getByRole("button", { name: "Próxima →" })).toBeDisabled();
  });

  it("excluir pede confirmação; cancelar não exclui; confirmar remove da lista", async () => {
    semearSalvosMock([
      { relatorio: RELATORIO_RESULT_FIXTURE },
      { relatorio: RELATORIO_INFRAESTRUTURA_FIXTURE },
    ]);
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");
    await fireEvent.click(screen.getByRole("button", { name: /Excluir IDEB do território/ }));
    let dlg = screen.getByTestId("confirmar-excluir-salvo");
    expect(dlg).toHaveTextContent("Excluir relatório salvo?");
    expect(dlg).toHaveTextContent("IDEB do território — Porto Velho (RO)");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Cancelar" }));
    expect(screen.queryByTestId("confirmar-excluir-salvo")).toBeNull();
    expect(getSalvosMock()).toHaveLength(2);

    await fireEvent.click(screen.getByRole("button", { name: /Excluir IDEB do território/ }));
    dlg = screen.getByTestId("confirmar-excluir-salvo");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Excluir" }));
    await waitFor(() => expect(linhas()).toHaveLength(1));
    expect(screen.queryByTestId("confirmar-excluir-salvo")).toBeNull();
    expect(getSalvosMock().map((s) => s.titulo)).toEqual(["Infraestrutura e IDEB — Rondônia"]);
  });

  it("excluir o último leva ao estado vazio; erro na exclusão aparece no diálogo", async () => {
    semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");

    server.use(
      http.delete("/api/gestor/:cod_inep/relatorios/salvos/:id", () =>
        HttpResponse.json({ error: "Relatório não encontrado." }, { status: 404 }),
        { once: true },
      ),
    );
    await fireEvent.click(screen.getByRole("button", { name: /Excluir/ }));
    let dlg = screen.getByTestId("confirmar-excluir-salvo");
    await fireEvent.click(within(dlg).getByRole("button", { name: "Excluir" }));
    expect(await within(dlg).findByRole("alert")).toHaveTextContent("Relatório não encontrado.");

    await fireEvent.click(within(dlg).getByRole("button", { name: "Excluir" }));
    expect(await screen.findByTestId("salvos-vazio")).toBeInTheDocument();
  });

  it("excluir o único item da página 2 volta para a página 1", async () => {
    semearSalvosMock(
      Array.from({ length: 21 }, (_, i) => ({
        relatorio: { ...RELATORIO_RESULT_FIXTURE, titulo: `Relatório ${i + 1}` },
      })),
    );
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");
    await fireEvent.click(screen.getByRole("button", { name: "Próxima →" }));
    await waitFor(() => expect(linhas()).toHaveLength(1));
    await fireEvent.click(screen.getByRole("button", { name: /Excluir Relatório 1$/ }));
    await fireEvent.click(
      within(screen.getByTestId("confirmar-excluir-salvo")).getByRole("button", { name: "Excluir" }),
    );
    await waitFor(() => expect(linhas()).toHaveLength(20));
    expect(screen.queryByRole("navigation", { name: /Paginação/ })).toBeNull();
  });

  it("fase 4: mostra o assistente quando não é o padrão", async () => {
    semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }, { relatorio: RELATORIO_EDA_FIXTURE }]);
    render(RelatoriosSalvosPage);
    await screen.findByTestId("salvos-tabela");
    const [eda, tema] = linhas();
    expect(within(eda).getByTestId("salvo-assistente")).toHaveTextContent("EDA do município");
    // o tema da EDA é o próprio assistente: não repete
    expect(within(eda).getAllByText("EDA do município")).toHaveLength(1);
    expect(within(tema).queryByTestId("salvo-assistente")).toBeNull();
    expect(within(tema).getByText("IDEB do território")).toBeInTheDocument();
  });
});
