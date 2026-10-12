// src/features/config/pages/ConfigPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import ConfigPage from "./ConfigPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { addToast } from "@/shared/stores/toastStore.js";
import {
  resetConfigMockState,
  getTelegramStatusChamadas,
  getRetencaoStatusChamadas,
} from "../mocks/configHandlers.js";

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
    for (const label of ["Integrações", "Canais de comunicação", "Aparência", "Comportamento", "Outros"]) {
      expect(screen.getAllByText(label).length).toBeGreaterThan(0);
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

  it("exibe as ações permitidas do bot como checkboxes", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.click(screen.getByRole("button", { name: "Configurar Ações permitidas" }));

    expect(await screen.findByText(/Marque as ações autorizadas/)).toBeInTheDocument();
    const boxes = screen.getAllByRole("checkbox");
    expect(boxes.length).toBe(7); // 7 ações da Policy
    expect(boxes.every((b) => !b.checked)).toBe(true); // lista vazia por omissão
  });

  it("alterna uma ação e salva a lista no servidor", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.click(screen.getByRole("button", { name: "Configurar Ações permitidas" }));
    await screen.findByText(/Marque as ações autorizadas/);

    await fireEvent.click(screen.getByRole("checkbox", { name: /ingest_stall/ }));
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Configuração salva.", "success"));
    expect(await screen.findByText(/Vigente: ingest_stall/)).toBeInTheDocument();
  });

  it("rejeita ação fora da Policy na validação", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.click(screen.getByRole("button", { name: "Configurar Ações permitidas" }));
    await screen.findByText(/Marque as ações autorizadas/);

    // nada marcado: validar lista vazia → erro do servidor
    await fireEvent.click(screen.getByRole("button", { name: "Validar" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(/A lista de ações não pode ser vazia/);
  });

  it("lista as folhas do bot público do Telegram e os templates do WhatsApp", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    expect(screen.getByText("Telegram (bot público)")).toBeInTheDocument();
    for (const label of [
      "Token do bot público",
      "Usuário do bot",
      "Modo de recebimento",
      "Segredo do webhook",
      "Bot público ativado",
      "Template de confirmação",
      "Idioma do template",
    ]) {
      expect(screen.getByRole("button", { name: `Configurar ${label}` })).toBeInTheDocument();
    }
    // nenhuma das folhas novas está "Em breve"
    const tg = screen.getByRole("button", { name: "Configurar Modo de recebimento" });
    expect(tg).not.toHaveTextContent("Em breve");
  });

  it("não mostra o status do bot público fora do grupo Telegram (bot público)", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);
    await fireEvent.click(screen.getByRole("button", { name: "Configurar Idioma do template" }));
    expect(await screen.findByPlaceholderText("pt_BR")).toBeInTheDocument();
    expect(screen.queryByText("Status do bot público")).not.toBeInTheDocument();
  });

  it("mostra o status do bot público ao abrir uma folha do grupo", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.click(screen.getByRole("button", { name: "Configurar Modo de recebimento" }));

    expect(await screen.findByText("Status do bot público")).toBeInTheDocument();
    expect(await screen.findByTestId("tg-recebimento")).toHaveTextContent("polling");
    expect(screen.getByRole("button", { name: "Iniciar polling" })).toBeInTheDocument();
  });

  it("recarrega o status do bot público ao salvar uma folha do grupo", async () => {
    render(ConfigPage);
    await screen.findByText(/Chave ainda não definida/);

    await fireEvent.click(screen.getByRole("button", { name: "Configurar Usuário do bot" }));
    await screen.findByTestId("tg-recebimento");
    const antes = getTelegramStatusChamadas();

    await fireEvent.input(await screen.findByPlaceholderText("EduMapsConfirmaBot"), {
      target: { value: "OutroBot" },
    });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Configuração salva.", "success"));
    await waitFor(() => expect(getTelegramStatusChamadas()).toBe(antes + 1));
  });
  describe("retenção (LGPD) e consentimento (#214)", () => {
    it("lista o grupo Retenção (LGPD) com as quatro folhas habilitadas", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      expect(screen.getByText("Retenção (LGPD)")).toBeInTheDocument();
      for (const label of [
        "Retenção ativada",
        "Metadados técnicos (dias)",
        "Inscrições nunca confirmadas (dias)",
        "Listas desativadas (meses)",
      ]) {
        expect(screen.getByRole("button", { name: `Configurar ${label}` })).not.toHaveTextContent("Em breve");
      }
    });

    it("mostra o painel de retenção só nas folhas canais.retencao.*", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      expect(screen.queryByText("Retenção dos dados das listas")).not.toBeInTheDocument();

      await fireEvent.click(screen.getByRole("button", { name: "Configurar Metadados técnicos (dias)" }));
      expect(await screen.findByText("Retenção dos dados das listas")).toBeInTheDocument();
      expect(await screen.findByTestId("ret-metadados-dias")).toHaveTextContent("90 dias");
      expect(screen.queryByText("Status do bot público")).not.toBeInTheDocument();

      await fireEvent.click(screen.getByRole("button", { name: "Configurar Modo de recebimento" }));
      await screen.findByText("Status do bot público");
      expect(screen.queryByText("Retenção dos dados das listas")).not.toBeInTheDocument();
    });

    it("salvar uma folha de retenção recarrega o painel com o prazo novo", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      await fireEvent.click(screen.getByRole("button", { name: "Configurar Metadados técnicos (dias)" }));
      await screen.findByTestId("ret-metadados-dias");
      const antes = getRetencaoStatusChamadas();

      await fireEvent.input(await screen.findByPlaceholderText("90"), { target: { value: "30" } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Configuração salva.", "success"));
      await waitFor(() => expect(getRetencaoStatusChamadas()).toBe(antes + 1));
      expect(await screen.findByTestId("ret-metadados-dias")).toHaveTextContent("30 dias");
    });

    it("mostra o painel de envios só nas folhas canais.envio.* (#216)", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      expect(screen.queryByText("Envios por e-mail das escolas")).not.toBeInTheDocument();

      await fireEvent.click(screen.getByRole("button", { name: "Configurar Cota diária por escola" }));
      expect(await screen.findByText("Envios por e-mail das escolas")).toBeInTheDocument();
      expect(await screen.findByTestId("env-cota")).toHaveTextContent("500 e-mails");
      expect(screen.queryByText("Retenção dos dados das listas")).not.toBeInTheDocument();

      await fireEvent.click(screen.getByRole("button", { name: "Configurar Metadados técnicos (dias)" }));
      await screen.findByText("Retenção dos dados das listas");
      expect(screen.queryByText("Envios por e-mail das escolas")).not.toBeInTheDocument();
    });

    it("salvar uma folha de envios recarrega o painel com o limite novo", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      await fireEvent.click(screen.getByRole("button", { name: "Configurar Cota diária por escola" }));
      await screen.findByTestId("env-cota");

      await fireEvent.input(await screen.findByPlaceholderText("500"), { target: { value: "800" } });
      await fireEvent.click(screen.getByRole("button", { name: "Salvar" }));

      await waitFor(() => expect(addToast).toHaveBeenCalledWith("Configuração salva.", "success"));
      await waitFor(() => expect(screen.getByTestId("env-cota")).toHaveTextContent("800 e-mails"));
    });

    it("tem o link para as versões do consentimento", async () => {
      render(ConfigPage);
      await screen.findByText(/Chave ainda não definida/);
      expect(screen.getByRole("link", { name: "Versões do consentimento" })).toHaveAttribute(
        "href",
        "/config/consentimento",
      );
    });
  });
});
