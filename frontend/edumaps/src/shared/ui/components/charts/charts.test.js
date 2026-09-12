// src/shared/ui/components/charts/charts.test.js
//
// Smoke test dos wrappers: validam a fiação (merge de options, injeção de
// height, guarda de ResizeObserver) sem depender do motor SVG do Carbon,
// que o jsdom não implementa.
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import RadarChart from "./RadarChart.svelte";
import LineChart from "./LineChart.svelte";
import BarChartGrouped from "./BarChartGrouped.svelte";
import DonutChart from "./DonutChart.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (
    await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")
  ).default;
  return {
    RadarChart: stub,
    BarChartGrouped: stub,
    DonutChart: stub,
    LineChart: stub,
  };
});

const DATA = [{ group: "A", stage: "Infantil", value: 10 }];

describe("wrappers de gráfico (Carbon)", () => {
  it.each([
    ["RadarChart", RadarChart],
    ["LineChart", LineChart],
    ["BarChartGrouped", BarChartGrouped],
    ["DonutChart", DonutChart],
  ])("%s renderiza título e injeta height nas options", (name, Component) => {
    render(Component, {
      props: { data: DATA, options: { title: `Título ${name}` } },
    });

    expect(screen.getByText(new RegExp(`Título ${name}`))).toBeInTheDocument();
    const stub = document.querySelector('[data-testid="carbon-chart-stub"]');
    expect(stub).toBeInTheDocument();
    // height padrão do wrapper (320px) injetado nas options
    expect(stub).toHaveAttribute("data-height", "320");
  });

  it("aceita height customizado", () => {
    render(RadarChart, {
      props: {
        data: DATA,
        height: "440px",
        options: { title: "Altura custom" },
      },
    });
    const stub = document.querySelector('[data-testid="carbon-chart-stub"]');
    expect(stub).toHaveAttribute("data-height", "440");
  });

  it("propaga data para o chart", () => {
    render(LineChart, { props: { data: DATA, options: {} } });
    const stub = document.querySelector('[data-testid="carbon-chart-stub"]');
    expect(stub).toHaveAttribute("data-rows", String(DATA.length));
  });
});