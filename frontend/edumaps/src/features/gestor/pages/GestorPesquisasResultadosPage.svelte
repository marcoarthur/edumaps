<!-- src/features/gestor/pages/GestorPesquisasResultadosPage.svelte -->
<script>
  // Resultados de uma pesquisa (?pesquisa=<id>). Exige sessão do gestor:
  // sem token mostra o cartão de login; 401 volta para o login. Gráficos em
  // SVG puro (decisão da fase 2, sem biblioteca de charts).
  import { onMount } from "svelte";
  import {
    getResultados,
    fetchMe,
    logoutGestor,
  } from "../api/gestorPesquisasApi.js";
  import { ApiError, setApiToken } from "@/shared/api/client.js";
  import {
    getSessaoToken,
    setSessaoToken,
    clearSessaoToken,
  } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import OpcaoBars from "../components/survey/OpcaoBars.svelte";
  import { ANSWER_TYPE_LABELS } from "../constants/pesquisas.js";

  let pesquisaId = $state(null);
  let inep = $state(null);
  let dados = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  async function carregarResultados() {
    if (!pesquisaId) return;
    carregando = true;
    precisaLogin = false;
    error = null;
    try {
      const [res, me] = await Promise.all([getResultados(pesquisaId), fetchMe()]);
      dados = res;
      gestor = me;
      inep = me.cod_inep;
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        precisaLogin = true;
        setApiToken(null);
        clearSessaoToken();
      } else {
        error =
          err instanceof ApiError
            ? err.message
            : "Não foi possível carregar os resultados.";
      }
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    carregarResultados();
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      dados = null;
      gestor = null;
      precisaLogin = true;
    }
  }

  function dataHora(iso) {
    if (!iso) return "—";
    const d = new Date(iso.replace(" ", "T"));
    return Number.isNaN(d.getTime())
      ? iso
      : d.toLocaleDateString("pt-BR") +
          " " +
          d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    pesquisaId = params.get("pesquisa") ?? params.get("id");

    if (!pesquisaId) {
      error = "Nenhuma pesquisa informada (?pesquisa=<id>).";
      carregando = false;
      return;
    }

    const token = getSessaoToken();
    if (token) setApiToken(token);
    carregarResultados();
  });
</script>

<div class="space-y-4">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Resultados da pesquisa</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}agregação das respostas da comunidade.
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">
          {gestor.nome} {gestor.email}
        </span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >
          Sair
        </button>
      {/if}
      <a
        href={inep ? `/gestor/pesquisas?inep=${inep}` : "/gestor/pesquisas"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >
        ← Lista de pesquisas
      </a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando resultados…</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">
      {error}
    </div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem={null} />
  {:else if dados}
    <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-6">
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm text-gray-600">
          <span class="text-2xl font-bold text-gray-900">{dados.n_respostas}</span>
          resposta{dados.n_respostas === 1 ? "" : "s"} no total
        </p>
        <span class="rounded-full bg-green-100 text-green-800 px-3 py-1 text-[11px] font-semibold">
          Pesquisa publicada
        </span>
      </div>

      {#if dados.n_respostas === 0}
        <p class="text-sm text-gray-500 text-center py-8">
          Ninguém respondeu ainda. Compartilhe o link de resposta.
        </p>
      {/if}

      <div class="grid gap-5">
        {#each dados.perguntas as p (p.id)}
          <section class="rounded-md border border-gray-200 p-4" aria-label={`Resultado pergunta ${p.ordem}`}>
            <p class="text-sm font-semibold text-gray-900">
              {p.ordem}. {p.texto}
            </p>
            <p class="mt-0.5 text-[11px] text-gray-400 uppercase tracking-wide">
              {ANSWER_TYPE_LABELS[p.tipo] ?? p.tipo}
            </p>

            {#if p.tipo === "texto"}
              {#if (p.respostas_texto ?? []).length === 0}
                <p class="mt-3 text-xs text-gray-400">Sem respostas livres ainda.</p>
              {:else}
                <ul class="mt-3 space-y-2">
                  {#each p.respostas_texto as r, i (i)}
                    <li class="rounded-md bg-gray-50 border border-gray-100 px-3 py-2">
                      <p class="text-sm text-gray-700">“{r.texto}”</p>
                      <p class="mt-1 text-[10px] text-gray-400">{dataHora(r.respondida_em)}</p>
                    </li>
                  {/each}
                </ul>
              {/if}
            {:else}
              <div class="mt-3">
                <OpcaoBars opcoes={p.opcoes ?? []} total={p.n_respondidas} />
              </div>
            {/if}
          </section>
        {/each}
      </div>
    </div>
  {/if}
</div>