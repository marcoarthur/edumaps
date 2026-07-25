<!-- src/features/schools/components/SchoolRanking.svelte -->
<script>
  import { onMount } from 'svelte';
  import { getAvailableIndicators, getSchoolRanking } from '../api/rankingApi.js';
  import { ApiError } from '@/shared/api/client.js';

  // ============================================================
  // PROPS (Svelte 5: $props())
  // ============================================================
  let { 
    codInep, 
    onSelectSchool = () => {}, 
    onExport = () => {} 
  } = $props();

  // ============================================================
  // ESTADO REATIVO (runes)
  // ============================================================
  let indicators = $state([]);
  let selectedIndicator = $state(null);
  let selectedNetwork = $state(null); // null = todas
  let ranking = $state(null);
  let loadingIndicators = $state(true);
  let loadingRanking = $state(false);
  let error = $state(null);

  // ============================================================
  // FUNÇÕES
  // ============================================================
  async function loadIndicators() {
    loadingIndicators = true;
    error = null;
    try {
      const data = await getAvailableIndicators(codInep);
      indicators = data;
      const firstAvailable = indicators.find(i => i.available);
      if (firstAvailable) {
        selectedIndicator = firstAvailable.id;
        await loadRanking(firstAvailable.id);
      }
    } catch (err) {
      error = err instanceof ApiError ? err.message : 'Erro ao carregar indicadores';
    } finally {
      loadingIndicators = false;
    }
  }

  async function loadRanking(indicatorId, network = selectedNetwork) {
    loadingRanking = true;
    error = null;
    ranking = null;
    try {
      const opts = { network, national: false };
      const data = await getSchoolRanking(codInep, indicatorId, opts);
      ranking = data;
    } catch (err) {
      error = err instanceof ApiError ? err.message : 'Erro ao carregar ranking';
    } finally {
      loadingRanking = false;
    }
  }

  function handleIndicatorChange(event) {
    const id = event.target.value;
    selectedIndicator = id;
    loadRanking(id);
  }

  function handleNetworkChange(event) {
    const value = event.target.value;
    selectedNetwork = value === 'todas' ? null : value;
    if (selectedIndicator) {
      loadRanking(selectedIndicator, selectedNetwork);
    }
  }

  // ============================================================
  // CICLO DE VIDA
  // ============================================================
  onMount(loadIndicators);
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-6 space-y-6">
  <!-- Cabeçalho com seletores -->
  <header class="flex items-center justify-between flex-wrap gap-3">
    <h2 class="text-lg font-semibold text-gray-900">Ranking</h2>
    <div class="flex flex-wrap gap-4">
      {#if !loadingIndicators}
        <label class="flex items-center gap-2 text-sm">
          <span class="text-gray-600">Indicador:</span>
          <select
            value={selectedIndicator}
            onchange={handleIndicatorChange}
            class="border border-gray-300 rounded-md px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
          >
            {#each indicators as indicator}
              <option value={indicator.id} disabled={!indicator.available}>
                {indicator.label}{!indicator.available ? ' (indisponível)' : ''}
              </option>
            {/each}
          </select>
        </label>
        <label class="flex items-center gap-2 text-sm">
          <span class="text-gray-600">Rede:</span>
          <select
            value={selectedNetwork ?? 'todas'}
            onchange={handleNetworkChange}
            class="border border-gray-300 rounded-md px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
          >
            <option value="todas">Todas</option>
            <option value="municipal">Municipal</option>
            <option value="estadual">Estadual</option>
            <option value="privada">Privada</option>
          </select>
        </label>
      {/if}
    </div>
  </header>

  <!-- Estados de carregamento / erro -->
  {#if loadingIndicators}
    <p class="text-gray-500 text-sm">Carregando indicadores disponíveis...</p>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-3">
      {error}
    </div>
  {:else if loadingRanking}
    <p class="text-gray-500 text-sm">Calculando ranking...</p>
  {:else if ranking}
    
    <div class="mb-4 p-4 bg-brand-50 border border-brand-200 rounded-lg">
      <p class="text-sm text-brand-700 font-medium">
        Valor do indicador <span class="font-normal text-brand-600">{ranking.indicador.label}</span>
      </p>
      <p class="text-3xl font-bold text-brand-700">
        {ranking.indicador.valor}
        <span class="text-sm font-normal text-brand-500 ml-1">
          (ano {ranking.ano})
        </span>
      </p>
    </div>
    <!-- Rankings -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      {#if ranking.ranking.municipio}
        <div class="bg-gray-50 rounded-md p-4">
          <p class="text-xs font-medium text-gray-500 uppercase">Ranking Municipal</p>
          <p class="text-2xl font-bold text-gray-900 mt-1">
            {ranking.ranking.municipio.posicao}º
            <span class="text-sm font-normal text-gray-500">
              de {ranking.ranking.municipio.total}
            </span>
          </p>
          <p class="text-xs text-gray-600 mt-1">
            Acima de {ranking.ranking.municipio.percentil}% das escolas
            {#if ranking.rede}
              da rede {ranking.rede}
            {/if}
          </p>
        </div>
      {/if}

      {#if ranking.ranking.estado}
        <div class="bg-gray-50 rounded-md p-4">
          <p class="text-xs font-medium text-gray-500 uppercase">Ranking Estadual</p>
          <p class="text-2xl font-bold text-gray-900 mt-1">
            {ranking.ranking.estado.posicao}º
            <span class="text-sm font-normal text-gray-500">
              de {ranking.ranking.estado.total}
            </span>
          </p>
          <p class="text-xs text-gray-600 mt-1">
            Acima de {ranking.ranking.estado.percentil}% das escolas
            {#if ranking.rede}
              da rede {ranking.rede}
            {/if}
          </p>
        </div>
      {/if}
    </div>

    <!-- Ano de referência -->
    {#if ranking.ano}
      <p class="text-xs text-gray-400 text-right">Dados de {ranking.ano}</p>
    {/if}

    <!-- Botão de exportação -->
    <div class="border-t border-gray-100 pt-4 flex justify-end">
      <button
        type="button"
        onclick={() => onExport({ codInep, indicator: selectedIndicator, ranking })}
        class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
      >
        Exportar relatório
      </button>
    </div>
  {/if}
</section>
