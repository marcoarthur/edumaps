// src/features/config/components/RetencaoStatus.test.js
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import RetencaoStatus from "./RetencaoStatus.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import {
  resetConfigMockState,
  setRetencaoMockState,
  setRetencaoMockErro,
  getRetencaoStatusChamadas,
} from "../mocks/configHandlers.js";
import { RETENCAO_STATUS, RETENCAO_JOB_ID } from "../mocks/configFixtures.js";

describe("RetencaoStatus", () => {
  beforeEach(() => {
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
  });
  afterEach(() => setApiToken(null));

  it("mostra prazos, agendamento e a última execução com contagens por regra", async () => {
    render(RetencaoStatus);
    expect(screen.getByText(/Carregando status da retenção/)).toBeInTheDocument();

    expect(await screen.findByTestId("ret-enabled")).toHaveTextContent("ativada");
    expect(screen.getByTestId("ret-agendado")).toHaveTextContent("agendada (diária)");
    expect(screen.getByTestId("ret-metadados-dias")).toHaveTextContent("90 dias");
    expect(screen.getByTestId("ret-pendentes-dias")).toHaveTextContent("180 dias");
    expect(screen.getByTestId("ret-listas-meses")).toHaveTextContent("12 meses");
    expect(screen.getByTestId("ret-ultima-em")).toHaveTextContent(
      new Date(RETENCAO_STATUS.ultima_execucao.em).toLocaleString("pt-BR"),
    );
    expect(screen.getByTestId("ret-ultima-metadados")).toHaveTextContent("4");
    expect(screen.getByTestId("ret-ultima-pendentes")).toHaveTextContent("2");
    expect(screen.getByTestId("ret-ultima-listas")).toHaveTextContent("0");
  });

  it("sem execução anterior, desligada e sem agendamento", async () => {
    setRetencaoMockState({ ...RETENCAO_STATUS, enabled: 0, agendado: 0, ultima_execucao: null });
    render(RetencaoStatus);
    expect(await screen.findByTestId("ret-enabled")).toHaveTextContent("desativada");
    expect(screen.getByTestId("ret-agendado")).toHaveTextContent("não agendada");
    expect(screen.getByTestId("ret-ultima")).toHaveTextContent("ainda não foi executada");
  });

  it("'Executar agora' (202) informa o job e recarrega o status", async () => {
    setRetencaoMockState({ ...RETENCAO_STATUS, ultima_execucao: null });
    render(RetencaoStatus);
    await screen.findByTestId("ret-ultima");
    const antes = getRetencaoStatusChamadas();

    await fireEvent.click(screen.getByRole("button", { name: "Executar agora" }));

    expect(await screen.findByTestId("ret-mensagem")).toHaveTextContent(`job ${RETENCAO_JOB_ID}`);
    expect(screen.getByTestId("ret-mensagem")).toHaveAttribute("role", "status");
    await waitFor(() => expect(getRetencaoStatusChamadas()).toBe(antes + 1));
    expect(await screen.findByTestId("ret-ultima-em")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Executar agora" })).toBeEnabled();
  });

  it("falha ao executar mostra o erro do backend", async () => {
    setRetencaoMockErro({ status: 409, error: "Execução já em andamento." });
    render(RetencaoStatus);
    await screen.findByTestId("ret-enabled");
    await fireEvent.click(screen.getByRole("button", { name: "Executar agora" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Execução já em andamento.");
  });

  it("erro ao carregar o status", async () => {
    setApiToken(null);
    render(RetencaoStatus);
    expect(await screen.findByRole("alert")).toHaveTextContent(/Faça login/);
  });
});
