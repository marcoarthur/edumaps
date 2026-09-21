<!-- src/features/schools/pages/SchoolFinancePage.svelte -->
<script>
  // src/features/schools/pages/SchoolFinancePage.svelte
  import { onMount, onDestroy } from "svelte";
  import {
    getSchoolFinance,
    requestSchoolSiope,
    watchJobProgress,
  } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
  import SchoolFinance from "../components/panel/SchoolFinance.svelte";

  let inep = $state(null);
  let escola = $state(null);
  let series = $state([]);
  let categorias = $state([]);
  let loading = $state(true);
  let error = $state(null);

  // SIOPE (remuneração municipal): só a rede municipal tem dados.
  let siope = $state(null);
  let gestorDaEscola = $state(false);
  let anoSelecionado = $state(null);
  let buscando = $state(false);
  let progresso = $state(null);
  let erroSiope = $state(null);
  let cancelarWatch = null;

  const siopeHabilitado = $derived(!!siope?.habilitado && gestorDaEscola);

  const anosDisponiveis = $derived.by(() => {
    if (!siope?.habilitado) return [];
    const presentes = new Set((siope.anos_presentes ?? []).map(Number));
    const out = [];
    for (let ano = siope.ano_inicial; ano <= siope.ano_atual; ano += 1) {
      if (!presentes.has(ano)) out.push(ano);
    }
    return out;
  });

  async function loadFinance(codInep) {
    loading = true;
    error = null;
    try {
      const data = await getSchoolFinance(codInep);
      escola = data.escola ?? null;
      series = data.series ?? [];
      categorias = data.categorias ?? [];
      siope = data.siope ?? null;
      anoSelecionado = anosDisponiveis.at(-1) ?? null;
    } catch (err) {
      escola = null;
      series = [];
      categorias = [];
      siope = null;
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar o painel financeiro.";
    } finally {
      loading = false;
    }
  }

  // O disparo do SIOPE exige sessão do gestor da escola; o card só aparece
  // para ele (sem validação adicional de titularidade).
  async function checarGestor(codInep) {
    restaurarSessao();
    try {
      const me = await fetchMe();
      gestorDaEscola = String(me.cod_inep) === String(codInep);
    } catch {
      gestorDaEscola = false;
    }
  }

  async function buscarSiope() {
    if (!anoSelecionado) return;
    buscando = true;
    erroSiope = null;
    progresso = { percent: 0, message: "Enfileirando…" };
    try {
      const { job_id } = await requestSchoolSiope(inep, Number(anoSelecionado));
      cancelarWatch = watchJobProgress(job_id, {
        onProgress: (p) => {
          progresso = p;
        },
        onDone: async () => {
          buscando = false;
          progresso = null;
          addToast("Dados do SIOPE atualizados.", "success");
          await loadFinance(inep);
        },
        onError: (msg) => {
          buscando = false;
          progresso = null;
          erroSiope = msg;
        },      });
    } catch (err) {
      buscando = false;
      progresso = null;
      erroSiope =
        err instanceof ApiError
          ? err.message
          : "Não foi possível iniciar a busca no SIOPE.";
    }
  }

  onMount(() => {
    const code = new URLSearchParams(window.location.search).get("inep");
    if (code) {
      inep = code;
      loadFinance(code);
      checarGestor(code);
    } else {
      loading = false;
      error = "Nenhum código INEP informado (?inep=XXXXXXXX).";
    }
  });

  onDestroy(() => cancelarWatch?.());

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
  {:else}
    {#if siopeHabilitado}
      <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-3">
        <div>
          <h2 class="text-sm font-semibold text-gray-900">
            Dados do SIOPE (remuneração municipal)
          </h2>
          <p class="text-xs text-gray-600 mt-1">
            Baixe os dados de um ano que ainda não está disponível. A busca roda
            em segundo plano (você pode acompanhar o progresso abaixo).
          </p>
        </div>

        {#if anosDisponiveis.length === 0}
          <p class="text-sm text-gray-500">Todos os anos já foram baixados.</p>
        {:else}
          <div class="flex flex-wrap items-center gap-2">
            <label class="text-sm text-gray-600">
              Ano
              <select
                bind:value={anoSelecionado}
                disabled={buscando}
                class="ml-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white disabled:opacity-50"
              >
                {#each anosDisponiveis as ano (ano)}
                  <option value={ano}>{ano}</option>
                {/each}
              </select>
            </label>
            <button
              type="button"
              onclick={buscarSiope}
              disabled={buscando}
              class="px-4 py-2 rounded-md bg-brand-700 text-white text-sm font-semibold hover:bg-brand-600 disabled:opacity-50 transition-colors"
            >
              {buscando ? "Buscando…" : "Buscar informações via SIOPE"}
            </button>
          </div>
        {/if}

        {#if progresso}
          <div class="space-y-1">
            <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div
                class="h-full bg-brand-600 transition-all"
                style={`width:${Math.min(100, Math.max(0, progresso.percent ?? 0))}%`}
              ></div>
            </div>
            <p class="text-xs text-gray-500">
              {progresso.message ?? "Processando…"}
              ({Math.round(progresso.percent ?? 0)}%)
            </p>
          </div>
        {/if}

        {#if erroSiope}
          <p class="text-sm text-red-600" role="alert">{erroSiope}</p>
        {/if}
      </section>
    {/if}

    {#if series.length === 0}
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-8 text-center">
        <p class="text-gray-500">
          Sem dados financeiros (folha de pagamento) para esta escola.
        </p>
      </div>
    {:else}
      <SchoolFinance {inep} {escola} {series} {categorias} />
    {/if}
  {/if}
</div>
