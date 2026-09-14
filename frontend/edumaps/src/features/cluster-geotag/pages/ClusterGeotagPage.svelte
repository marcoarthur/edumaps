<script>
  // src/features/cluster-geotag/pages/ClusterGeotagPage.svelte
  import { onMount, onDestroy } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { router } from "@/app/router.svelte.js";
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
  } from "../api/clusterApi.js";
  import ClusterSchoolMap from "../components/ClusterSchoolMap.svelte";
  import ClusterSummaryTable from "../components/ClusterSummaryTable.svelte";
  import PresetSelector from "../components/PresetSelector.svelte";
  import FeatureSelect from "../components/FeatureSelect.svelte";
  import { ALGORITHMS } from "../constants/cluster.js";

  // ---- cascata de geotag ------------------------------------------------
  let regions = $state([]);
  let ufs = $state([]);
  let municipalities = $state([]);

  let codigoRegiao = $state("");
  let codigoUf = $state("");
  let codigoIbge = $state("");

  // ---- catálogo de indicadores ------------------------------------------
  let presets = $state([]);
  let columns = $state([]);
  let years = $state([]);
  let selectedPreset = $state("infraestrutura");
  let anoIdeb = $state("");
  let selectedFeatures = $state([]);

  const currentPreset = $derived(
    presets.find((p) => p.id === selectedPreset) ?? null,
  );
  const needsYear = $derived(Boolean(currentPreset?.year_filter));

  // ---- parâmetros da clusterização --------------------------------------
  let algorithm = $state("kmeans");
  let clusters = $state("3");
  let eps = $state("1.5");
  let minPts = $state("5");

  // ---- estado de execução -----------------------------------------------
  let markers = $state([]);
  let clusterSummary = $state([]);
  let loading = $state(false);
  let clustered = $state(false);
  let locating = $state(false);
  let error = $state(null);

  let popTimer = null;

  async function loadUfs() {
    codigoUf = "";
    codigoIbge = "";
    municipalities = [];
    ufs = codigoRegiao ? await getUfs(codigoRegiao) : [];
  }

  async function loadMunicipalities() {
    codigoIbge = "";
    municipalities = codigoUf ? await getMunicipalities(codigoUf) : [];
  }

  async function handleRegionChange() {
    ufs = [];
    municipalities = [];
    codigoUf = "";
    codigoIbge = "";
    if (!codigoRegiao) return;
    locating = true;
    try {
      await loadUfs();
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar UFs.");
    } finally {
      locating = false;
    }
  }

  async function handleUfChange() {
    municipalities = [];
    codigoIbge = "";
    if (!codigoUf) return;
    locating = true;
    try {
      await loadMunicipalities();
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar municípios.");
    } finally {
      locating = false;
    }
  }

  function handlePresetChange(id) {
    selectedPreset = id;
    const preset = presets.find((p) => p.id === id);
    if (preset) selectedFeatures = [...preset.features];
  }

  function apiMessage(err, fallback) {
    return err instanceof ApiError ? err.message : fallback;
  }

  async function pollJob(jobId) {
    // Polling simples: 1.5s de intervalo até o job terminar ou falhar.
    for (;;) {
      await new Promise((resolve) => {
        popTimer = setTimeout(resolve, 1500);
      });
      const progress = await getJobProgress(jobId);
      if (progress.state === "failed") {
        throw new Error(progress.error || "Falha ao processar clusters no R.");
      }
      if (progress.state === "finished") return;
    }
  }

  async function generateClusters() {
    if (!codigoRegiao && !codigoUf && !codigoIbge) {
      error = "Selecione ao menos a região para definir o recorte.";
      return;
    }
    if (needsYear && !anoIdeb) {
      error = `O preset "${currentPreset?.name}" exige escolher o ano IDEB/SAEB.`;
      return;
    }
    if (selectedFeatures.length === 0) {
      error = "Selecione ao menos um indicador (coluna) para clusterizar.";
      return;
    }

    loading = true;
    clustered = false;
    error = null;
    markers = [];
    clusterSummary = [];

    const payload = {
      table_name: "school_indicators",
      id_column: "co_entidade",
      schema: "clean",
      algorithm,
      preset: selectedPreset,
      ano_ideb: needsYear ? Number(anoIdeb) : undefined,
      features: selectedFeatures,
      codigo_regiao: codigoRegiao || undefined,
      codigo_uf: codigoUf || undefined,
      codigo_ibge: codigoIbge || undefined,
    };
    if (algorithm === "dbscan") {
      payload.min_pts = Number(minPts) || 5;
      payload.eps = Number(eps) || 1.5;
    } else {
      payload.clusters = Number(clusters) || 3;
    }

    try {
      const started = await requestCluster(payload);
      await pollJob(started.job_id);

      const geotag = {
        codigo_regiao: codigoRegiao || undefined,
        codigo_uf: codigoUf || undefined,
        codigo_ibge: codigoIbge || undefined,
      };
      const fc = await getClusterSchools(geotag);
      markers = fc.features ?? [];
      clustered = true;

      try {
        clusterSummary = (await getClusterSummary()) ?? [];
      } catch (err) {
        clusterSummary = [];
      }
    } catch (err) {
      error = apiMessage(err, "Erro ao gerar os clusters.");
    } finally {
      loading = false;
    }
  }

  function voltarParaBusca() {
    router.navigate("/escola/search");
  }

  async function loadCatalog() {
    // Catálogo de indicadores (presets, colunas com metadado e anos).
    // Cada um carrega independente — se um falhar, os demais seguem.
    try {
      presets = await getPresets();
      const first = presets.find((p) => p.id === selectedPreset) ?? presets[0];
      if (first) {
        selectedPreset = first.id;
        selectedFeatures = [...first.features];
      }
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar presets.");
    }
    try {
      columns = await getColumns();
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar colunas de indicadores.");
    }
    try {
      years = await getYears();
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar anos IDEB/SAEB.");
    }
  }

  onMount(async () => {
    try {
      regions = await getRegions();
    } catch (err) {
      error = apiMessage(err, "Erro ao carregar regiões.");
    }
    await loadCatalog();
  });

  onDestroy(() => {
    if (popTimer) clearTimeout(popTimer);
  });
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Clusterizar escolas por geotag</h1>
      <p class="text-sm text-gray-600 mt-1">
        Escolha um preset de indicadores (ou monte sua própria lista), recorte a região e veja as escolas no mapa coloridas por cluster.
      </p>
    </div>
    <button
      onclick={voltarParaBusca}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar para busca
    </button>
  </header>

  <!-- Recorte geotag -->
  <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
    <p class="font-semibold text-gray-800 text-sm mb-3">Recorte geotag</p>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div>
        <label for="regiao" class="block text-sm text-gray-600 mb-1">Região</label>
        <select
          id="regiao"
          bind:value={codigoRegiao}
          onchange={handleRegionChange}
          class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm"
        >
          <option value="">Todas as regiões</option>
          {#each regions as r}
            <option value={r.co_regiao}>{r.co_regiao} · {r.no_regiao}</option>
          {/each}
        </select>
      </div>

      <div>
        <label for="uf" class="block text-sm text-gray-600 mb-1">UF</label>
        <select
          id="uf"
          bind:value={codigoUf}
          onchange={handleUfChange}
          disabled={!codigoRegiao || locating}
          class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm disabled:bg-gray-100"
        >
          <option value="">Todas as UFs</option>
          {#each ufs as u}
            <option value={u.co_uf}>{u.sg_uf}</option>
          {/each}
        </select>
      </div>

      <div>
        <label for="municipio" class="block text-sm text-gray-600 mb-1">Município</label>
        <select
          id="municipio"
          bind:value={codigoIbge}
          disabled={!codigoUf || locating}
          class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm disabled:bg-gray-100"
        >
          <option value="">Todos os municípios</option>
          {#each municipalities as m}
            <option value={m.co_municipio}>{m.no_municipio}</option>
          {/each}
        </select>
      </div>
    </div>
  </div>

  <!-- Parâmetros de clusterização -->
  <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
    <p class="font-semibold text-gray-800 text-sm mb-3">Parâmetros</p>

    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
      <div>
        <label for="algorithm" class="block text-sm text-gray-600 mb-1">Algoritmo</label>
        <select id="algorithm" bind:value={algorithm} class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
          {#each ALGORITHMS as a}
            <option value={a.value}>{a.label}</option>
          {/each}
        </select>
      </div>

      {#if algorithm === "dbscan"}
        <div>
          <label for="eps" class="block text-sm text-gray-600 mb-1">eps</label>
          <input id="eps" type="number" step="0.1" bind:value={eps} class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm" />
        </div>
        <div>
          <label for="minPts" class="block text-sm text-gray-600 mb-1">min_pts</label>
          <input id="minPts" type="number" bind:value={minPts} class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm" />
        </div>
      {:else}
        <div>
          <label for="clusters" class="block text-sm text-gray-600 mb-1">Nº de clusters</label>
          <input id="clusters" type="number" min="2" max="10" bind:value={clusters} class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm" />
        </div>
      {/if}

      <button
        onclick={generateClusters}
        disabled={loading}
        class="px-4 py-2 bg-blue-700 text-white text-sm font-medium rounded-md hover:bg-blue-800 transition-colors disabled:opacity-50"
      >
        {loading ? "Processando…" : "Gerar clusters"}
      </button>
    </div>

    <div class="mt-6">
      <p class="block text-sm text-gray-600 mb-2">
        Indicadores (features) — presets prontos ou seleção livre com busca
      </p>

      <div class="mb-3">
        <PresetSelector
        {presets}
        bind:value={selectedPreset}
        onchange={handlePresetChange}
      />
      </div>
      <div class="-mt-1 mb-3">
        <p class="text-xs text-gray-500">
          {currentPreset?.description
            ? currentPreset.description
            : "Monte sua própria lista de indicadores buscando por nome ou descrição."}
        </p>
        {#if needsYear}
          <div class="mt-3">
            <label for="ano_ideb" class="block text-sm text-gray-600 mb-1">
              Ano IDEB/SAEB <span class="text-red-500">*</span>
            </label>
            <select
              id="ano_ideb"
              bind:value={anoIdeb}
              class="w-full md:w-64 border border-gray-300 rounded-md px-3 py-2 text-sm"
            >
              <option value="">Selecione o ano…</option>
              {#each years as y}
                <option value={y.ano}>{y.ano}</option>
              {/each}
            </select>
          </div>
        {/if}
      </div>

      <FeatureSelect {columns} bind:value={selectedFeatures} disabled={loading} />
    </div>
  </div>

  {#if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {/if}

  <div class="bg-white border border-gray-200 rounded-card shadow-card p-2">
    {#if clustered && markers.length > 0}
      <ClusterSchoolMap {markers} height="460px" />
      <ClusterSummaryTable summary={clusterSummary} />
    {:else if clustered}
      <div class="text-center py-16 text-sm text-gray-500">
        Nenhuma escola com cluster gerado para este recorte.
      </div>
    {:else if loading}
      <div class="text-center py-16 text-sm text-gray-500">
        Processando clusters no motor R… aguarde.
      </div>
    {:else}
      <div class="text-center py-16 text-sm text-gray-500">
        Defina o recorte e clique em "Gerar clusters" para visualizar o mapa.
      </div>
    {/if}
  </div>
</div>