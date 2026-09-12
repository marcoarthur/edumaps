// src/features/network-compare/pages/NetworkComparePage.test.js
import { render, screen, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import NetworkComparePage from "./NetworkComparePage.svelte";
import {
  fetchMunicipioSuggestions,
  getNetworkMarkers,
  getNetworkPerformance,
  getNetworkSummary,
} from "../api/networkCompareApi.js";
import {
  NETWORK_MARKERS_FIXTURE,
  NETWORK_PERFORMANCE_FIXTURE,
  NETWORK_SUMMARY_FIXTURE,
} from "../mocks/fixtures.js";

vi.mock("../api/networkCompareApi.js", () => ({
  fetchMunicipioSuggestions: vi.fn(),
  getNetworkMarkers: vi.fn(),
  getNetworkPerformance: vi.fn(),
  getNetworkSummary: vi.fn(),
}));

// O motor do Carbon depende de APIs de SVG ausentes no jsdom; usa um stub
// que expõe o mesmo contrato (data/options) dos wrappers.
vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("../__tests__/CarbonChartStub.svelte")).default;
  return {
    RadarChart: stub,
    BarChartGrouped: stub,
    DonutChart: stub,
    LineChart: stub,
  };
});

describe("NetworkComparePage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete window.location;
    window.location = new URL("http://localhost/municipio/compare");
  });

  afterEach(() => {
    vi.resetAllMocks();
  });

  it("exibe estado vazio sem município selecionado", () => {
    render(NetworkComparePage);
    expect(
      screen.getByText(/Selecione um município acima/i),
    ).toBeInTheDocument();
  });

  it("carrega os dados do município da query string e exibe o banner", async () => {
    getNetworkSummary.mockResolvedValue(NETWORK_SUMMARY_FIXTURE);
    getNetworkPerformance.mockResolvedValue(NETWORK_PERFORMANCE_FIXTURE);
    getNetworkMarkers.mockResolvedValue(NETWORK_MARKERS_FIXTURE);

    window.location = new URL(
      "http://localhost/municipio/compare?codigo_ibge=3551702",
    );

    render(NetworkComparePage);

    await waitFor(() => {
      expect(
        screen.getByText(/Redes que atendem Sertãozinho/i),
      ).toBeInTheDocument();
    });

    expect(getNetworkSummary).toHaveBeenCalledWith("3551702");
    expect(getNetworkPerformance).toHaveBeenCalledWith("3551702");
    expect(getNetworkMarkers).toHaveBeenCalledWith("3551702");

    // Banner com as 4 redes (nomes também aparecem em legendas de gráfico)
    expect(screen.getAllByText("Federal").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Municipal").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Privada").length).toBeGreaterThan(0);

    // Acessório: SP · Sudeste
    expect(screen.getByText(/SP · Sudeste/)).toBeInTheDocument();
  });

  it("exibe mensagem de erro quando a API falha", async () => {
    getNetworkSummary.mockRejectedValue(new Error("Município sem dados"));
    getNetworkPerformance.mockResolvedValue([]);
    getNetworkMarkers.mockResolvedValue({ type: "FeatureCollection", features: [] });

    window.location = new URL(
      "http://localhost/municipio/compare?codigo_ibge=9999999",
    );

    render(NetworkComparePage);

    await waitFor(() => {
      expect(
        screen.getByText(/Erro ao carregar dados do município/i),
      ).toBeInTheDocument();
    });
  });
});