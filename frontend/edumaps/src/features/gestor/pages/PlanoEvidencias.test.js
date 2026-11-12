// src/features/gestor/pages/PlanoEvidencias.test.js — evidências das ações e metas (#372).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import PlanoDetailPage from "./PlanoDetailPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetPlanosMock } from "../mocks/planosHandlers.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const abrir = async () => {
  window.history.pushState({}, "", "/gestor/planos/1");
  render(PlanoDetailPage);
  await screen.findByRole("heading", { name: "Plano de ação 2026" });
};
const bloco = (rotulo) => screen.getByLabelText(`Evidências de ${rotulo}`);

describe("Evidências do plano", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetPlanosMock();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    vi.clearAllMocks();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("mostra a ata com link, a nota e a origem removida", async () => {
    await abrir();
    const acao = bloco("Reforço de leitura");
    expect(within(acao).getByRole("link", { name: "Conselho escolar de fevereiro" }))
      .toHaveAttribute("href", "/gestor/reunioes/70");
    expect(within(acao).getByText("Projeto de leitura (v1)")).toBeInTheDocument();
    expect(within(acao).getByText("origem removida")).toBeInTheDocument();
    expect(within(acao).queryByRole("button", { name: "Projeto de leitura (v1)" })).not.toBeInTheDocument();
    expect(within(bloco("Reduzir faltas")).getByText("Chamada conferida pela secretaria.")).toBeInTheDocument();
  });

  it("liga a ata de uma reunião a uma ação", async () => {
    await abrir();
    const acao = bloco("Busca ativa");
    await fireEvent.click(within(acao).getByRole("button", { name: "+ Evidência" }));
    const reuniao = await within(acao).findByLabelText("Reunião");
    expect(within(acao).getByRole("button", { name: "Ligar evidência" })).toBeDisabled();
    await fireEvent.change(reuniao, { target: { value: "71" } });
    await fireEvent.click(within(acao).getByRole("button", { name: "Ligar evidência" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Evidência ligada.", "success"));
    expect(await within(bloco("Busca ativa")).findByRole("link", { name: "Reunião de pais do 5º ano" }))
      .toHaveAttribute("href", "/gestor/reunioes/71");
  });

  it("liga uma versão de documento a uma meta", async () => {
    await abrir();
    const meta = bloco("Reduzir faltas");
    await fireEvent.click(within(meta).getByRole("button", { name: "+ Evidência" }));
    await fireEvent.click(await within(meta).findByLabelText("Documento"));
    await fireEvent.change(await within(meta).findByLabelText("Documento (versão)"), { target: { value: "81" } });
    await fireEvent.click(within(meta).getByRole("button", { name: "Ligar evidência" }));
    expect(await within(bloco("Reduzir faltas")).findByRole("button", { name: "PPP 2026 (v2)" })).toBeInTheDocument();
  });

  it("registra uma nota", async () => {
    await abrir();
    const meta = bloco("Subir o IDEB dos anos iniciais");
    await fireEvent.click(within(meta).getByRole("button", { name: "+ Evidência" }));
    await fireEvent.click(await within(meta).findByLabelText("Nota"));
    await fireEvent.input(await within(meta).findByRole("textbox"), { target: { value: "Simulado de leitura aplicado." } });
    await fireEvent.click(within(meta).getByRole("button", { name: "Ligar evidência" }));
    expect(await within(bloco("Subir o IDEB dos anos iniciais")).findByText("Simulado de leitura aplicado."))
      .toBeInTheDocument();
  });

  it("avisa quando a evidência já está ligada", async () => {
    await abrir();
    const acao = bloco("Reforço de leitura");
    await fireEvent.click(within(acao).getByRole("button", { name: "+ Evidência" }));
    await fireEvent.change(await within(acao).findByLabelText("Reunião"), { target: { value: "70" } });
    await fireEvent.click(within(acao).getByRole("button", { name: "Ligar evidência" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Esta evidência já está ligada.", "error"));
  });

  it("retira uma evidência sem apagar a origem", async () => {
    await abrir();
    await fireEvent.click(within(bloco("Reduzir faltas"))
      .getByRole("button", { name: "Retirar evidência Chamada conferida pela secretaria." }));
    expect(window.confirm).toHaveBeenCalledWith(expect.stringMatching(/não são apagados/));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Evidência retirada.", "success"));
    await waitFor(() =>
      expect(screen.queryByText("Chamada conferida pela secretaria.")).not.toBeInTheDocument());
  });

  it("plano encerrado: evidências só para leitura", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Encerrar plano" }));
    await screen.findByRole("button", { name: "Reabrir plano" });
    expect(screen.queryByRole("button", { name: "+ Evidência" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Retirar evidência/ })).not.toBeInTheDocument();
    expect(within(bloco("Reforço de leitura")).getByRole("link", { name: "Conselho escolar de fevereiro" }))
      .toBeInTheDocument();
  });
});
