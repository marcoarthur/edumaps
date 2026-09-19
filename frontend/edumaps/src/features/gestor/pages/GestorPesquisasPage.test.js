// src/features/gestor/pages/GestorPesquisasPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import GestorPesquisasPage from "./GestorPesquisasPage.svelte";
import { addToast } from "@/shared/stores/toastStore.js";

vi.mock("@/shared/stores/toastStore.js", () => ({
  addToast: vi.fn(),
}));

function renderWithQuery(query) {
  window.history.replaceState({}, "", `/gestor/pesquisas${query}`);
  return render(GestorPesquisasPage);
}

describe("GestorPesquisasPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.clearAllMocks();
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("lista as pesquisas da escola (via MSW)", async () => {
    renderWithQuery("?inep=11000040");

    await screen.findByText("Pesquisa de clima escolar");
    expect(screen.getByText("Rascunho")).toBeInTheDocument();
    expect(screen.getByText("Publicada")).toBeInTheDocument();
    expect(screen.getByText("Semana de ciências: temas de interesse")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "+ Nova pesquisa" }).getAttribute("href")).toBe(
      "/gestor/pesquisas/nova?inep=11000040",
    );
  });

  it("mostra o banner do gestor quando há sessão no localStorage", async () => {
    window.localStorage.setItem(
      "edumaps_gestor_11000040",
      JSON.stringify({ nome: "Marina Souza", cargo: "Diretora" }),
    );
    renderWithQuery("?inep=11000040");

    await screen.findByText(/Logado como/);
    expect(screen.getByText(/Marina Souza/)).toBeInTheDocument();
  });

  it("exibe estado vazio para escola sem pesquisas", async () => {
    server.use(
      http.get("/api/gestor/pesquisas", ({ request }) => {
        const url = new URL(request.url);
        if (url.searchParams.get("inep") === "99999999") {
          return HttpResponse.json([]);
        }
      }),
    );
    renderWithQuery("?inep=99999999");

    await screen.findByText(/Nenhuma pesquisa ainda/);
    expect(screen.getByRole("link", { name: "Criar a primeira pesquisa" })).toBeInTheDocument();
  });

  it("exclui um rascunho após confirmação", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(true);
    renderWithQuery("?inep=11000040");
    await screen.findByText("Pesquisa de clima escolar");

    const deleteBtn = screen.getByRole("button", { name: "Excluir" });
    await fireEvent.click(deleteBtn);

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("Rascunho excluído.", "success"),
    );
    window.confirm.mockRestore();
  });

  it("cancela a exclusão se o usuário desistir", async () => {
    vi.spyOn(window, "confirm").mockReturnValue(false);
    renderWithQuery("?inep=11000040");
    await screen.findByText("Pesquisa de clima escolar");

    await fireEvent.click(screen.getByRole("button", { name: "Excluir" }));
    expect(addToast).not.toHaveBeenCalled();
    window.confirm.mockRestore();
  });

  it("avisa quando falta o INEP", () => {
    renderWithQuery("");
    expect(screen.getByText(/Nenhum código INEP informado/)).toBeInTheDocument();
  });
});