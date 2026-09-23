// src/features/chat/pages/ChatPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import ChatPage from "./ChatPage.svelte";
import { askChat, getChatProgress } from "../api/chatApi.js";
import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
import { getGestorPanel } from "@/features/gestor/api/gestorApi.js";
import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";

vi.mock("../api/chatApi.js", () => ({
  askChat: vi.fn(),
  getChatProgress: vi.fn(),
  extractSql: (r) => r?.sql ?? null,
  extractResposta: (r) => r?.resposta ?? null,
  extractResultado: (r) => r?.resultado ?? null,
  extractOrigem: (r) => (Array.isArray(r?.origem) ? r.origem : []),
  extractMeta: (r) => ({ linhas: r?.linhas ?? 0, colunas: r?.colunas ?? 0 }),
}));

vi.mock("@/features/gestor/api/gestorPesquisasApi.js", () => ({
  fetchMe: vi.fn(),
}));

vi.mock("@/features/gestor/api/gestorApi.js", () => ({
  getGestorPanel: vi.fn(),
}));

vi.mock("@/features/gestor/utils/gestorAuth.js", () => ({
  restaurarSessao: vi.fn(),
}));

const RESULTADO = {
  cache_hit: 0,
  resposta: "Existem 1.588 escolas ativas no município.",
  sql: "SELECT COUNT(*) FROM clean.censo_escolas WHERE co_municipio = 3550308",
  linhas: 1,
  colunas: 1,
  origem: ["clean.censo_escolas"],
  resultado: { total_escolas: 1588 },
};

// A página faz polling a cada 1500ms. Com fake timers, avançamos o relógio
// manualmente para não esperar o intervalo real nos testes.
function advancePolling(ms = 1600) {
  return vi.advanceTimersByTimeAsync(ms);
}

describe("ChatPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    // Por padrão, sem sessão de gestor (formulário manual).
    restaurarSessao.mockReturnValue(false);
    fetchMe.mockResolvedValue(null);
    getGestorPanel.mockResolvedValue(null);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renderiza o título e o input de pergunta", () => {
    render(ChatPage);
    expect(screen.getByText("Assistente do Censo")).toBeInTheDocument();
    expect(
      screen.getByPlaceholderText("Pergunte sobre o Censo Escolar..."),
    ).toBeInTheDocument();
  });

  it("desabilita o botão de envio com input vazio", () => {
    render(ChatPage);
    const button = screen.getByRole("button", { name: "Enviar pergunta" });
    expect(button).toBeDisabled();
  });

  it("envia a pergunta e mostra a resposta do assistente", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    askChat.mockResolvedValue({ task: "chat", job_id: 42 });
    getChatProgress.mockResolvedValue({ state: "finished", result: RESULTADO });

    render(ChatPage);
    const input = screen.getByPlaceholderText("Pergunte sobre o Censo Escolar...");
    await user.type(input, "Quantas escolas ativas existem?");

    const button = screen.getByRole("button", { name: "Enviar pergunta" });
    expect(button).not.toBeDisabled();
    await user.click(button);

    await advancePolling();

    await waitFor(() => {
      expect(
        screen.getByText("Existem 1.588 escolas ativas no município."),
      ).toBeInTheDocument();
    });
    expect(screen.getByText("Quantas escolas ativas existem?")).toBeInTheDocument();

    expect(askChat).toHaveBeenCalledWith({
      pergunta: "Quantas escolas ativas existem?",
      contexto: {
        cod_municipio: undefined,
        cod_inep: undefined,
        nome_municipio: undefined,
        nome_escola: undefined,
        sg_uf: undefined,
      },
    });
  });

  it("mostra erro quando o job falha", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    askChat.mockResolvedValue({ task: "chat", job_id: 7 });
    getChatProgress.mockResolvedValue({
      state: "failed",
      error: "serviço indisponível",
    });

    render(ChatPage);
    const input = screen.getByPlaceholderText("Pergunte sobre o Censo Escolar...");
    await user.type(input, "Teste de falha");
    await user.click(screen.getByRole("button", { name: "Enviar pergunta" }));

    await advancePolling();

    await waitFor(() => {
      expect(
        screen.getByText("Erro ao consultar o Assistente do Censo."),
      ).toBeInTheDocument();
    });
  });

  it("limpa a conversa", async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    askChat.mockResolvedValue({ task: "chat", job_id: 1 });
    getChatProgress.mockResolvedValue({ state: "finished", result: RESULTADO });

    render(ChatPage);
    const input = screen.getByPlaceholderText("Pergunte sobre o Censo Escolar...");
    await user.type(input, "Oi");
    await user.click(screen.getByRole("button", { name: "Enviar pergunta" }));

    await advancePolling();

    await waitFor(() => {
      expect(
        screen.getByText("Existem 1.588 escolas ativas no município."),
      ).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: "Limpar conversa" }));
    await waitFor(() => {
      expect(
        screen.getByText("Nenhuma mensagem ainda. Envie sua primeira pergunta!"),
      ).toBeInTheDocument();
    });
  });

  it("pré-preenche o escopo com a escola do gestor logado", async () => {
    restaurarSessao.mockReturnValue(true);
    fetchMe.mockResolvedValue({ id: 7, cod_inep: 11000040, nome: "Rovai", email: "rovai@edumaps.dev" });
    getGestorPanel.mockResolvedValue({
      escola: {
        cod_inep: 11000040,
        cod_municipio: 1100205,
        nome: "EE Machado de Assis",
        municipio: "Porto Velho",
        uf: "RO",
      },
    });

    render(ChatPage);

    await waitFor(() => {
      expect(fetchMe).toHaveBeenCalled();
    });
    await waitFor(() => {
      expect(getGestorPanel).toHaveBeenCalledWith("11000040");
    });

    const inepInput = screen.getByDisplayValue("11000040");
    expect(inepInput).toBeInTheDocument();
    expect(screen.getByDisplayValue("EE Machado de Assis")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Porto Velho")).toBeInTheDocument();
    expect(screen.getByDisplayValue("1100205")).toBeInTheDocument();
    expect(screen.getByDisplayValue("RO")).toBeInTheDocument();
  });
});
