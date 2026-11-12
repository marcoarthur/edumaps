// src/features/config/pages/RedeContasPage.test.js — contas de rede no admin (#394).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import RedeContasPage from "./RedeContasPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { resetRedeMock } from "@/features/rede/mocks/redeHandlers.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const conta = (nome) => screen.getByText(nome, { selector: "p" }).closest("li");

describe("RedeContasPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetRedeMock();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    vi.clearAllMocks();
  });
  afterEach(() => {
    clearSessaoToken();
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("lista as contas com a situação da senha e as redes", async () => {
    render(RedeContasPage);
    expect(await screen.findByText("Técnica da Rede")).toBeInTheDocument();
    expect(within(conta("Técnica da Rede")).getByText("Senha definida")).toBeInTheDocument();
    expect(within(conta("Técnica da Rede")).getByText(/Rede municipal · Alta Floresta D'Oeste\/RO/)).toBeInTheDocument();
    expect(within(conta("Secretário Adjunto")).getByText(/Convite pendente/)).toBeInTheDocument();
    expect(within(conta("Secretário Adjunto")).getByText(/não vê escola nenhuma/)).toBeInTheDocument();
  });

  it("cria a conta e mostra o link do convite uma vez", async () => {
    render(RedeContasPage);
    await screen.findByText("Técnica da Rede");
    const form = within(screen.getByLabelText("Nova conta de rede"));
    await fireEvent.input(form.getByLabelText("Nome *"), { target: { value: "Diretora Regional" } });
    await fireEvent.input(form.getByLabelText("E-mail *"), { target: { value: "regional@estado.exemplo" } });
    await fireEvent.click(form.getByRole("button", { name: "Criar conta e gerar convite" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Conta de rede criada.", "success"));
    const link = await screen.findByLabelText("Link do convite");
    expect(link.value).toMatch(/\/rede\/convite\/[A-Za-z0-9_-]{43}$/);
    expect(screen.getByText(/não aparece de novo/)).toBeInTheDocument();
    expect(await screen.findByText("Diretora Regional")).toBeInTheDocument();
  });

  it("concede e revoga uma rede", async () => {
    render(RedeContasPage);
    await screen.findByText("Secretário Adjunto");
    const c = () => within(conta("Secretário Adjunto"));
    await fireEvent.click(c().getByRole("button", { name: "+ Conceder rede" }));
    await fireEvent.input(c().getByLabelText("Município (código IBGE)"), { target: { value: "3550308" } });
    await fireEvent.click(c().getByRole("button", { name: "Conceder" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Rede concedida.", "success"));
    expect(await c().findByText(/Rede municipal · São Paulo\/SP/)).toBeInTheDocument();
    await fireEvent.click(c().getByRole("button", { name: "Revogar rede Municipal de São Paulo" }));
    expect(window.confirm).toHaveBeenCalledWith(expect.stringMatching(/O acesso acaba na hora/));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Rede revogada.", "success"));
    expect(await c().findByText(/não vê escola nenhuma/)).toBeInTheDocument();
  });

  it("município inválido: avisa antes de enviar e mostra o erro do servidor", async () => {
    render(RedeContasPage);
    await screen.findByText("Secretário Adjunto");
    const c = () => within(conta("Secretário Adjunto"));
    await fireEvent.click(c().getByRole("button", { name: "+ Conceder rede" }));
    await fireEvent.input(c().getByLabelText("Município (código IBGE)"), { target: { value: "123" } });
    await fireEvent.click(c().getByRole("button", { name: "Conceder" }));
    expect(addToast).toHaveBeenCalledWith("Informe o código IBGE do município (7 dígitos).", "warning");
    await fireEvent.input(c().getByLabelText("Município (código IBGE)"), { target: { value: "9999999" } });
    await fireEvent.click(c().getByRole("button", { name: "Conceder" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Município não encontrado no Censo.", "error"));
  });

  it("novo convite e histórico", async () => {
    render(RedeContasPage);
    await screen.findByText("Secretário Adjunto");
    await fireEvent.click(within(conta("Secretário Adjunto")).getByRole("button", { name: "Novo convite" }));
    expect(window.confirm).toHaveBeenCalledWith(expect.stringMatching(/O link anterior deixa de valer/));
    expect((await screen.findByLabelText("Link do convite")).value).toMatch(/\/rede\/convite\//);
    await fireEvent.click(within(conta("Secretário Adjunto")).getByRole("button", { name: "Histórico" }));
    expect(await screen.findByLabelText("Histórico de Secretário Adjunto")).toHaveTextContent("Convite gerado");
  });
});
