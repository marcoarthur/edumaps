// src/features/gestor/pages/GestorPesquisasPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import GestorPesquisasPage from "./GestorPesquisasPage.svelte";
import { addToast } from "@/shared/stores/toastStore.js";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({
  addToast: vi.fn(),
}));

function renderWithQuery(query) {
  window.history.replaceState({}, "", `/gestor/pesquisas${query}`);
  return render(GestorPesquisasPage);
}

const logado = () => window.localStorage.setItem("edumaps_gestor_token", SESSION_TOKEN);

describe("GestorPesquisasPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setApiToken(null);
    vi.clearAllMocks();
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("sem sessão, pede login em vez de listar", async () => {
    renderWithQuery("?inep=11000040");

    await screen.findByText(/Entre para ver as pesquisas da sua escola/);
    expect(screen.queryByText("Pesquisa de clima escolar")).not.toBeInTheDocument();
  });

  it("lista as pesquisas da escola da sessão (via MSW)", async () => {
    logado();
    renderWithQuery("");

    await screen.findByText("Pesquisa de clima escolar");
    expect(screen.getByText("Rascunho")).toBeInTheDocument();
    expect(screen.getByText("Publicada")).toBeInTheDocument();
    expect(screen.getByText("Semana de ciências: temas de interesse")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "+ Nova pesquisa" }).getAttribute("href")).toBe(
      "/gestor/pesquisas/nova?inep=11000040",
    );
    expect(screen.getByText(/Logado como/)).toBeInTheDocument();
  });

  it("ignora o INEP da URL: a escola vem da sessão", async () => {
    logado();
    renderWithQuery("?inep=99999999");

    await screen.findByText("Pesquisa de clima escolar");
  });

  it("apaga a identidade antiga por escola guardada no navegador", async () => {
    logado();
    window.localStorage.setItem("edumaps_gestor_11000040", JSON.stringify({ nome: "Marina" }));
    renderWithQuery("");

    await screen.findByText("Pesquisa de clima escolar");
    expect(window.localStorage.getItem("edumaps_gestor_11000040")).toBeNull();
    expect(window.localStorage.getItem("edumaps_gestor_token")).toBe(SESSION_TOKEN);
  });

  it("exibe estado vazio para escola sem pesquisas", async () => {
    logado();
    server.use(http.get("/api/gestor/pesquisas", () => HttpResponse.json([])));
    renderWithQuery("");

    await screen.findByText(/Nenhuma pesquisa ainda/);
    expect(screen.getByRole("link", { name: "Criar a primeira pesquisa" })).toBeInTheDocument();
  });

  it("exclui um rascunho após confirmação", async () => {
    logado();
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWithQuery("");
    await screen.findByText("Pesquisa de clima escolar");

    await fireEvent.click(screen.getByRole("button", { name: "Excluir" }));

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("Rascunho excluído.", "success"),
    );
    window.confirm.mockRestore();
  });

  it("cancela a exclusão se o usuário desistir", async () => {
    logado();
    vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWithQuery("");
    await screen.findByText("Pesquisa de clima escolar");

    await fireEvent.click(screen.getByRole("button", { name: "Excluir" }));
    expect(addToast).not.toHaveBeenCalled();
    window.confirm.mockRestore();
  });
});
