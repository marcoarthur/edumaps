// src/features/gestor/pages/GestorAcessoPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import GestorAcessoPage from "./GestorAcessoPage.svelte";
import { setApiToken, getApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("GestorAcessoPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setApiToken(null);
    vi.clearAllMocks();
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
    setApiToken(null);
  });

  it("faz login e guarda o token da sessão", async () => {
    window.history.replaceState({}, "", "/gestor");
    render(GestorAcessoPage);

    await screen.findByRole("button", { name: "Criar conta" });
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Sua senha"), {
      target: { value: "senha123" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Entrar" }));

    await waitFor(() => expect(getApiToken()).toBe(SESSION_TOKEN));
  });

  it("cadastra o gestor com o INEP pré-preenchido", async () => {
    window.history.replaceState({}, "", "/gestor?inep=11000040&modo=cadastro");
    render(GestorAcessoPage);

    await screen.findByRole("button", { name: "Já tenho conta" });
    expect(screen.getByDisplayValue("11000040")).toBeInTheDocument();

    await fireEvent.input(screen.getByPlaceholderText("Seu nome completo"), {
      target: { value: "Marina Souza" },
    });
    await fireEvent.input(screen.getByPlaceholderText("voce@escola.gov.br"), {
      target: { value: "marina@edu.gov.br" },
    });
    await fireEvent.input(screen.getByPlaceholderText("Mínimo 6 caracteres"), {
      target: { value: "senha123" },
    });
    await fireEvent.click(screen.getByRole("button", { name: /cadastrar e entrar/i }));

    await waitFor(() =>
      expect(addToast).toHaveBeenCalledWith("Cadastro realizado. Bem-vindo(a)!", "success"),
    );
  });

  it("mostra atalho ao painel quando já há sessão", async () => {
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    window.history.replaceState({}, "", "/gestor");
    render(GestorAcessoPage);

    expect(await screen.findByText(/você já está logado/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /ir para o painel/i })).toBeInTheDocument();
  });
});
