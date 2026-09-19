<!-- src/features/gestor/pages/GestorPesquisasWizardPage.svelte -->
<script>
  // Montagem de uma pesquisa (nova ou edição de rascunho/publicada).
  // Query params: ?inep=&id= (id opcional). Carrega a sessão do gestor
  // (localStorage) e o detalhe da pesquisa quando editando.
  import { onMount } from "svelte";
  import { getPesquisa } from "../api/gestorPesquisasApi.js";
  import { getGestorSession } from "../utils/gestorSession.js";
  import { ApiError } from "@/shared/api/client.js";
  import SurveyWizard from "../components/survey/SurveyWizard.svelte";

  let inep = $state(null);
  let pesquisaId = $state(null);
  let gestor = $state(null);
  let initialSurvey = $state(null);
  let loading = $state(true);
  let error = $state(null);

  onMount(async () => {
    const params = new URLSearchParams(window.location.search);
    inep = params.get("inep") ?? null;
    pesquisaId = params.get("id");
    gestor = inep ? getGestorSession(inep) : null;

    try {
      if (!inep) {
        error = "Nenhum código INEP informado (?inep=XXXXXXXX).";
      } else if (pesquisaId) {
        initialSurvey = await getPesquisa(pesquisaId);
      }
    } catch (err) {
      error =
        err instanceof ApiError ? err.message : "Não foi possível carregar a pesquisa.";
    } finally {
      loading = false;
    }
  });
</script>

<div class="space-y-4">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">
        {pesquisaId ? "Editar pesquisa" : "Nova pesquisa da comunidade"}
      </h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}publicado para quem você conhece: a
        comunidade responde em segundos pelo celular.
      </p>
    </div>
    <a
      href={`/gestor/pesquisas?inep=${inep}`}
      class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
    >
      ← Lista de pesquisas
    </a>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando…</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">
      {error}
    </div>
  {:else}
    <SurveyWizard
      inep={inep}
      initialGestor={gestor}
      initialSurvey={initialSurvey}
      readonly={initialSurvey?.status === "publicada"}
    />
  {/if}
</div>