// src/features/gestor/components/relatorios/Secoes.test.js
// Componentes de seção do Assistente de Relatório (#219).
import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/svelte";
import SecaoTexto from "./SecaoTexto.svelte";
import SecaoIndicadores from "./SecaoIndicadores.svelte";
import SecaoTabela from "./SecaoTabela.svelte";
import SecaoGrafico from "./SecaoGrafico.svelte";
import { RELATORIO_RESULT_FIXTURE } from "../../mocks/relatoriosFixtures.js";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

const secao = (id) => RELATORIO_RESULT_FIXTURE.secoes.find((s) => s.id === id);

describe("SecaoTexto", () => {
  it("renderiza o markdown simples com elementos (negrito e lista)", () => {
    render(SecaoTexto, { props: { secao: secao("resumo") } });
    expect(screen.getByRole("heading", { name: "Resumo" })).toBeInTheDocument();
    expect(screen.getByText("Porto Velho").tagName).toBe("STRONG");
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
  });

  it("não interpreta HTML", () => {
    const { container } = render(SecaoTexto, {
      props: { secao: { id: "x", tipo: "texto", markdown: "<img src=x onerror=alert(1)> oi" } },
    });
    expect(container.querySelector("img")).toBeNull();
    expect(screen.getByText(/<img src=x/)).toBeInTheDocument();
  });
});

describe("SecaoIndicadores", () => {
  it("mostra cartões com valor formatado e referência", () => {
    render(SecaoIndicadores, { props: { secao: secao("kpis") } });
    const cards = screen.getAllByTestId("indicador");
    expect(cards).toHaveLength(3);
    expect(cards[0]).toHaveTextContent("IDEB 2023");
    expect(cards[0]).toHaveTextContent("5,6");
    expect(within(cards[0]).getByTestId("indicador-referencia")).toHaveTextContent("RO: 5,9");
    expect(cards[1]).toHaveTextContent("12.345");
    expect(within(cards[1]).queryByTestId("indicador-referencia")).toBeNull();
    expect(cards[2]).toHaveTextContent("93,4%");
    expect(within(cards[2]).getByTestId("indicador-referencia")).toHaveTextContent("RO: 95,1%");
  });
});

describe("SecaoTabela", () => {
  it("é acessível (caption, th scope) e formata as colunas", () => {
    render(SecaoTabela, { props: { secao: secao("tabela_redes") } });
    const tabela = screen.getByRole("table", { name: "IDEB por rede" });
    const cols = within(tabela).getAllByRole("columnheader");
    expect(cols.map((c) => c.textContent.trim())).toEqual([
      "Rede",
      "Escolas",
      "IDEB",
      "Nota SAEB",
      "Aprovação",
    ]);
    cols.forEach((c) => expect(c).toHaveAttribute("scope", "col"));
    const rowHeader = within(tabela).getByRole("rowheader", { name: "Municipal" });
    expect(rowHeader).toHaveAttribute("scope", "row");
    const linha = rowHeader.closest("tr");
    const celulas = within(linha).getAllByRole("cell").map((c) => c.textContent.trim());
    expect(celulas).toEqual(["1.234", "5,5", "5,88", "92,5%"]);
    expect(screen.getByText("Escolas com IDEB divulgado em 2023.")).toBeInTheDocument();
  });

  it("sem linhas mostra mensagem", () => {
    render(SecaoTabela, {
      props: { secao: { id: "v", titulo: "Vazia", colunas: [{ id: "a", rotulo: "A" }], linhas: [] } },
    });
    expect(screen.getByText("Sem dados para este recorte.")).toBeInTheDocument();
  });
});

describe("SecaoGrafico", () => {
  it("barras: usa o wrapper com as linhas convertidas e descreve em texto", () => {
    render(SecaoGrafico, { props: { secao: secao("grafico_serie") } });
    const sec = screen.getByTestId("secao-grafico");
    expect(sec).toHaveAttribute("data-grafico", "barras");
    const stub = screen.getByTestId("carbon-chart-stub");
    expect(stub).toHaveAttribute("data-rows", "6");
    expect(screen.getByText(/IDEB ao longo do tempo/, { selector: "p" })).toBeInTheDocument();
    const figura = screen.getByRole("figure");
    expect(figura).toHaveAccessibleDescription(/Gráfico de barras .* Porto Velho — 2019: 5,2/);
    // os mesmos dados em tabela recolhível
    expect(screen.getByRole("table", { name: "Dados: IDEB ao longo do tempo" })).toBeInTheDocument();
  });

  it("linhas: marca o tipo", () => {
    render(SecaoGrafico, { props: { secao: { ...secao("grafico_serie"), grafico: "linhas" } } });
    expect(screen.getByTestId("secao-grafico")).toHaveAttribute("data-grafico", "linhas");
    expect(screen.getByTestId("grafico-descricao")).toHaveTextContent(/^Gráfico de linhas/);
  });

  it("sem dados não desenha o gráfico", () => {
    render(SecaoGrafico, { props: { secao: { ...secao("grafico_serie"), dados: [] } } });
    expect(screen.queryByTestId("carbon-chart-stub")).toBeNull();
    expect(screen.getByText("Sem dados para este gráfico.")).toBeInTheDocument();
  });
});
