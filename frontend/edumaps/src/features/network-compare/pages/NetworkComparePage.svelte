<script>
  // src/features/network-compare/pages/NetworkComparePage.svelte
  import { onMount } from "svelte";
  import InputAutocomplete from "@/shared/ui/components/InputAutocomplete.svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { router } from "@/app/router.svelte.js";
  import {
    fetchMunicipioSuggestions,
    getNetworkMarkers,
    getNetworkPerformance,
    getNetworkSummary,
  } from "../api/networkCompareApi.js";
  import NetworkSummaryBanner from "../components/NetworkSummaryBanner.svelte";
  import NetworkKpis from "../components/NetworkKpis.svelte";
  import NetworkRadar from "../components/NetworkRadar.svelte";
  import NetworkStageBars from "../components/NetworkStageBars.svelte";
  import NetworkShareDonut from "../components/NetworkShareDonut.svelte";
  import NetworkIdedTimeline from "../components/NetworkIdedTimeline.svelte";
  import NetworkCompareTable from "../components/NetworkCompareTable.svelte";
  import NetworkSchoolMap from "../components/NetworkSchoolMap.svelte";

  const CITY_KEY = "municipio";

  let codigoIbge = $state(null);
  let municipioName = $state("");
  let networks = $state([]);
  let performance = $state([]);
  let markers = $state([]);
  let loading = $state(false);
  let error = $state(null);

  async function loadMunicipality(code) {
    if (!code) return;
    loading = true;
    error = null;
    try {
      const [summary, perf, features] = await Promise.all([
        getNetworkSummary(code),
        getNetworkPerformance(code),
        getNetworkMarkers(code),
      ]);
      networks = summary;
      performance = perf;
      markers = features?.features ?? [];
      codigoIbge = code;
      municipioName = summary[0]?.no_municipio ?? "";
    } catch (err) {
      networks = [];
      performance = [];
      markers = [];
      error = err instanceof ApiError
        ? err.message
        : "Erro ao carregar dados do município.";
    } finally {
      loading = false;
    }
  }

  function handleSelectMunicipio(city) {
    if (!city?.codigo_ibge) return;
    loadMunicipality(city.codigo_ibge);
    // Mantém a URL compartilhável sem recarregar a página.
    if (window.location.search !== `?codigo_ibge=${city.codigo_ibge}`) {
      window.history.replaceState({}, "", `/municipio/compare?codigo_ibge=${city.codigo_ibge}`);
    }
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get("codigo_ibge");
    if (code) {
      municipioName = "";
      loadMunicipality(code);
    } else {
      loading = false;
    }
  });

  function voltarParaBusca() {
    router.navigate("/escola/search");
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Comparar redes por município</h1>
      <p class="text-sm text-gray-600 mt-1">
        Busque um município para comparar as redes de ensino que o atendem.
      </p>
    </div>
    <button
      onclick={voltarParaBusca}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar para busca
    </button>
  </header>

  <div class="bg-white border border-gray-200 rounded-card shadow-card p-5 max-w-xl">
    <InputAutocomplete
      id={CITY_KEY}
      label="Município"
      placeholder="Ex: Sertãozinho"
      bind:value={municipioName}
      disabled={loading}
      fetchSuggestions={fetchMunicipioSuggestions}
      getOptionLabel={(city) => city.nome}
      getOptionKey={(city) => city.codigo_ibge}
      noResultsText="Nenhum município encontrado"
      onSelect={handleSelectMunicipio}
    >
      {#snippet option(city)}
        <span>{city.nome}</span>
        <span class="text-gray-400"> · {city.uf}</span>
      {/snippet}
    </InputAutocomplete>
  </div>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando dados do município…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if networks.length > 0}
    <NetworkSummaryBanner {networks} />

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <NetworkRadar {networks} />
      <NetworkStageBars {networks} />
      <NetworkShareDonut {networks} field="total_escolas" title="Escolas por rede" />
      <NetworkShareDonut {networks} field="total_matriculas" title="Matrículas por rede" />
    </div>

    <NetworkIdedTimeline {performance} />

    <NetworkCompareTable {networks} />

    <NetworkSchoolMap {markers} />
  {:else}
    <div class="bg-gray-50 border border-dashed border-gray-300 rounded-card p-10 text-center">
      <p class="text-gray-500 text-sm">
        Selecione um município acima para ver a comparação das redes.
      </p>
    </div>
  {/if}
</div>