<!-- src/features/schools/pages/SchoolRankingPage.svelte -->
<script>
  import { onMount } from 'svelte';
  import { getSchoolInfo } from '../api/schoolApi.js';
  import SchoolRanking from '../components/SchoolRanking.svelte';
  import { router } from '@/app/router.svelte.js';

  // ID da escola – pode vir de query string ou de uma prop
  // Vamos usar o DEMO_SCHOOL_COD_INEP da fixture como fallback
  const DEFAULT_INEP = 35011162;

  let codInep = $state(DEFAULT_INEP);
  let school = $state(null);
  let loading = $state(true);
  let error = $state(null);

  // Função para carregar os dados da escola
  async function loadSchoolInfo(inep) {
    loading = true;
    error = null;
    try {
      const data = await getSchoolInfo(inep);
      school = data;
    } catch (err) {
      error = err.message || 'Erro ao carregar informações da escola';
      console.error(err);
    } finally {
      loading = false;
    }
  }

  // Carrega os dados ao montar ou quando o código mudar
  onMount(() => {
    // Tenta obter o código da URL (ex: ?inep=35011162)
    const params = new URLSearchParams(window.location.search);
    const inepFromUrl = params.get('inep');
    if (inepFromUrl) codInep = parseInt(inepFromUrl, 10);
    loadSchoolInfo(codInep);
  });

  // Callback quando o usuário clicar em uma escola de referência
  function handleSelectSchool(refInep) {
    // Navega para a mesma página com o novo INEP na query string
    router.navigate(`/escola/ranking?inep=${refInep}`);
    // Recarrega os dados da escola
    codInep = refInep;
    loadSchoolInfo(refInep);
  }

  // Callback para exportar relatório
  function handleExport(data) {
    console.log('Exportando relatório:', data);
    // Futuro: integrar com geração de PDF
    alert('Relatório exportado (simulação)');
  }

  // Voltar para a busca
  function goBack() {
    router.navigate('/busca');
  }
</script>

<div class="max-w-6xl mx-auto px-4 py-8 space-y-8">
  <!-- Cabeçalho da página -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">📊 Painel de Ranking da Escola</h1>
      <p class="text-gray-600">Compare o desempenho da sua escola com outras instituições.</p>
    </div>
    <button
      onclick={goBack}
      class="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 transition"
    >
      ← Voltar para busca
    </button>
  </div>

  <!-- Estado de carregamento da escola -->
  {#if loading}
    <div class="text-center py-8 text-gray-500">Carregando dados da escola...</div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 rounded-card p-4 text-red-700">
      <p class="font-medium">Erro ao carregar escola</p>
      <p class="text-sm">{error}</p>
    </div>
  {:else if school}
    <!-- Cartão com informações da escola -->
    <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 class="text-xl font-bold text-gray-900">{school.escola}</h2>
          <div class="mt-1 space-y-1 text-sm text-gray-600">
            <p>
              <span class="font-medium">Código INEP:</span>
              <span class="font-mono">{school.codigo_inep}</span>
            </p>
            {#if school.municipio}
              <p>
                <span class="font-medium">Município:</span>
                {school.municipio} {school.uf ? `- ${school.uf}` : ''}
              </p>
            {/if}
            {#if school.endereco}
              <p>
                <span class="font-medium">Endereço:</span>
                {school.endereco}
              </p>
            {/if}
            {#if school.telefone}
              <p>
                <span class="font-medium">Telefone:</span>
                <a href={`tel:${school.telefone}`} class="text-brand-600 hover:underline">
                  {school.telefone}
                </a>
              </p>
            {/if}
            {#if school.tipo}
              <p>
                <span class="font-medium">Tipo:</span>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-brand-50 text-brand-700">
                  {school.tipo}
                </span>
              </p>
            {/if}
            {#if school.modalidades?.length}
              <p>
                <span class="font-medium">Modalidades:</span>
                <span class="flex flex-wrap gap-1 mt-1">
                  {#each school.modalidades as mod}
                    <span class="px-2 py-0.5 bg-gray-100 text-gray-700 rounded text-xs">
                      {mod}
                    </span>
                  {/each}
                </span>
              </p>
            {/if}
          </div>
        </div>
        {#if school.osm}
          <a
            href={school.osm}
            target="_blank"
            rel="noopener noreferrer"
            class="px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition text-sm"
          >
            🗺️ Ver no OpenStreetMap
          </a>
        {/if}
      </div>
    </section>

    <!-- Componente de Ranking (já com seletor, ranking, cluster e escolas de referência) -->
    <SchoolRanking
      codInep={codInep}
      onSelectSchool={handleSelectSchool}
      onExport={handleExport}
    />
  {:else}
    <div class="text-center py-8 text-gray-400">
      Nenhuma escola encontrada.
    </div>
  {/if}
</div>
