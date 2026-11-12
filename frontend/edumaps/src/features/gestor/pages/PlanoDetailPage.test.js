// src/features/gestor/pages/PlanoDetailPage.test.js — acompanhamento e edição (#371).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, within } from "@testing-library/svelte";
import PlanoDetailPage from "./PlanoDetailPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { addToast } from "@/shared/stores/toastStore.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetPlanosMock } from "../mocks/planosHandlers.js";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const abrir = (id) => {
  window.history.pushState({}, "", `/gestor/planos/${id}`);
  return render(PlanoDetailPage);
};

describe("PlanoDetailPage", () => {
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

  it("mostra o andamento com N de M e a meta oficial com fonte", async () => {
    abrir(1);
    expect(await screen.findByRole("heading", { name: "Plano de ação 2026" })).toBeInTheDocument();
    // meta do IDEB: base 5,0 → alvo 6,0, atual 5,4 (2023) = 40%; meta manual sem medição
    expect(screen.getByLabelText("Progresso da meta Subir o IDEB dos anos iniciais: 40%")).toBeInTheDocument();
    expect(screen.getAllByText("1 de 2 meta(s) medida(s)").length).toBeGreaterThan(0);
    expect(screen.getByText(/INEP — IDEB · base 5 → alvo 6/)).toBeInTheDocument();
    expect(screen.getByText("Sem medição")).toBeInTheDocument();
    expect(screen.queryByText("0%")).not.toBeInTheDocument();
  });

  it("leva ao relatório de acompanhamento (#374)", async () => {
    abrir(1);
    await screen.findByRole("heading", { name: "Plano de ação 2026" });
    expect(screen.getByRole("link", { name: "🖨️ Relatório" })).toHaveAttribute("href", "/gestor/planos/1/relatorio");
  });

  it("textos com os espaços certos (separadores e unidade)", async () => {
    abrir(1);
    await screen.findByRole("heading", { name: "Plano de ação 2026" });
    const txt = document.body.textContent.replace(/\s+/g, " ");
    expect(txt).toContain("alvo 6 pontos (0 a 10) · atual 5,4 (2023)");
    expect(txt).toContain("prazo 05/03/2026 · Coordenação · R$ 1.500 (PDDE) · meta: Subir o IDEB dos anos iniciais");
    expect(txt).toContain("Reforço de leitura · prazo 05/03/2026 · Coordenação");
    expect(txt).toContain("Conselho escolar de fevereiro · 20/02/2026");
    expect(txt).not.toMatch(/\S·|\d[a-z]/);
  });

  it("destaca a ação atrasada", async () => {
    abrir(1);
    await screen.findByRole("heading", { name: "Plano de ação 2026" });
    expect(screen.getByRole("heading", { name: "Atrasadas" })).toBeInTheDocument();
    expect(screen.getAllByText("atrasada").length).toBe(1);
  });

  it("registra uma medição manual e o progresso aparece", async () => {
    abrir(1);
    await screen.findByText("Reduzir faltas");
    await fireEvent.click(screen.getByRole("button", { name: "+ Registrar medição" }));
    await fireEvent.input(screen.getByLabelText("Valor"), { target: { value: "16" } });
    await fireEvent.click(screen.getByRole("button", { name: "Registrar" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Medição registrada.", "success"));
    // reduzir 20 → 12, atual 16 = 50%
    expect(await screen.findByLabelText("Progresso da meta Reduzir faltas: 50%")).toBeInTheDocument();
    expect(screen.getAllByText("2 de 2 meta(s) medida(s)").length).toBeGreaterThan(0);
  });

  it("adiciona meta ligada a indicador oficial com o último valor da escola", async () => {
    abrir(1);
    await screen.findByText("Melhorar a aprendizagem");
    await fireEvent.click(screen.getByRole("button", { name: "+ Meta" }));
    await fireEvent.change(screen.getByLabelText("Indicador oficial (opcional)"), { target: { value: "matriculas_total" } });
    expect(screen.getByText(/Último valor da escola: 320 \(2025\)/)).toBeInTheDocument();
    await fireEvent.input(screen.getByLabelText("Alvo"), { target: { value: "350" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar meta" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Meta adicionada.", "success"));
    expect(await screen.findByText("Matrículas — total da educação básica")).toBeInTheDocument();
  });

  it("indicador sem dado da escola avisa que a meta fica sem dado", async () => {
    abrir(1);
    await screen.findByText("Melhorar a aprendizagem");
    await fireEvent.click(screen.getByRole("button", { name: "+ Meta" }));
    await fireEvent.change(screen.getByLabelText("Indicador oficial (opcional)"), { target: { value: "infra_quadra" } });
    expect(screen.getByText(/A fonte não tem valor desta escola/)).toBeInTheDocument();
  });

  it("adiciona uma ação e conclui", async () => {
    abrir(1);
    await screen.findByText("Melhorar a aprendizagem");
    await fireEvent.click(screen.getByRole("button", { name: "+ Ação" }));
    await fireEvent.input(screen.getByPlaceholderText("Ex.: Reforço de leitura no contraturno"), { target: { value: "Formação de professores" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar ação" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Ação adicionada.", "success"));
    const select = await screen.findByLabelText("Situação de Formação de professores");
    await fireEvent.change(select, { target: { value: "concluida" } });
    await waitFor(() => expect(screen.getByText(/1 de 3 ação\(ões\) concluída\(s\)/)).toBeInTheDocument());
  });

  it("plano encerrado é só leitura e pode ser reaberto", async () => {
    abrir(2);
    expect(await screen.findByRole("heading", { name: "PPP 2025" })).toBeInTheDocument();
    expect(screen.getByText("Plano encerrado: só leitura.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "+ Objetivo" })).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Reabrir plano" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Plano reaberto.", "success"));
    expect(await screen.findByRole("button", { name: "+ Objetivo" })).toBeInTheDocument();
  });

  it("desliga os alertas de prazo", async () => {
    abrir(1);
    await screen.findByRole("heading", { name: "Plano de ação 2026" });
    await fireEvent.click(screen.getByLabelText("Receber alertas de prazo por e-mail"));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Alertas de prazo desligados.", "success"));
  });
});
