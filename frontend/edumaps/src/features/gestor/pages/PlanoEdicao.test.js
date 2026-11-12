// src/features/gestor/pages/PlanoEdicao.test.js — editar objetivos, metas e ações (#383).
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
const texto = () => document.body.textContent.replace(/\s+/g, " ");

describe("Edição do plano", () => {
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

  it("edita a ação e mantém as evidências", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Editar ação Reforço de leitura" }));
    const descricao = screen.getByDisplayValue("Reforço de leitura");
    expect(screen.getByDisplayValue("Coordenação")).toBeInTheDocument();
    expect(screen.getByDisplayValue("2026-03-05")).toBeInTheDocument();
    await fireEvent.input(descricao, { target: { value: "Reforço de leitura no contraturno" } });
    await fireEvent.input(screen.getByDisplayValue("Coordenação"), { target: { value: "Equipe pedagógica" } });
    await fireEvent.input(screen.getByDisplayValue("2026-03-05"), { target: { value: "2026-04-30" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Ação atualizada.", "success"));
    await waitFor(() => expect(texto()).toContain("prazo 30/04/2026 · Equipe pedagógica"));
    // as evidências continuam ligadas à ação
    expect(within(screen.getByLabelText("Evidências de Reforço de leitura no contraturno"))
      .getByRole("link", { name: "Conselho escolar de fevereiro" })).toBeInTheDocument();
  });

  it("não salva a ação com prazo antes do início", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Editar ação Reforço de leitura" }));
    await fireEvent.input(screen.getByDisplayValue("2026-03-05"), { target: { value: "2026-01-01" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));
    expect(addToast).toHaveBeenCalledWith("O prazo da ação não pode ser antes do início.", "warning");
    expect(screen.getByRole("button", { name: "Salvar alterações" })).toBeInTheDocument();
  });

  it("edita a meta manual e o andamento acompanha", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Editar meta Reduzir faltas" }));
    expect(screen.getByText(/Meta manual\. O tipo da meta não muda na edição/)).toBeInTheDocument();
    expect(screen.getByText(/de onde o andamento é medido até o alvo/)).toBeInTheDocument();
    await fireEvent.input(screen.getByDisplayValue("12"), { target: { value: "10" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Meta atualizada.", "success"));
    await waitFor(() => expect(texto()).toContain("base 20 → alvo 10 %"));
  });

  it("meta oficial: o indicador não muda na edição", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Editar meta Subir o IDEB dos anos iniciais" }));
    expect(screen.getByText(/Indicador oficial: IDEB — anos iniciais\./)).toBeInTheDocument();
    expect(screen.queryByLabelText("Indicador oficial (opcional)")).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Cancelar" }));
    expect(screen.getByRole("button", { name: "Editar meta Subir o IDEB dos anos iniciais" })).toBeInTheDocument();
  });

  it("edita o título do objetivo", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Editar objetivo Melhorar a aprendizagem" }));
    await fireEvent.input(screen.getByDisplayValue("Melhorar a aprendizagem"),
      { target: { value: "Melhorar a aprendizagem em leitura" } });
    await fireEvent.click(screen.getByRole("button", { name: "Salvar alterações" }));
    await waitFor(() => expect(addToast).toHaveBeenCalledWith("Objetivo atualizado.", "success"));
    expect(await screen.findByRole("heading", { name: "Melhorar a aprendizagem em leitura" })).toBeInTheDocument();
  });

  it("plano encerrado não mostra os botões de editar", async () => {
    await abrir();
    await fireEvent.click(screen.getByRole("button", { name: "Encerrar plano" }));
    await screen.findByRole("button", { name: "Reabrir plano" });
    expect(screen.queryByRole("button", { name: /^Editar / })).not.toBeInTheDocument();
  });

  it("gráfico da meta com legenda e os anos", async () => {
    await abrir();
    const fig = screen.getByRole("img", { name: "Histórico de Subir o IDEB dos anos iniciais" }).closest("figure");
    const t = fig.textContent.replace(/\s+/g, " ");
    expect(t).toContain("2021");
    expect(t).toContain("2023");
    expect(t).toContain("linha de base (5)");
    expect(t).toContain("alvo (6)");
  });
});
