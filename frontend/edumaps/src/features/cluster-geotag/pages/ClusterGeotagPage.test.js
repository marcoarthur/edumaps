// src/features/cluster-geotag/pages/ClusterGeotagPage.test.js
import { render, screen, waitFor, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import ClusterGeotagPage from "./ClusterGeotagPage.svelte";
import {
  getRegions,
  getUfs,
  getMunicipalities,
  getPresets,
  getColumns,
  getYears,
  requestCluster,
  getJobProgress,
  getClusterSchools,
} from "../api/clusterApi.js";
import {
  REGIONS_FIXTURE,
  UFS_FIXTURE,
  MUNICIPALITIES_FIXTURE,
  PRESETS_FIXTURE,
  COLUMNS_FIXTURE,
  YEARS_FIXTURE,
  CLUSTER_POLYGONS_FIXTURE,
  FIXTURE_GEOTAG,
} from "../mocks/fixtures.js";
import { ApiError } from "@/shared/api/client.js";

vi.mock("../api/clusterApi.js", () => ({
  getRegions: vi.fn(),
  getUfs: vi.fn(),
  getMunicipalities: vi.fn(),
  getPresets: vi.fn(),
  getColumns: vi.fn(),
  getYears: vi.fn(),
  requestCluster: vi.fn(),
  getJobProgress: vi.fn(),
  getClusterSchools: vi.fn(),
}));

describe("ClusterGeotagPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Catálogo padrão para todos os testes.
    getPresets.mockResolvedValue(PRESETS_FIXTURE);
    getColumns.mockResolvedValue(COLUMNS_FIXTURE);
    getYears.mockResolvedValue(YEARS_FIXTURE);

    // Leaflet precisa de um container com dimensões; jsdom reporta 0x0,
    // mas o mapa ainda inicializa. Mockamos fitBounds para evitar warning.
    vi.spyOn(window.HTMLElement.prototype, "clientWidth", "get").mockReturnValue(800);
    vi.spyOn(window.HTMLElement.prototype, "clientHeight", "get").mockReturnValue(600);
  });

  afterEach(() => {
    vi.resetAllMocks();
  });

  it("carrega e exibe as regiões da cascata", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    render(ClusterGeotagPage);

    await waitFor(() => {
      expect(screen.getByText(/3 · Sudeste/)).toBeInTheDocument();
    });
  });

  it("carrega UFs ao selecionar região e municípios ao selecionar UF", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);

    render(ClusterGeotagPage);

    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: "1" } });

    await waitFor(() => {
      // bind:value em <select> do Svelte devolve número, não string
      expect(getUfs).toHaveBeenCalledWith(1);
      expect(screen.getByText("RO")).toBeInTheDocument();
    });

    const uf = screen.getByLabelText("UF");
    await fireEvent.change(uf, { target: { value: "12" } });

    await waitFor(() => {
      expect(getMunicipalities).toHaveBeenCalledWith(12);
      expect(screen.getByText("Rio Branco")).toBeInTheDocument();
    });
  });

  it("preset infraestrutura pré-seleciona 11 features", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    render(ClusterGeotagPage);

    await waitFor(() => {
      expect(screen.getByText("11 selecionado(s)")).toBeInTheDocument();
    });
  });

  it("preset desempenho exige ano e envia ano_ideb no payload", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);
    requestCluster.mockResolvedValue({ task: "cluster", job_id: 100 });
    getJobProgress.mockResolvedValue({ state: "finished", job_id: 100 });
    getClusterSchools.mockResolvedValue(CLUSTER_POLYGONS_FIXTURE);

    render(ClusterGeotagPage);

    // Espera os presets carregarem antes de clicar.
    await waitFor(() => {
      expect(screen.getByRole("button", { name: /Desempenho dos alunos/ })).toBeInTheDocument();
    });
    await fireEvent.click(screen.getByRole("button", { name: /Desempenho dos alunos/ }));

    await waitFor(() => {
      // Ano IDEB obrigatório aparece.
      expect(screen.getByLabelText(/Ano IDEB\/SAEB/)).toBeInTheDocument();
    });

    // Seleciona região e UF (necessário para passar a checagem de recorte).
    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: String(FIXTURE_GEOTAG.codigo_regiao) } });
    const uf = await screen.findByLabelText("UF");
    await fireEvent.change(uf, { target: { value: String(FIXTURE_GEOTAG.codigo_uf) } });

    // Tenta gerar SEM ano — deve mostrar erro de validação.
    await fireEvent.click(screen.getByRole("button", { name: /Gerar clusters/i }));

    await waitFor(() => {
      expect(screen.getByText(/exige escolher o ano/i)).toBeInTheDocument();
      expect(requestCluster).not.toHaveBeenCalled();
    });

    // Seleciona ano 2023 e gera com sucesso.
    const anoSelect = screen.getByLabelText(/Ano IDEB\/SAEB/);
    await fireEvent.change(anoSelect, { target: { value: "2023" } });

    await fireEvent.click(screen.getByRole("button", { name: /Gerar clusters/i }));

    await waitFor(() => {
      expect(requestCluster).toHaveBeenCalledWith(
        expect.objectContaining({
          preset: "desempenho",
          ano_ideb: 2023,
          table_name: "school_indicators",
          id_column: "co_entidade",
          schema: "clean",
          features: expect.arrayContaining(["nota_media"]),
        }),
      );
    });

    await waitFor(
      () => {
        expect(getClusterSchools).toHaveBeenCalled();
      },
      { timeout: 3000 },
    );
  });

  it("gera clusters, aguarda o job e colore o mapa por cluster", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);
    requestCluster.mockResolvedValue({ task: "cluster", job_id: 42 });
    getJobProgress.mockResolvedValue({ state: "finished", job_id: 42 });
    getClusterSchools.mockResolvedValue(CLUSTER_POLYGONS_FIXTURE);

    render(ClusterGeotagPage);

    // Cascata região 1 + UF 12
    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: String(FIXTURE_GEOTAG.codigo_regiao) } });
    const uf = await screen.findByLabelText("UF");
    await fireEvent.change(uf, { target: { value: String(FIXTURE_GEOTAG.codigo_uf) } });

    await waitFor(() => expect(uf.value).toBe(String(FIXTURE_GEOTAG.codigo_uf)));

    await fireEvent.click(screen.getByRole("button", { name: /Gerar clusters/i }));

    await waitFor(() => {
      expect(requestCluster).toHaveBeenCalled();
    });

    // Depois do polling, o mapa mostra os clusters com legenda
    await waitFor(
      () => {
        expect(getClusterSchools).toHaveBeenCalled();
        expect(screen.getByText(/Cluster 1/)).toBeInTheDocument();
        expect(screen.getByText(/Cluster 2/)).toBeInTheDocument();
      },
      { timeout: 3000 },
    );
  });

  it("exibe erro quando a API de clusters falha", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);
    requestCluster.mockRejectedValue(
      new ApiError("Analytics fora do ar", { status: 502 }),
    );

    render(ClusterGeotagPage);

    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: "1" } });
    const uf = screen.getByLabelText("UF");
    await fireEvent.change(uf, { target: { value: "12" } });

    await fireEvent.click(screen.getByRole("button", { name: /Gerar clusters/i }));

    await waitFor(() => {
      expect(screen.getByText(/Analytics fora do ar/)).toBeInTheDocument();
    });
  });
});
