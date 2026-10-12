// src/features/gestor/components/relatorios/RelatorioView.test.js
import { describe, it, expect, vi } from "vitest";
import { render, screen, within } from "@testing-library/svelte";
import RelatorioView from "./RelatorioView.svelte";
import {
  RELATORIO_RESULT_FIXTURE,
  RELATORIO_LLM_INDISPONIVEL_FIXTURE,
} from "../../mocks/relatoriosFixtures.js";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartGrouped: stub, LineChart: stub, RadarChart: stub, DonutChart: stub };
});

describe("RelatorioView", () => {
  it("renderiza título, recorte e as seções na ordem, por tipo", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
    expect(
      screen.getByRole("heading", { name: "IDEB do território — Porto Velho (RO)" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Porto Velho \(RO\)/, { selector: "p" })).toBeInTheDocument();
    const ids = [...document.querySelectorAll("[data-testid^='secao-']")].map((e) =>
      e.getAttribute("data-testid"),
    );
    expect(ids).toEqual([
      "secao-texto",
      "secao-indicadores",
      "secao-tabela",
      "secao-grafico",
      "secao-tabela", // dados do gráfico, dentro dele
      "secao-texto",
    ]);
    expect(screen.queryByTestId("selo-cache")).toBeNull();
    expect(screen.queryByTestId("aviso-llm")).toBeNull();
  });

  it("rodapé com fontes (ferramenta, edição, escopo, n) e avisos", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_RESULT_FIXTURE } });
    const fontes = screen.getByTestId("relatorio-fontes");
    expect(fontes).toHaveTextContent("IDEB agregado por território");
    expect(fontes).toHaveTextContent("IDEB 2023");
    expect(fontes).toHaveTextContent("municípios de RO");
    expect(fontes).toHaveTextContent("n = 52");
    expect(fontes).toHaveTextContent("ideb_agregado");
    expect(within(screen.getByTestId("relatorio-avisos")).getByText(/limitada a 1000 linhas/)).toBeInTheDocument();
  });

  it("selo quando veio do cache", () => {
    render(RelatorioView, { props: { relatorio: { ...RELATORIO_RESULT_FIXTURE, cache_hit: true } } });
    expect(screen.getByTestId("selo-cache")).toHaveTextContent("Gerado a partir do cache");
  });

  it("aviso visível quando o LLM esteve indisponível", () => {
    render(RelatorioView, { props: { relatorio: RELATORIO_LLM_INDISPONIVEL_FIXTURE } });
    expect(screen.getByTestId("aviso-llm")).toHaveTextContent("A redação automática não estava disponível");
    expect(screen.getByTestId("relatorio-avisos")).toHaveTextContent("O serviço de redação não respondeu.");
  });

  it("ignora tipos de seção desconhecidos e listas ausentes", () => {
    render(RelatorioView, {
      props: { relatorio: { titulo: "Só título", secoes: [{ id: "z", tipo: "mapa" }] } },
    });
    expect(screen.getByRole("heading", { name: "Só título" })).toBeInTheDocument();
    expect(screen.queryByTestId("relatorio-fontes")).toBeNull();
    expect(screen.queryByTestId("relatorio-avisos")).toBeNull();
  });
});
