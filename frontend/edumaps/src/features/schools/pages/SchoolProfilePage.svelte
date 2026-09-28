<script>
  // src/features/schools/pages/SchoolProfilePage.svelte
  //
  // Página "/escola/perfil?inep=XXXXXXXX" — Perfil analítico da escola
  // (issue #105). Um único GET /api/school/:inep/profile devolve o
  // diagnóstico, a posição relativa, o benchmarking (cluster + peers) e
  // os sinais de atenção.
  import { onMount } from 'svelte';
  import SchoolProfile from '../components/profile/SchoolProfile.svelte';
  import { getSchoolProfile } from '../api/schoolProfileApi.js';
  import { transformProfileData } from '../utils/transformProfileData.js';
  import { ApiError } from '@/shared/api/client.js';

  let inep = $state(null);
  let profile = $state(null);
  let loading = $state(true);
  let error = $state(null);

  async function loadProfile(codInep) {
    loading = true;
    error = null;
    try {
      const raw = await getSchoolProfile(codInep);
      profile = transformProfileData(raw);
    } catch (err) {
      profile = null;
      error =
        err instanceof ApiError
          ? err.message
          : 'Erro ao carregar o perfil da escola.';
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const code = new URLSearchParams(window.location.search).get('inep');
    if (code) {
      inep = code;
      loadProfile(code);
    } else {
      loading = false;
      error = 'Nenhum código INEP informado (?inep=XXXXXXXX).';
    }
  });

  function selectPeer(id) {
    window.location.href = `/escola/perfil?inep=${id}`;
  }

  function goBack() {
    window.location.href = inep ? `/escola/panel?inep=${inep}` : '/escola/search';
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Perfil da Escola</h1>
      <p class="text-sm text-gray-600 mt-1">
        Diagnóstico, posição relativa e benchmarking justo.
      </p>
    </div>
    <button
      onclick={goBack}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar
    </button>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando perfil da escola…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if profile}
    <SchoolProfile {profile} onSelectPeer={selectPeer} />
  {/if}
</div>
