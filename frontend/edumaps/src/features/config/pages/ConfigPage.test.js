// src/features/config/pages/ConfigPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ConfigPage from "./ConfigPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { resetConfigMockState } from "../mocks/configHandlers.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

describe("ConfigPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("mostra categorias e abre a primeira folha habilitada (Chaves)", async () => {
    render(ConfigPage);

    expect(await screen.findByText("Painel de Configuração")).toBeInTheDocument();
    // a árvore carrega via API — espera a primeira categoria aparecer
    expect(await screen.findByText("Sistema")).toBeInTheDocument();
    for (const label of ["Integrações", "Aparência", "Comportamento", "Outros"]) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
    expect(await screen.findByText(/Chave ainda não definida/)).toBeInTheDocument();
    expect(screen.getByText(/Categorias/)).toBeInTheDocument();
  });

  it("marca itens não habilitados com 'Em breve'", async () => {
    render(ConfigPage);
    await screen.findByText("Painel de Configuração");

    const selos = await screen.findAllByText("Em breve");
    expect(selos.length).toBeGreaterThan(0);
  });

  it("exibe o tooltip '?' com a descrição da folha", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    const tooltips = screen.getAllByLabelText(/Sobre Chaves:/);
    expect(tooltips.length).toBeGreaterThan(0);
    const tooltip = tooltips[0];
    expect(tooltip.getAttribute("title")).toContain("provedor de linguagem");
  });

  it("salva a chave do Assistente do Censo", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.input(screen.getByPlaceholderText(/Cole a chave secreta/), {
      target: { value: "sk-teste-1234567890" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Configuração salva.", "success"));
    expect(await screen.findByText(/Chave atualmente definida/)).toBeInTheDocument();
  });

  it("rejeita chave muito curta na validação", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.input(screen.getByPlaceholderText(/Cole a chave secreta/), {
      target: { value: "x" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Validar" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(/A chave não pode ser vazia/);
  });
});