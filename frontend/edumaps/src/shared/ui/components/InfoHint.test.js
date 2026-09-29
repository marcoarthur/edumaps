import { describe, it, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import InfoHint from "./InfoHint.svelte";

describe("InfoHint", () => {
  it("renderiza o botão (?) acessível e não abre a caixa por padrão", () => {
    render(InfoHint, {
      title: "Como calculamos",
      text: "Detalhe do cálculo.",
      items: ["ponto 1", "ponto 2"],
    });

    const btn = screen.getByRole("button", { name: "Detalhes sobre este dado" });
    expect(btn).toHaveTextContent("?");
    expect(btn).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("abre a caixa com título, texto e itens ao clicar", async () => {
    render(InfoHint, {
      title: "Como calculamos",
      text: "Detalhe do cálculo.",
      items: ["ponto 1", "ponto 2"],
    });

    await fireEvent.click(screen.getByRole("button", { name: "Detalhes sobre este dado" }));

    const dialog = screen.getByRole("dialog", { name: "Como calculamos" });
    expect(dialog).toBeInTheDocument();
    expect(screen.getByText("Detalhe do cálculo.")).toBeInTheDocument();
    expect(screen.getByText("ponto 1")).toBeInTheDocument();
    expect(screen.getByText("ponto 2")).toBeInTheDocument();
  });

  it("fecha no botão Fechar", async () => {
    render(InfoHint, { title: "T", text: "x" });

    await fireEvent.click(screen.getByRole("button", { name: "Detalhes sobre este dado" }));
    expect(screen.getByRole("dialog")).toBeInTheDocument();

    await fireEvent.click(screen.getByRole("button", { name: "Fechar" }));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });
});
