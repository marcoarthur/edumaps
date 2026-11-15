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
  getClusterSummary,
  getExecucao,
  getExecucaoEscolas,
} from "../api/clusterApi.js";
import {
  REGIONS_FIXTURE,
  UFS_FIXTURE,
  MUNICIPALITIES_FIXTURE,
  PRESETS_FIXTURE,
  COLUMNS_FIXTURE,
  YEARS_FIXTURE,
  CLUSTER_POLYGONS_FIXTURE,
  CLUSTER_SUMMARY_FIXTURE,
  FIXTURE_GEOTAG,
  EXECUCAO_FIXTURE,
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
  getClusterSummary: vi.fn(),
  getExecucao: vi.fn(),
  getExecucaoEscolas: vi.fn(),
  execucaoCsvUrl: (id) => `/api/cluster/execucoes/${id}/csv`,
}));

describe("ClusterGeotagPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Catálogo padrão para todos os testes.
    getPresets.mockResolvedValue(PRESETS_FIXTURE);
    getColumns.mockResolvedValue(COLUMNS_FIXTURE);
    getYears.mockResolvedValue(YEARS_FIXTURE);
    getClusterSummary.mockResolvedValue(CLUSTER_SUMMARY_FIXTURE);

    // Leaflet precisa de um container com dimensões; jsdom reporta 0x0,
    // mas o mapa ainda inicializa. Mockamos fitBounds para evitar warning.
    vi.spyOn(window.HTMLElement.prototype, "clientWidth", "get").mockReturnValue(800);
    vi.spyOn(window.HTMLElement.prototype, "clientHeight", "get").mockReturnValue(600);
  });

  afterEach(() => {
    vi.resetAllMocks();
    window.history.replaceState({}, "", "/");
  });

  it("execução guardada: mostra o universo, o link e o CSV, e põe ?execucao= na URL (#427)", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    requestCluster.mockResolvedValue({ task: "cluster", job_id: 42 });
    getJobProgress.mockResolvedValue({ state: "finished", run_id: EXECUCAO_FIXTURE.run_id });
    getExecucao.mockResolvedValue({ ...EXECUCAO_FIXTURE, resumo: CLUSTER_SUMMARY_FIXTURE });
    getExecucaoEscolas.mockResolvedValue(CLUSTER_POLYGONS_FIXTURE);

    render(ClusterGeotagPage);
    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: "1" } });
    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

    const universo = await screen.findByTestId("universo-execucao", {}, { timeout: 3000 });
    expect(universo).toHaveTextContent(/226\s*escolas no recorte, 180\s*agrupadas, 46\s*fora/);
    expect(universo).toHaveTextContent(/40 não funcionam mais/);
    expect(universo).toHaveTextContent(/6 sem dado de .*esgoto/i);
    expect(universo).toHaveTextContent(/13 escolas agrupadas sem coordenada/);
    expect(universo).toHaveTextContent(/até 13\/02\/2027/);
    expect(screen.getByTestId("versao-dados")).toHaveTextContent("Dados: Censo Escolar 2025 (carga em 14/10/2026) · IDEB 2023.");
    expect(screen.getByRole("link", { name: "Baixar CSV" })).toHaveAttribute(
      "href", `/api/cluster/execucoes/${EXECUCAO_FIXTURE.run_id}/csv`);
    expect(window.location.search).toBe(`?execucao=${EXECUCAO_FIXTURE.run_id}`);
    expect(getClusterSchools).not.toHaveBeenCalled();
    expect(getClusterSummary).not.toHaveBeenCalled();
  });

  it("link ?execucao= reabre o resultado e remonta o formulário sem recalcular (#427)", async () => {
    window.history.replaceState({}, "", `/cluster/geotag?execucao=${EXECUCAO_FIXTURE.run_id}`);
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);
    getExecucao.mockResolvedValue({ ...EXECUCAO_FIXTURE, resumo: CLUSTER_SUMMARY_FIXTURE });
    getExecucaoEscolas.mockResolvedValue(CLUSTER_POLYGONS_FIXTURE);

    render(ClusterGeotagPage);

    await screen.findByTestId("universo-execucao", {}, { timeout: 3000 });
    expect(getExecucao).toHaveBeenCalledWith(EXECUCAO_FIXTURE.run_id);
    expect(requestCluster).not.toHaveBeenCalled();
    await waitFor(() => {
      expect(screen.getByLabelText("Região").value).toBe("1");
      expect(screen.getByLabelText("UF").value).toBe("12");
      expect(screen.getByLabelText("Município").value).toBe("1200401");
      expect(screen.getByLabelText("Nº de grupos").value).toBe("4");
    });
  });

  it("execução vencida ou inexistente: mensagem, sem quebrar a página (#427)", async () => {
    window.history.replaceState({}, "", "/cluster/geotag?execucao=run_1_ffff");
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getExecucao.mockRejectedValue(new ApiError("Execução não encontrada ou vencida (as execuções valem 90 dias).", { status: 404 }));

    render(ClusterGeotagPage);
    expect(await screen.findByText(/vencida \(as execuções valem 90 dias\)/)).toBeInTheDocument();
    expect(screen.queryByTestId("universo-execucao")).toBeNull();
  });

  it("carrega e exibe as regiões da cascata", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    render(ClusterGeotagPage);

    await waitFor(() => {
      expect(screen.getByText(/3 · Sudeste/)).toBeInTheDocument();
    });
  });

  it("fala a língua do usuário: título, grupos e a frase do algoritmo (#431)", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    render(ClusterGeotagPage);

    expect(screen.getByRole("heading", { name: "Agrupar escolas com perfil parecido" })).toBeInTheDocument();
    expect(screen.getByLabelText("Nº de grupos")).toBeInTheDocument();
    expect(screen.getByTestId("algoritmo-descricao")).toHaveTextContent(/tamanho parecido/);
    expect(screen.queryByText(/geotag|motor R/i)).toBeNull();

    await fireEvent.change(screen.getByLabelText("Algoritmo"), { target: { value: "dbscan" } });
    expect(screen.getByTestId("algoritmo-descricao")).toHaveTextContent(/isoladas ficam de fora/);
    expect(screen.getByLabelText(/Mínimo de escolas por grupo/)).toBeInTheDocument();
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
    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

    await waitFor(() => {
      expect(screen.getByText(/exige escolher o ano/i)).toBeInTheDocument();
      expect(requestCluster).not.toHaveBeenCalled();
    });

    // Seleciona ano 2023 e gera com sucesso.
    const anoSelect = screen.getByLabelText(/Ano IDEB\/SAEB/);
    await fireEvent.change(anoSelect, { target: { value: "2023" } });

    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

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

    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

    await waitFor(() => {
      expect(requestCluster).toHaveBeenCalled();
    });

    // Depois do polling, o mapa mostra a legenda com rótulos semânticos
    // e a tabela de resumo dos clusters.
    await waitFor(
      () => {
        expect(getClusterSchools).toHaveBeenCalled();
        expect(getClusterSummary).toHaveBeenCalled();
        expect(screen.getByText(/Resumo dos grupos/)).toBeInTheDocument();
      },
      { timeout: 3000 },
    );

    expect(screen.getAllByText(/Baixa qualidade de infraestrutura/).length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText(/Alta qualidade de infraestrutura/).length).toBeGreaterThanOrEqual(1);
  });

  it("legenda alterna clusters (on/off) ao clicar", async () => {
    getRegions.mockResolvedValue(REGIONS_FIXTURE);
    getUfs.mockResolvedValue(UFS_FIXTURE);
    getMunicipalities.mockResolvedValue(MUNICIPALITIES_FIXTURE);
    requestCluster.mockResolvedValue({ task: "cluster", job_id: 42 });
    getJobProgress.mockResolvedValue({ state: "finished", job_id: 42 });
    getClusterSchools.mockResolvedValue(CLUSTER_POLYGONS_FIXTURE);

    render(ClusterGeotagPage);

    const regiao = await screen.findByLabelText("Região");
    await fireEvent.change(regiao, { target: { value: String(FIXTURE_GEOTAG.codigo_regiao) } });
    const uf = await screen.findByLabelText("UF");
    await fireEvent.change(uf, { target: { value: String(FIXTURE_GEOTAG.codigo_uf) } });
    await waitFor(() => expect(uf.value).toBe(String(FIXTURE_GEOTAG.codigo_uf)));

    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

    // Botão da legenda (não o da tabela) — inicialmente ligado.
    const btn = await screen.findByRole(
      "button",
      { name: /Baixa qualidade de infraestrutura/ },
      { timeout: 3000 },
    );
    expect(btn.getAttribute("aria-pressed")).toBe("true");

    await fireEvent.click(btn);
    expect(btn.getAttribute("aria-pressed")).toBe("false");

    await fireEvent.click(btn);
    expect(btn.getAttribute("aria-pressed")).toBe("true");
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

    await fireEvent.click(screen.getByRole("button", { name: /Agrupar escolas/i }));

    await waitFor(() => {
      expect(screen.getByText(/Analytics fora do ar/)).toBeInTheDocument();
    });
  });
});
