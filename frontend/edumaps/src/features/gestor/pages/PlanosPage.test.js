// src/features/gestor/pages/PlanosPage.test.js — lista e criação de planos (#371).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import PlanosPage from "./PlanosPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetPlanosMock } from "../mocks/planosHandlers.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("PlanosPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetPlanosMock();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista os planos com situação e resumo das ações", async () => {
    render(PlanosPage);
    expect(await screen.findByText("Plano de ação 2026")).toBeInTheDocument();
    expect(screen.getByText("PPP 2025")).toBeInTheDocument();
    expect(screen.getByText("Vigente")).toBeInTheDocument();
    expect(screen.getByText("Encerrado")).toBeInTheDocument();
    expect(screen.getByText("1 atrasada(s)")).toBeInTheDocument();
    expect(screen.getByText(/0 de 2 ação\(ões\) concluída\(s\)/)).toBeInTheDocument();
  });

  it("valida o título antes de criar", async () => {
    render(PlanosPage);
    await screen.findByText("Plano de ação 2026");
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo plano" }));
    await fireEvent.click(screen.getByRole("button", { name: "Criar plano" }));
    expect(addToast).toHaveBeenCalledWith("Dê um título ao plano.", "warning");
  });

  it("recusa fim antes do início", async () => {
    render(PlanosPage);
    await screen.findByText("Plano de ação 2026");
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo plano" }));
    await fireEvent.input(screen.getByPlaceholderText("Ex.: Plano de ação 2026"), { target: { value: "X" } });
    await fireEvent.input(screen.getByLabelText("Início"), { target: { value: "2026-06-01" } });
    await fireEvent.input(screen.getByLabelText("Fim"), { target: { value: "2026-01-01" } });
    await fireEvent.click(screen.getByRole("button", { name: "Criar plano" }));
    expect(addToast).toHaveBeenCalledWith("O fim do plano não pode ser antes do início.", "warning");
  });

  it("cria o plano e abre a página dele", async () => {
    const original = window.location;
    delete window.location;
    window.location = { ...original, href: original.href };
    render(PlanosPage);
    await screen.findByText("Plano de ação 2026");
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo plano" }));
    await fireEvent.input(screen.getByPlaceholderText("Ex.: Plano de ação 2026"), { target: { value: "Plano de gestão 2027" } });
    await fireEvent.click(screen.getByRole("button", { name: "Criar plano" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Plano criado.", "success"));
    expect(window.location.href).toMatch(/\/gestor\/planos\/\d+$/);
    window.location = original;
  });

  it("sem sessão pede login", async () => {
    clearSessaoToken();
    setApiToken(null);
    render(PlanosPage);
    expect(await screen.findByText("Entre para ver os planos da escola.")).toBeInTheDocument();
  });
});
