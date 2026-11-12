// src/features/gestor/pages/PlanoRelatorioPage.test.js — relatório de acompanhamento (#374).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, within } from "@testing-library/svelte";
import PlanoRelatorioPage from "./PlanoRelatorioPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetPlanosMock } from "../mocks/planosHandlers.js";

const abrir = async (id = 1) => {
  window.history.pushState({}, "", `/gestor/planos/${id}/relatorio`);
  render(PlanoRelatorioPage);
};
const linhaDe = (texto) => screen.getByText(texto).closest("tr");

describe("PlanoRelatorioPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetPlanosMock();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("cabeçalho com escola, plano, período e emissão", async () => {
    await abrir();
    expect(await screen.findByRole("heading", { level: 1, name: "Plano de ação 2026" })).toBeInTheDocument();
    expect(screen.getByText(/Escola Estadual Teste · INEP 11000040/)).toBeInTheDocument();
    expect(screen.getByText(/Porto Velho\/RO/)).toBeInTheDocument();
    expect(screen.getByText(/período 01\/02\/2026 a 15\/12\/2026/)).toBeInTheDocument();
    expect(screen.getByText("Emitido em 10/03/2026 às 14:30")).toBeInTheDocument();
  });

  it("indicador oficial com fonte e ano; sem medição em texto, nunca 0%", async () => {
    await abrir();
    await screen.findByRole("heading", { level: 1 });
    const ideb = within(linhaDe("Subir o IDEB dos anos iniciais"));
    expect(ideb.getByText("INEP — IDEB, 2023")).toBeInTheDocument();
    expect(ideb.getByText("40%")).toBeInTheDocument();
    const faltas = within(linhaDe("Reduzir faltas"));
    expect(faltas.getByText("Medição da escola")).toBeInTheDocument();
    expect(faltas.getByText("Sem medição")).toBeInTheDocument();
    expect(screen.queryByText("0%")).not.toBeInTheDocument();
    expect(screen.getByText(/1 de 2 meta\(s\) medida\(s\)/)).toBeInTheDocument();
  });

  it("ações por situação e evidências, com origem removida", async () => {
    await abrir();
    await screen.findByRole("heading", { level: 1 });
    expect(screen.getByRole("heading", { name: "Atrasadas (1)" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Não iniciadas (1)" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: /Concluídas/ })).not.toBeInTheDocument();
    expect(within(linhaDe("Reforço de leitura")).getByText("Coordenação")).toBeInTheDocument();

    const ev = screen.getByRole("heading", { name: "Evidências" }).parentElement;
    expect(within(ev).getByText("Conselho escolar de fevereiro")).toBeInTheDocument();
    expect(within(ev).getByText("Projeto de leitura (v1) (origem removida)")).toBeInTheDocument();
    expect(within(ev).getByText("Chamada conferida pela secretaria.")).toBeInTheDocument();
    expect(screen.getByText("3 evidência(s) registrada(s)")).toBeInTheDocument();
  });

  it("textos com os espaços certos", async () => {
    await abrir();
    await screen.findByRole("heading", { level: 1 });
    expect(linhaDe("Medição da escola").cells[0].textContent).toBe("Reduzir faltas (reduzir, %)");
    const faltas = linhaDe("Medição da escola").cells;
    expect([faltas[2].textContent, faltas[3].textContent]).toEqual(["20%", "12%"]);
    expect(screen.getByText("Subir o IDEB dos anos iniciais", { exact: false }).closest("td").textContent)
      .toBe("Subir o IDEB dos anos iniciais (aumentar, pontos (0 a 10))");
    expect(screen.getByText(/INEP 11000040/).textContent.replace(/\s+/g, " ").trim())
      .toBe("Escola Estadual Teste · INEP 11000040 · Porto Velho/RO");
    expect(screen.getByText("Ata de reunião", { exact: false }).textContent).toBe("Ata de reunião (20/02/2026)");
  });

  it("custo previsto por fonte e nas ações; sem custo não é R$ 0 (#384)", async () => {
    await abrir();
    await screen.findByRole("heading", { level: 1 });
    const sec = within(screen.getByRole("heading", { name: "Custo previsto por fonte de recurso" }).parentElement);
    const pdde = sec.getByText("PDDE").closest("tr");
    expect(pdde.textContent.replace(/\s+/g, " ")).toMatch(/PDDE\s*1\s*R\$\s*1\.500,00/);
    expect(sec.getByText("Total").closest("tr").textContent).toMatch(/R\$\s*1\.500,00/);
    expect(sec.getByText(/1 ação\(ões\) sem custo informado/)).toBeInTheDocument();
    const reforco = linhaDe("Reforço de leitura");
    expect(reforco.textContent).toMatch(/R\$\s*1\.500,00/);
    expect(within(reforco).getByText("PDDE")).toBeInTheDocument();
    const busca = within(linhaDe("Busca ativa"));
    expect(busca.getAllByText("—").length).toBeGreaterThanOrEqual(2);
    expect(linhaDe("Busca ativa").textContent).not.toMatch(/R\$\s*0/);
  });

  it("imprime pelo navegador", async () => {
    const print = vi.spyOn(window, "print").mockImplementation(() => {});
    await abrir();
    await fireEvent.click(await screen.findByRole("button", { name: "Imprimir / salvar PDF" }));
    expect(print).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("link", { name: "← Plano" })).toHaveAttribute("href", "/gestor/planos/1");
  });

  it("sem sessão pede login", async () => {
    clearSessaoToken();
    setApiToken(null);
    await abrir();
    expect(await screen.findByText("Entre para gerar o relatório do plano.")).toBeInTheDocument();
  });

  it("plano inexistente mostra o erro", async () => {
    await abrir(999);
    expect(await screen.findByText(/não encontrado/)).toBeInTheDocument();
  });
});
