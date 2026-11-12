// src/features/rede/pages/RedeRelatorioPage.test.js — relatório da escola pela rede (#396).
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import RedeRelatorioPage from "./RedeRelatorioPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { resetPlanosMock } from "@/features/gestor/mocks/planosHandlers.js";
import { REDE_TOKEN } from "../mocks/redeFixtures.js";

const abrir = (inep, id) => {
  window.history.pushState({}, "", `/rede/escolas/${inep}/planos/${id}/relatorio`);
  render(RedeRelatorioPage);
};

describe("RedeRelatorioPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetPlanosMock();
    setSessaoToken(REDE_TOKEN);
    setApiToken(REDE_TOKEN);
  });
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
  });

  it("mostra o relatório da escola, só leitura, com o cargo da conta de rede", async () => {
    abrir(11000040, 1);
    expect(await screen.findByRole("heading", { level: 1, name: "Plano de ação 2026" })).toBeInTheDocument();
    expect(screen.getByText(/por: Técnica pedagógica/)).toBeInTheDocument();
    expect(screen.getByText(/Visão da rede: só leitura/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "← Rede" })).toHaveAttribute("href", "/rede");
    expect(screen.getByRole("button", { name: "Imprimir / salvar PDF" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Editar|Salvar|\+/ })).not.toBeInTheDocument();
  });

  it("escola fora da rede: mostra o erro do servidor", async () => {
    abrir(99999999, 1);
    expect(await screen.findByText("Esta escola não é de uma rede da sua conta.")).toBeInTheDocument();
  });

  it("plano inexistente", async () => {
    abrir(11000040, 999);
    expect(await screen.findByText("Plano não encontrado.")).toBeInTheDocument();
  });
});
