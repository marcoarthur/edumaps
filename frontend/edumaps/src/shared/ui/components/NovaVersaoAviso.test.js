import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import NovaVersaoAviso from "./NovaVersaoAviso.svelte";
import { criarAtualizador } from "@/shared/pwa/atualizacao.js";

function sw() {
  const l = {};
  return {
    controller: {},
    addEventListener: (t, fn) => ((l[t] ||= []).push(fn)),
    removeEventListener: () => {},
    emit: (t) => (l[t] || []).forEach((fn) => fn()),
  };
}

describe("NovaVersaoAviso", () => {
  it("fica oculto até haver nova versão; região é anunciada (role=status)", () => {
    const atualizador = criarAtualizador({ sw: sw(), doc: null, recarregar: vi.fn() });
    render(NovaVersaoAviso, { atualizador });
    expect(screen.getByRole("status")).toHaveClass("print:hidden");
    expect(screen.queryByRole("button", { name: "Atualizar" })).toBeNull();
  });

  it("Atualizar → SKIP_WAITING e recarrega no controllerchange", async () => {
    const s = sw();
    const recarregar = vi.fn();
    const atualizador = criarAtualizador({ sw: s, doc: null, recarregar });
    render(NovaVersaoAviso, { atualizador });
    const w = { postMessage: vi.fn() };
    atualizador.onNeedRefresh(w);
    expect(await screen.findByText("Nova versão disponível.")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Atualizar" }));
    expect(w.postMessage).toHaveBeenCalledWith({ type: "SKIP_WAITING" });
    s.emit("controllerchange");
    expect(recarregar).toHaveBeenCalledTimes(1);
    expect(screen.queryByRole("button", { name: "Atualizar" })).toBeNull();
  });

  it("Depois → esconde sem recarregar", async () => {
    const recarregar = vi.fn();
    const atualizador = criarAtualizador({ sw: sw(), doc: null, recarregar });
    render(NovaVersaoAviso, { atualizador });
    atualizador.onNeedRefresh({ postMessage: vi.fn() });
    await userEvent.click(await screen.findByRole("button", { name: "Depois" }));
    expect(screen.queryByRole("button", { name: "Depois" })).toBeNull();
    expect(recarregar).not.toHaveBeenCalled();
  });

  it("erro de chunk mostra mensagem de recarga", async () => {
    const atualizador = criarAtualizador({ sw: sw(), doc: null, recarregar: vi.fn() });
    render(NovaVersaoAviso, { atualizador });
    atualizador.mostrarErroChunk();
    expect(await screen.findByText(/Recarregue para continuar/)).toBeInTheDocument();
  });
});
