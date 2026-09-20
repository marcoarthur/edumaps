<!-- src/features/gestor/pages/ReunioesPage.svelte -->
<script>
  // Lista de reuniões do gestor, com busca/status/intervalo e ações rápidas.
  import { onMount } from "svelte";
  import {
    listReunioes,
    marcarRealizada,
    cancelarReuniao,
    deleteReuniao,
  } from "../api/gestorReunioesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    REUNIAO_STATUS_BADGE,
    REUNIAO_STATUS_LABELS,
    AVISO_METODO_LABELS,
  } from "../constants/reunioes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let reunioes = $state([]);
  let q = $state("");
  let statusFiltro = $state("");
  let de = $state("");
  let ate = $state("");

  const deApi = $derived(de ? `${de} 00:00:00` : "");
  const ateApi = $derived(ate ? `${ate} 23:59:59` : "");

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar() {
    if (!inep) return;
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      reunioes = await listReunioes(inep, { q, status: statusFiltro, de: deApi, ate: ateApi });
    } catch (err) {
      const msg = onApiError(err, "Não foi possível listar as reuniões.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function iniciar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      await carregar();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as reuniões.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function acao(r, tipo) {
    try {
      if (tipo === "realizar") await marcarRealizada(inep, r.id);
      else if (tipo === "cancelar") await cancelarReuniao(inep, r.id);
      else if (tipo === "excluir") {
        if (!window.confirm(`Excluir a reunião "${r.titulo}"?`)) return;
        await deleteReuniao(inep, r.id);
      }
      await carregar();
      const msgs = { realizar: "Reunião marcada como realizada.", cancelar: "Reunião cancelada.", excluir: "Reunião excluída." };
      addToast(msgs[tipo], "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível concluir a ação.");
      if (msg) addToast(msg, "error");
    }
  }

  function dataHora(iso) {
    const d = new Date(iso.replace(" ", "T"));
    if (Number.isNaN(d.getTime())) return iso;
    return (
      d.toLocaleDateString("pt-BR", { weekday: "short", day: "2-digit", month: "short" }) +
      " · " +
      d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
    );
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      gestor = null;
      precisaLogin = true;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await iniciar();
  }

  onMount(() => {
    restaurarSessao();
    iniciar();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Reuniões &amp; Atas</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}agende, convide e registre o que ficou decidido.
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      {/if}
      <a
        href="/gestor/contatos"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Agenda</a>
      <a
        href="/gestor/reunioes/nova"
        class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
      >+ Nova reunião</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando reuniões…</p></div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver as reuniões." />
  {:else}
    <!-- filtros -->
    <form
      onsubmit={(e) => { e.preventDefault(); carregar(); }}
      class="rounded-card bg-white border border-gray-200 shadow-card p-4 grid gap-3 sm:grid-cols-[1fr_auto_auto_auto_auto] items-end"
    >
      <label class="block">
        <span class="block text-xs font-medium text-gray-600 mb-1">Buscar</span>
        <input
          bind:value={q}
          placeholder="Título…"
          class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </label>
      <label class="block">
        <span class="block text-xs font-medium text-gray-600 mb-1">Status</span>
        <select bind:value={statusFiltro} class="h-9 px-2 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">Todos</option>
          <option value="agendada">Agendadas</option>
          <option value="realizada">Realizadas</option>
          <option value="cancelada">Canceladas</option>
        </select>
      </label>
      <label class="block">
        <span class="block text-xs font-medium text-gray-600 mb-1">De</span>
        <input type="date" bind:value={de} class="h-9 px-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
      </label>
      <label class="block">
        <span class="block text-xs font-medium text-gray-600 mb-1">Até</span>
        <input type="date" bind:value={ate} class="h-9 px-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
      </label>
      <button type="submit" class="h-9 px-4 rounded-md bg-gray-800 text-white text-sm font-medium hover:bg-gray-900 transition-colors">
        Filtrar
      </button>
    </form>

    <ul class="space-y-3">
      {#each reunioes as r (r.id)}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-4 flex flex-wrap items-center gap-4">
          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <span class={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${REUNIAO_STATUS_BADGE[r.status] ?? "bg-gray-100 text-gray-600"}`}>
                {REUNIAO_STATUS_LABELS[r.status] ?? r.status}
              </span>
              {#if r.tem_ata}
                <span class="rounded-full bg-green-100 text-green-800 px-2.5 py-0.5 text-[11px] font-semibold">ata salva</span>
              {/if}
              <span class="text-xs text-gray-400">{AVISO_METODO_LABELS[r.aviso_metodo] ?? r.aviso_metodo}</span>
            </div>
            <a href={`/gestor/reunioes/${r.id}`} class="block mt-1 text-sm font-semibold text-gray-900 hover:text-blue-700 transition-colors">
              {r.titulo}
            </a>
            <p class="text-xs text-gray-500 mt-0.5">
              {dataHora(r.quando)} · {r.duracao_min} min · {r.n_participantes} participante(s)
            </p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            {#if r.status === "agendada"}
              <button
                type="button"
                onclick={() => acao(r, "realizar")}
                class="px-3 py-1.5 rounded-md bg-green-600 text-white text-xs font-medium hover:bg-green-700 transition-colors"
              >Realizada</button>
              <button
                type="button"
                onclick={() => acao(r, "cancelar")}
                class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
              >Cancelar</button>
              <a
                href={`/gestor/reunioes/${r.id}/editar`}
                class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
              >Editar</a>
            {:else if r.status === "cancelada"}
              <button
                type="button"
                onclick={() => acao(r, "excluir")}
                class="px-3 py-1.5 rounded-md bg-red-50 text-red-600 text-xs font-medium hover:bg-red-100 transition-colors"
              >Excluir</button>
            {/if}
            <a
              href={`/gestor/reunioes/${r.id}`}
              class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
            >Abrir</a>
          </div>
        </li>
      {:else}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center">
          {#if q || statusFiltro || de || ate}
            <p class="text-sm text-gray-500">Nada encontrado com esses filtros.</p>
          {:else}
            <p class="text-sm text-gray-500">Nenhuma reunião ainda.</p>
            <a href="/gestor/reunioes/nova" class="mt-3 inline-block px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors">
              Agendar a primeira
            </a>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</div>