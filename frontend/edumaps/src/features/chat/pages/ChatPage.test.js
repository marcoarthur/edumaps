// src/features/chat/pages/ChatPage.test.js
// Assistente do Censo (#224): login obrigatório, escopo vindo do servidor
// (somente leitura), pergunta sem contexto, 401 no polling → login, resposta
// em markdown seguro e gráfico pelos wrappers Carbon (MSW, sem mocks de API).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { server } from "../../../mocks/server.js";
import {
  resetChatMockState,
  setChatMockResultado,
  setChatMockFalha,
  getUltimoAsk,
  CHAT_RESULTADO_FIXTURE,
} from "../mocks/chatHandlers.js";
import ChatPage from "./ChatPage.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

const PLACEHOLDER = "Pergunte sobre o Censo Escolar...";
const MSG_LOGIN = "Entre para usar o Assistente do Censo.";

async function perguntar(texto) {
  const input = await screen.findByPlaceholderText(PLACEHOLDER);
  await fireEvent.input(input, { target: { value: texto } });
  await fireEvent.click(screen.getByRole("button", { name: "Enviar pergunta" }));
  // a página consulta o progresso a cada 1500 ms
  await vi.advanceTimersByTimeAsync(1600);
}

describe("ChatPage", () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"], shouldAdvanceTime: true });
    resetChatMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });

  afterEach(() => {
    vi.useRealTimers();
    setApiToken(null);
  });

  it("sem sessão mostra o login e não mostra o chat", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(ChatPage);
    expect(await screen.findByText(MSG_LOGIN)).toBeInTheDocument();
    expect(screen.queryByPlaceholderText(PLACEHOLDER)).toBeNull();
    expect(screen.queryByRole("button", { name: "Salvar conversa" })).toBeNull();
  });

  it("mostra o escopo vindo do servidor, sem campos editáveis de contexto", async () => {
    render(ChatPage);
    const escopo = await screen.findByTestId("chat-escopo");
    expect(escopo).toHaveTextContent("EEEF Professora Maria de Lourdes");
    expect(escopo).toHaveTextContent("Porto Velho (RO)");
    expect(within(escopo).queryByRole("textbox")).toBeNull();
    expect(screen.queryByDisplayValue("Porto Velho")).toBeNull();
    // apenas o campo da pergunta
    expect(screen.getAllByRole("textbox")).toHaveLength(1);
  });

  it("envia só a pergunta (sem contexto) e renderiza a resposta em markdown", async () => {
    render(ChatPage);
    await perguntar("Quantas escolas ativas existem?");

    const resposta = await screen.findByTestId("chat-resposta");
    expect(getUltimoAsk()).toEqual({ pergunta: "Quantas escolas ativas existem?" });
    expect(within(resposta).getByText("1.588").tagName).toBe("STRONG");
    expect(within(resposta).getAllByRole("listitem")).toHaveLength(2);
    expect(resposta).not.toHaveTextContent("**");
    expect(screen.getByText("Quantas escolas ativas existem?")).toBeInTheDocument();
  });

  it("não interpreta HTML na resposta", async () => {
    setChatMockResultado({ resposta: "<img src=x onerror=alert(1)> **ok**" });
    const { container } = render(ChatPage);
    await perguntar("Teste");
    const resposta = await screen.findByTestId("chat-resposta");
    expect(container.querySelector("img")).toBeNull();
    expect(resposta).toHaveTextContent("<img src=x onerror=alert(1)>");
  });

  it("desenha o gráfico da resposta com descrição e tabela de dados", async () => {
    render(ChatPage);
    await perguntar("Escolas por rede");

    const grafico = await screen.findByTestId("chat-grafico");
    expect(grafico).toHaveAttribute("data-grafico", "barra");
    expect(within(grafico).getByTestId("carbon-chart-stub")).toHaveAttribute("data-rows", "2");
    expect(within(grafico).getByTestId("chat-grafico-descricao")).toHaveTextContent(
      'Gráfico de barras "Escolas por rede" por rede. Municipal: 1.200; Estadual: 388.',
    );
    const tabela = within(grafico).getByRole("table", { name: "Dados: Escolas por rede" });
    expect(within(tabela).getByRole("rowheader", { name: "Municipal" })).toBeInTheDocument();
    expect(within(tabela).getByText("1.200")).toBeInTheDocument();
  });

  it("chart ausente ou irreconhecível é ignorado sem quebrar", async () => {
    setChatMockResultado({ ...CHAT_RESULTADO_FIXTURE, chart: { data: [{ type: "heatmap", z: [1] }] } });
    render(ChatPage);
    await perguntar("Primeira");
    await screen.findByTestId("chat-resposta");
    expect(screen.queryByTestId("chat-grafico")).toBeNull();

    setChatMockResultado({ ...CHAT_RESULTADO_FIXTURE, chart: null });
    await perguntar("Segunda");
    await waitFor(() => expect(screen.getAllByTestId("chat-resposta")).toHaveLength(2));
    expect(screen.queryByTestId("chat-grafico")).toBeNull();
  });

  it("401 no polling volta ao login", async () => {
    render(ChatPage);
    await screen.findByTestId("chat-escopo");
    server.use(
      http.get("/api/chat/progress", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    await perguntar("Pergunta com sessão expirada");
    expect(await screen.findByText(MSG_LOGIN)).toBeInTheDocument();
    expect(screen.queryByPlaceholderText(PLACEHOLDER)).toBeNull();
  });

  it("401 no ask volta ao login", async () => {
    render(ChatPage);
    await screen.findByTestId("chat-escopo");
    server.use(
      http.post("/api/chat/ask", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    await perguntar("Outra");
    expect(await screen.findByText(MSG_LOGIN)).toBeInTheDocument();
  });

  it("login pelo cartão libera o chat", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(ChatPage);
    await screen.findByText(MSG_LOGIN);
    await fireEvent.input(screen.getByLabelText(/e-mail/i), { target: { value: "marina@edu.gov.br" } });
    await fireEvent.input(screen.getByLabelText(/senha/i), { target: { value: "senha123" } });
    await fireEvent.click(screen.getByRole("button", { name: "Entrar" }));
    expect(await screen.findByTestId("chat-escopo")).toBeInTheDocument();
    expect(screen.getByPlaceholderText(PLACEHOLDER)).toBeInTheDocument();
  });

  it("mostra erro quando o job falha", async () => {
    setChatMockFalha("serviço indisponível");
    render(ChatPage);
    await perguntar("Teste de falha");
    await waitFor(() => {
      expect(screen.getAllByText(/serviço indisponível|Erro ao consultar/).length).toBeGreaterThan(0);
    });
  });

  it("limpa a conversa", async () => {
    render(ChatPage);
    await perguntar("Oi");
    await screen.findByTestId("chat-resposta");
    await fireEvent.click(screen.getByRole("button", { name: "Limpar conversa" }));
    expect(
      await screen.findByText("Nenhuma mensagem ainda. Envie sua primeira pergunta!"),
    ).toBeInTheDocument();
  });
});
