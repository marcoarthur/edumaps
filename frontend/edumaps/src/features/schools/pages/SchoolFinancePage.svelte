<script>
  // src/features/schools/pages/SchoolFinancePage.svelte
  import { onMount } from "svelte";
  import { getSchoolFinance } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import SchoolFinance from "../components/panel/SchoolFinance.svelte";

  let inep = $state(null);
  let escola = $state(null);
  let series = $state([]);
  let categorias = $state([]);
  let loading = $state(true);
  let error = $state(null);

  async function loadFinance(codInep) {
    loading = true;
    error = null;
    try {
      const data = await getSchoolFinance(codInep);
      escola = data.escola ?? null;
      series = data.series ?? [];
      categorias = data.categorias ?? [];
    } catch (err) {
      escola = null;
      series = [];
      categorias = [];
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar o painel financeiro.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const code = new URLSearchParams(window.location.search).get("inep");
    if (code) {
      inep = code;
      loadFinance(code);
    } else {
      loading = false;
      error = "Nenhum código INEP informado (?inep=XXXXXXXX).";
    }
  });

  function goBack() {
    window.location.href = inep ? `/escola/panel?inep=${inep}` : "/escola/search";
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Painel Financeiro</h1>
      {#if escola?.nome}
        <p class="text-sm text-gray-600 mt-1">
          {escola.nome} · INEP {inep}
        </p>
      {/if}
    </div>
    <button
      type="button"
      onclick={goBack}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar ao painel
    </button>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando dados financeiros…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if series.length === 0}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-8 text-center">
      <p class="text-gray-500">
        Sem dados financeiros (folha de pagamento) para esta escola.
      </p>
    </div>
  {:else}
    <SchoolFinance {inep} {escola} {series} {categorias} />
  {/if}
</div>
