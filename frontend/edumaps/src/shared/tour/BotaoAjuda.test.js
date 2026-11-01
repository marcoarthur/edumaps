// src/shared/tour/BotaoAjuda.test.js
import { describe, it, expect, vi, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import BotaoAjuda from "./BotaoAjuda.svelte";

function managerFalso(tour) {
  return {
    ativo: null,
    tourDaRota: (path) => (path === tour.rotaInicial ? tour : null),
    iniciar: vi.fn(),
  };
}

const TOUR = { id: "busca-escola", titulo: "Como buscar uma escola", rotaInicial: "/escola/search" };

describe("BotaoAjuda", () => {
  it("aparece na página que tem tour e o inicia ao clicar", async () => {
    const manager = managerFalso(TOUR);
    render(BotaoAjuda, { path: "/escola/search", manager });

    const botao = screen.getByRole("button", { name: "Ajuda guiada: Como buscar uma escola" });
    await userEvent.click(botao);
    expect(manager.iniciar).toHaveBeenCalledWith("busca-escola");
  });

  it("não aparece em página sem tour", () => {
    render(BotaoAjuda, { path: "/about", manager: managerFalso(TOUR) });
    expect(screen.queryByRole("button")).toBeNull();
  });

  describe("tour com prontoQuando (página que carrega dados)", () => {
    const PAINEL = {
      id: "painel-gestor",
      titulo: "Conhecer o painel do gestor",
      rotaInicial: "/gestor/painel",
      prontoQuando: "gestor-escola",
    };

    afterEach(() => {
      document.querySelectorAll('[data-tour="gestor-escola"]').forEach((el) => el.remove());
    });

    function montarAlvo() {
      const el = document.createElement("header");
      el.dataset.tour = "gestor-escola";
      document.body.appendChild(el);
      return el;
    }

    it("não aparece enquanto o alvo não existe (carregando ou tela de erro)", () => {
      render(BotaoAjuda, { path: "/gestor/painel", manager: managerFalso(PAINEL) });
      expect(screen.queryByRole("button")).toBeNull();
    });

    it("aparece quando o painel carrega, e some se o alvo sair", async () => {
      render(BotaoAjuda, { path: "/gestor/painel", manager: managerFalso(PAINEL) });
      const alvo = montarAlvo();
      expect(
        await screen.findByRole("button", { name: "Ajuda guiada: Conhecer o painel do gestor" }),
      ).toBeInTheDocument();

      alvo.remove();
      await waitFor(() => expect(screen.queryByRole("button")).toBeNull());
    });

    it("alvo já presente na montagem: aparece de imediato", () => {
      montarAlvo();
      render(BotaoAjuda, { path: "/gestor/painel", manager: managerFalso(PAINEL) });
      expect(screen.getByRole("button")).toBeInTheDocument();
    });
  });
});
