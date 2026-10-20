<script>
  // src/features/schools/pages/SchoolPanelPage.svelte
  import { onMount } from 'svelte';
  import SchoolPanel from '../components/panel/SchoolPanel.svelte';
  import { getSchoolPanelData } from '../api/schoolApi.js';
  import { getSchoolIvet, getSchoolIsocrona } from '../api/schoolIvetApi.js';
  import { transformPanelData } from '../utils/transformPanelData.js';
  import { ApiError } from '@/shared/api/client.js';

  // Estados reativos (Svelte 5 runes)
  let inep = $state(null);
  let school = $state(null);
  let indicators = $state([]);
  let similarSchools = $state([]);
  let desempenho = $state([]);
  let loading = $state(true);
  let error = $state(null);
  let loadingSimilar = $state(false); // já vem junto na mesma requisição
  let ivet = $state(null);            // GET /api/school/:cod_inep/ivet
  let isocrona = $state(null);        // GET /api/school/:cod_inep/isocrona

  // IVET e isócrona são acessórios: a ausência (404 = escola fora da
  // cobertura) não pode derrubar o painel — ficam null e o card/Legenda
  // mostram "não calculado".
  async function loadIvet(codInep) {
    try {
      ivet = await getSchoolIvet(codInep);
    } catch {
      ivet = null;
    }
  }

  async function loadIsocrona(codInep) {
    try {
      isocrona = await getSchoolIsocrona(codInep);
    } catch {
      isocrona = null;
    }
  }

  // Função para carregar os dados
  async function loadPanelData(codInep) {
    loading = true;
    error = null;
    // Dispara IVET/isócrona em paralelo: não bloqueiam o painel principal.
    loadIvet(codInep);
    loadIsocrona(codInep);
    try {
      const raw = await getSchoolPanelData(codInep);
      const transformed = transformPanelData(raw);
      school = transformed.school;
      indicators = transformed.indicators;
      similarSchools = transformed.similarSchools;
      desempenho = transformed.desempenho;
    } catch (err) {
      school = null;
      indicators = [];
      similarSchools = [];
      desempenho = [];
      error = err instanceof ApiError ? err.message : 'Erro ao carregar dados da escola.';
    } finally {
      loading = false;
    }
  }

  // Lê o parâmetro `inep` da query string na montagem
  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('inep');
    if (code) {
      inep = code;
      loadPanelData(code);
    } else {
      loading = false;
      error = 'Nenhum código INEP informado.';
    }
  });

  // Callback ao selecionar uma escola semelhante
  function handleSelectSimilarSchool(schoolId) {
    // Navega para o painel da escola selecionada (recarrega a página com novo INEP)
    window.location.href = `/escola/panel?inep=${schoolId}`;
  }

  // Voltar para a busca
  function goBack() {
    window.location.href = '/escola/search';
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Painel da Escola</h1>
      {#if school}
        <p class="text-gray-600 text-sm mt-1">{school.nome} · INEP {school.id_escola}</p>
      {/if}
    </div>
    <div class="flex items-center gap-2">
      {#if inep}
        <a
          href={`/gestor?inep=${inep}`}
          class="px-4 py-2 bg-emerald-50 text-emerald-700 text-sm font-semibold rounded-md hover:bg-emerald-100 transition-colors"
          title="Acesse o painel do gestor desta escola"
        >
          Você é o gestor?
        </a>
      {/if}
      <button
        onclick={goBack}
        class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
      >
        ← Voltar para busca
      </button>
    </div>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando dados da escola…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if school}
    <SchoolPanel
      {school}
      {indicators}
      {similarSchools}
      {desempenho}
      {ivet}
      {isocrona}
      loadingSimilarSchools={loadingSimilar}
      onSelectSimilarSchool={handleSelectSimilarSchool}
    />
  {/if}
</div>
