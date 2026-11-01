// src/shared/tour/BotaoAjuda.test.js
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/svelte";
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
});
