// src/features/schools/components/panel/SchoolPerformance.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolPerformance from "./SchoolPerformance.svelte";

// jsdom não implementa as APIs SVG do @carbon; usa o stub padrão.
vi.mock("@carbon/charts-svelte", async () => {
  const stub = (
    await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")
  ).default;
  return { LineChart: stub };
});

const DESEMPENHO = [
  { ano: 2019, etapa: "fundamental_ii", ideb_observado: 5.1 },
  { ano: 2021, etapa: "fundamental_ii", ideb_observado: 5.2 },
  { ano: 2023, etapa: "fundamental_ii", ideb_observado: 4.8 },
  { ano: 2021, etapa: "ensino_medio", ideb_observado: null },
  { ano: 2023, etapa: "ensino_medio", ideb_observado: 3.5 },
];

describe("SchoolPerformance", () => {
  it("renderiza um gráfico com os pontos de IDEB observado", () => {
    render(SchoolPerformance, { props: { desempenho: DESEMPENHO } });

    expect(
      screen.getByText(/IDEB observado por etapa/i),
    ).toBeInTheDocument();

    const stub = document.querySelector('[data-testid="carbon-chart-stub"]');
    // 3 pontos de fundamental_ii + 1 de ensino_medio (o null é ignorado).
    expect(stub.getAttribute("data-rows")).toBe("4");
  });

  it("mostra mensagem quando não há IDEB observado", () => {
    render(SchoolPerformance, {
      props: {
        desempenho: [{ ano: 2023, etapa: "ensino_medio", ideb_observado: null }],
      },
    });

    expect(
      screen.getByText(/sem resultados de ideb observado/i),
    ).toBeInTheDocument();
  });
});
