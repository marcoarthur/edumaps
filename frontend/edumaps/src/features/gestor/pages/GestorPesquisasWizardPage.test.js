// src/features/gestor/pages/GestorPesquisasWizardPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import GestorPesquisasWizardPage from "./GestorPesquisasWizardPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("GestorPesquisasWizardPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setApiToken(null);
    window.history.replaceState({}, "", "/gestor/pesquisas/nova?inep=11000040");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("sem sessão, pede login e não mostra o assistente", async () => {
    render(GestorPesquisasWizardPage);

    await screen.findByText(/Entre para montar pesquisas da sua escola/);
    expect(screen.queryByRole("heading", { name: "Dados da pesquisa" })).not.toBeInTheDocument();
  });

  it("com sessão, abre direto em 'Dados da pesquisa', sem cadastro", async () => {
    window.localStorage.setItem("edumaps_gestor_token", SESSION_TOKEN);
    render(GestorPesquisasWizardPage);

    await screen.findByRole("heading", { name: "Dados da pesquisa" });
    expect(screen.queryByText(/Seus dados/)).not.toBeInTheDocument();
    expect(screen.getByText(/Escola 11000040/)).toBeInTheDocument();
  });
});
