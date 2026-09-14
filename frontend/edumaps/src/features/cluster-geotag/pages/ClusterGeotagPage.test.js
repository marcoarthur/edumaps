// src/features/cluster-geotag/pages/ClusterGeotagPage.test.js
import { render, screen, waitFor, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import ClusterGeotagPage from "./ClusterGeotagPage.svelte";
import {
  getRegions,
  getUfs,
  getMunicipalities,
  requestCluster,
  getJobProgress,
  getClusterSchools,
} from "../api/clusterApi.js";
import {
  REGIONS_FIXTURE,
  UFS_FIXTURE,
  MUNICIPALITIES_FIXTURE,
  CLUSTER_POLYGONS_FIXTURE,
  FIXTURE_GEOTAG,
} from "../mocks/fixtures.js";
import { ApiError } from "@/shared/api/client.js";

vi.mock("../api/clusterApi.js", () => ({
  getRegions: vi.fn(),
  getUfs: vi.fn(),
  getMunicipalities: vi.fn(),
  requestCluster: vi.fn(),
  getJobProgress: vi.fn(),
  getClusterSchools: vi.fn(),
}));

describe("ClusterGeotagPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
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
    const uf = await screen.findByLabelText("UF");
    await fireEvent.change(uf, { target: { value: "12" } });

    await fireEvent.click(screen.getByRole("button", { name: /Gerar clusters/i }));

    await waitFor(() => {
      expect(screen.getByText(/Analytics fora do ar/)).toBeInTheDocument();
    });
  });
});