// src/features/gestor/pages/GestorPesquisasResultadosPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import GestorPesquisasResultadosPage from "./GestorPesquisasResultadosPage.svelte";

function renderWithQuery(query) {
  window.history.replaceState({}, "", `/gestor/pesquisas/resultados${query}`);
  return render(GestorPesquisasResultadosPage);
}

describe("GestorPesquisasResultadosPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setApiToken(null);
    vi.useRealTimers();
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("pede login quando não há sessão válida", async () => {
    renderWithQuery("?pesquisa=2");
    await screen.findByRole("heading", { name: "Entrar para ver resultados" });
  });

  it("mostra erro quando falta ?pesquisa=", async () => {
    renderWithQuery("");
    await screen.findByText(/Nenhuma pesquisa informada/);
  });

  it("mostra os resultados depois de entrar", async () => {
    renderWithQuery("?pesquisa=2");
    await screen.findByRole("heading", { name: "Entrar para ver resultados" });

    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Sua senha"), {
      target: { value: "senha123" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Entrar" }));

    await waitFor(() =>
      expect(screen.getByText(/Qual tema você mais quer/)).toBeInTheDocument(),
    );
    expect(screen.getByText(/^4$/)).toBeInTheDocument(); // n_respostas
    expect(screen.getByTestId("opcao-bars")).toBeInTheDocument();
    expect(screen.getByText(/Tema 1/)).toBeInTheDocument();
    expect(screen.getByText(/Feira de foguetes!/)).toBeInTheDocument();
    expect(
      screen.queryByRole("heading", { name: "Entrar para ver resultados" }),
    ).not.toBeInTheDocument();
  });

  it("rejeita credenciais inválidas sem sair da tela de login", async () => {
    renderWithQuery("?pesquisa=2");
    await screen.findByRole("heading", { name: "Entrar para ver resultados" });

    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Sua senha"), {
      target: { value: "senha-errada" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Entrar" }));

    await screen.findByText(/E-mail ou senha inválidos/);
    expect(
      screen.queryByText(/Qual tema você mais quer/),
    ).not.toBeInTheDocument();
  });

  it("mantém a sessão quando há token salvo", async () => {
    window.localStorage.setItem("edumaps_gestor_token", "88888888-9999-4aaa-8bbb-cccccccccccc");
    renderWithQuery("?pesquisa=2");
    await waitFor(() =>
      expect(screen.getByText(/Qual tema você mais quer/)).toBeInTheDocument(),
    );
    expect(screen.getByRole("button", { name: "Sair" })).toBeInTheDocument();
  });
});