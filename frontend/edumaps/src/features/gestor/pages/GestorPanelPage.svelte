<script>
  // src/features/gestor/pages/GestorPanelPage.svelte
  import { onMount } from "svelte";
  import GestorPanel from "../components/GestorPanel.svelte";
  import { getGestorPanel } from "../api/gestorApi.js";
  import { ApiError } from "@/shared/api/client.js";

  let inep = $state(null);
  let data = $state(null);
  let loading = $state(true);
  let error = $state(null);

  async function load(code) {
    loading = true;
    error = null;
    try {
      data = await getGestorPanel(code);
    } catch (err) {
      data = null;
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar o painel do gestor.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const code = new URLSearchParams(window.location.search).get("inep");
    if (code) {
      inep = code;
      load(code);
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
      <h1 class="text-2xl font-bold text-gray-900">Painel do Gestor</h1>
      <p class="text-sm text-gray-600 mt-1">
        Raio-x da escola em poucos minutos.
      </p>
    </div>
    <button
      type="button"
      onclick={goBack}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar
    </button>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando painel do gestor…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if data}
    <GestorPanel
      {inep}
      escola={data.escola}
      resumo={data.resumo}
      matriculas={data.matriculas}
      turmas={data.turmas}
      docentes={data.docentes}
      infraestrutura={data.infraestrutura}
      equipamentos={data.equipamentos}
      acessibilidade={data.acessibilidade}
    />
  {/if}
</div>
