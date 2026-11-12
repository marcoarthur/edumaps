// src/features/gestor/pages/PlanoDocumento.test.js — plano ligado ao arquivo em Documentos e planos (#385).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import PlanoDetailPage from "./PlanoDetailPage.svelte";
import PlanosPage from "./PlanosPage.svelte";
import PlanoRelatorioPage from "./PlanoRelatorioPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetPlanosMock } from "../mocks/planosHandlers.js";
import { updatePlano, getPlano } from "../api/gestorPlanosApi.js";
import { INEP_PLANOS } from "../mocks/planosFixtures.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const abrirPlano = async (id = 1) => {
  window.history.pushState({}, "", `/gestor/planos/${id}`);
  render(PlanoDetailPage);
  await screen.findByRole("group", { name: "Arquivo do plano" });
};
const arquivo = () => within(screen.getByRole("group", { name: "Arquivo do plano" }));

describe("Arquivo do plano", () => {
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

  it("liga, troca e desliga o arquivo do plano", async () => {
    await abrirPlano();
    expect(arquivo().getByText("Nenhum arquivo ligado.")).toBeInTheDocument();
    await fireEvent.click(arquivo().getByRole("button", { name: "Ligar arquivo de Documentos e planos" }));
    await fireEvent.change(await arquivo().findByLabelText("Documento do plano"), { target: { value: "10" } });
    await fireEvent.click(arquivo().getByRole("button", { name: "Ligar" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Arquivo do plano ligado.", "success"));
    expect(await arquivo().findByRole("button", { name: "📄 PPP da escola.pdf (v2)" })).toBeInTheDocument();

    await fireEvent.click(arquivo().getByRole("button", { name: "Trocar" }));
    await fireEvent.change(await arquivo().findByLabelText("Documento do plano"), { target: { value: "11" } });
    await fireEvent.click(arquivo().getByRole("button", { name: "Ligar" }));
    expect(await arquivo().findByRole("button", { name: "📄 Regimento interno.docx (v1)" })).toBeInTheDocument();

    await fireEvent.click(arquivo().getByRole("button", { name: "Desligar" }));
    expect(window.confirm).toHaveBeenCalledWith(expect.stringMatching(/continua em Documentos e planos/));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Arquivo do plano desligado.", "success"));
    expect(await arquivo().findByText("Nenhum arquivo ligado.")).toBeInTheDocument();
  });

  it("plano encerrado: mostra o arquivo, sem trocar nem desligar", async () => {
    await updatePlano(INEP_PLANOS, 2, { situacao: "vigente" });
    await updatePlano(INEP_PLANOS, 2, { documento_id: 10 });
    await updatePlano(INEP_PLANOS, 2, { situacao: "encerrado" });
    await abrirPlano(2);
    expect(arquivo().getByRole("button", { name: "📄 PPP da escola.pdf (v2)" })).toBeInTheDocument();
    expect(arquivo().queryByRole("button", { name: "Trocar" })).not.toBeInTheDocument();
    expect(arquivo().queryByRole("button", { name: "Desligar" })).not.toBeInTheDocument();
  });

  it("cria o plano já ligado ao arquivo", async () => {
    const original = window.location;
    delete window.location;
    window.location = { ...original, href: original.href };
    render(PlanosPage);
    await screen.findByText("Plano de ação 2026");
    await fireEvent.click(screen.getByRole("button", { name: "+ Novo plano" }));
    await fireEvent.input(screen.getByPlaceholderText("Ex.: Plano de ação 2026"), { target: { value: "PPP 2027" } });
    await fireEvent.change(await screen.findByLabelText("Arquivo do plano (opcional)"), { target: { value: "10" } });
    await fireEvent.click(screen.getByRole("button", { name: "Criar plano" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Plano criado.", "success"));
    const id = Number(window.location.href.match(/\/gestor\/planos\/(\d+)$/)[1]);
    window.location = original;
    expect((await getPlano(INEP_PLANOS, id)).documento).toEqual({ id: 10, nome: "PPP da escola.pdf", versao_atual: 2 });
  });

  it("o relatório traz o arquivo do plano", async () => {
    await updatePlano(INEP_PLANOS, 1, { documento_id: 10 });
    window.history.pushState({}, "", "/gestor/planos/1/relatorio");
    render(PlanoRelatorioPage);
    expect(await screen.findByText("Arquivo do plano: PPP da escola.pdf (versão 2)")).toBeInTheDocument();
  });
});
