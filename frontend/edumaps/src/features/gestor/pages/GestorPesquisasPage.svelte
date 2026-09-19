<!-- src/features/gestor/pages/GestorPesquisasPage.svelte -->
<script>
  // Lista de pesquisas do gestor de uma escola (?inep=): status, perguntas,
  // gestor responsável e ações por estado (rascunho: continuar/excluir).
  import { onMount } from "svelte";
  import { listPesquisas, deletePesquisa } from "../api/gestorPesquisasApi.js";
  import { getGestorSession, clearGestorSession } from "../utils/gestorSession.js";
  import { STATUS_LABELS } from "../constants/pesquisas.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";

  let inep = $state(null);
  let gestor = $state(null);
  let data = $state([]);
  let loading = $state(true);
  let error = $state(null);
  let deleting = $state(null);

  async function load() {
    if (!inep) return;
    loading = true;
    error = null;
    try {
      data = await listPesquisas(inep);
    } catch (err) {
      data = [];
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar as pesquisas.";
    } finally {
      loading = false;
    }
  }

  async function remove(id) {
    if (!window.confirm("Excluir este rascunho? A ação não pode ser desfeita.")) return;
    deleting = id;
    try {
      await deletePesquisa(id);
      addToast("Rascunho excluído.", "success");
      load();
    } catch (err) {
      addToast(
        err instanceof ApiError ? err.message : "Não foi possível excluir.",
        "error",
      );
    } finally {
      deleting = null;
    }
  }

  function mudarConta() {
    clearGestorSession(inep);
    gestor = null;
  }

  const statusBadge = {
    rascunho: "bg-amber-100 text-amber-800",
    publicada: "bg-green-100 text-green-800",
    arquivada: "bg-gray-100 text-gray-600",
  };

  function dataHora(iso) {
    if (!iso) return "—";
    const d = new Date(iso.replace(" ", "T"));
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString("pt-BR") + " " + d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
  }

  onMount(() => {
    inep = new URLSearchParams(window.location.search).get("inep") ?? null;
    gestor = inep ? getGestorSession(inep) : null;
    load();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Pesquisas da comunidade</h1>
      <p class="text-sm text-gray-600 mt-1">
        Monte pesquisas rápidas para pais, alunos e professores {inep ? `· escola ${inep}` : ""}.
      </p>
    </div>
    <div class="flex items-center gap-2">
      <a
        href="/gestor/painel?inep={inep}"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >
        ← Painel do gestor
      </a>
      <a
        href="/gestor/pesquisas/nova?inep={inep}"
        class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
      >
        + Nova pesquisa
      </a>
    </div>
  </header>

  {#if gestor}
    <div class="flex items-center justify-between gap-3 rounded-md bg-blue-50 border border-blue-200 px-4 py-3">
      <p class="text-sm text-blue-900">
        Logado como <span class="font-semibold">{gestor.nome}</span>
        {gestor.cargo ? ` · ${gestor.cargo}` : ""}
      </p>
      <button
        type="button"
        onclick={mudarConta}
        class="text-xs text-blue-700 hover:underline"
      >
        Mudar conta
      </button>
    </div>
  {/if}

  {#if !inep}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">
      Nenhum código INEP informado (?inep=XXXXXXXX).
    </div>
  {:else if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando pesquisas…</p>
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">
      {error}
    </div>
  {:else if data.length === 0}
    <div class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center space-y-3">
      <p class="text-gray-500">Nenhuma pesquisa ainda para esta escola.</p>
      <a
        href="/gestor/pesquisas/nova?inep={inep}"
        class="inline-block px-5 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
      >
        Criar a primeira pesquisa
      </a>
    </div>
  {:else}
    <ul class="space-y-3">
      {#each data as s (s.id)}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-4 flex flex-wrap items-center gap-3">
          <div class="flex-1 min-w-[220px]">
            <div class="flex items-center gap-2">
              <a
                href={s.status === "rascunho"
                  ? `/gestor/pesquisas/editar?id=${s.id}&inep=${inep}`
                  : `/gestor/pesquisas/editar?id=${s.id}&inep=${inep}`}
                class="text-base font-semibold text-gray-900 hover:text-blue-600"
              >
                {s.titulo}
              </a>
              <span class={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${statusBadge[s.status] ?? statusBadge.arquivada}`}>
                {STATUS_LABELS[s.status] ?? s.status}
              </span>
            </div>
            <p class="mt-1 text-xs text-gray-500">
              {s.n_perguntas} pergunta{s.n_perguntas === 1 ? "" : "s"} ·
              criada por {s.gestor?.nome} · atualizada {dataHora(s.updated_at)}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <a
              href={`/gestor/pesquisas/editar?id=${s.id}&inep=${inep}`}
              class="px-3 py-1.5 rounded-md bg-gray-100 text-gray-700 text-xs font-medium hover:bg-gray-200 transition-colors"
            >
              {s.status === "rascunho" ? "Continuar" : "Ver"}
            </a>
            {#if s.status === "rascunho"}
              <button
                type="button"
                onclick={() => remove(s.id)}
                disabled={deleting === s.id}
                class="px-3 py-1.5 rounded-md text-red-600 text-xs font-medium hover:bg-red-50 disabled:opacity-50 transition-colors"
              >
                {deleting === s.id ? "Excluindo…" : "Excluir"}
              </button>
            {/if}
          </div>
        </li>
      {/each}
    </ul>
  {/if}
</div>