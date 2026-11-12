<!-- src/features/gestor/pages/PlanosPage.svelte -->
<script>
  // Planos de gestão da escola (#371, épico #368): lista e criação. O plano
  // abre em /gestor/planos/:id (acompanhamento e edição). Exige sessão.
  import { onMount } from "svelte";
  import { listPlanos, createPlano } from "../api/gestorPlanosApi.js";
  import { getDocumentos } from "../api/gestorDocumentosApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    PLANO_TIPOS,
    PLANO_TIPO_LABEL,
    PLANO_SITUACAO_LABEL,
    PLANO_SITUACAO_BADGE,
    PLANO_LIMITS as L,
    fmtData,
  } from "../constants/planos.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);
  let planos = $state([]);
  let mostrarArquivados = $state(false);
  let form = $state(null);
  let salvando = $state(false);
  let documentos = $state([]);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      planos = (await listPlanos(me.cod_inep, { arquivados: mostrarArquivados })).planos ?? [];
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os planos.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function novoPlano() {
    form = { tipo: "acao", titulo: "", inicio: "", fim: "", documento_id: "" };
    // arquivo do plano (#385): opcional; sem a lista, o campo só não aparece
    try {
      documentos = (await getDocumentos(inep)).documentos ?? [];
    } catch {
      documentos = [];
    }
  }

  async function criar() {
    if (!form.titulo.trim()) {
      addToast("Dê um título ao plano.", "warning");
      return;
    }
    if (form.inicio && form.fim && form.fim < form.inicio) {
      addToast("O fim do plano não pode ser antes do início.", "warning");
      return;
    }
    salvando = true;
    try {
      const p = await createPlano(inep, {
        tipo: form.tipo,
        titulo: form.titulo.trim(),
        inicio: form.inicio || null,
        fim: form.fim || null,
        documento_id: form.documento_id ? Number(form.documento_id) : null,
      });
      addToast("Plano criado.", "success");
      window.location.href = `/gestor/planos/${p.id}`;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível criar o plano.");
      if (msg) addToast(msg, "error");
    } finally {
      salvando = false;
    }
  }

  async function alternarArquivados() {
    mostrarArquivados = !mostrarArquivados;
    await carregar();
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
    await carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6 max-w-4xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Planos de gestão</h1>
      <p class="text-sm text-gray-600 mt-1">
        Objetivos, metas e ações do plano da escola, com o andamento de cada um.
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors">Sair</button>
      {/if}
      {#if inep}
        <a href={`/gestor/painel?inep=${inep}`} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">← Painel</a>
      {/if}
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando planos…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver os planos da escola." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else}
    <div class="flex flex-wrap items-center justify-between gap-2" data-tour="planos-acoes">
      <button type="button" onclick={novoPlano} class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">+ Novo plano</button>
      <label class="flex items-center gap-2 text-xs text-gray-600">
        <input type="checkbox" checked={mostrarArquivados} onchange={alternarArquivados} class="accent-blue-600" />
        Mostrar arquivados
      </label>
    </div>

    {#if form}
      <section class="rounded-card border border-blue-200 bg-blue-50 p-4 space-y-3" aria-label="Novo plano">
        <div class="grid gap-3 sm:grid-cols-2">
          <label class="text-xs text-gray-600"><span class="block">Tipo</span>
            <select bind:value={form.tipo} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              {#each PLANO_TIPOS as t (t.valor)}<option value={t.valor}>{t.rotulo}</option>{/each}
            </select></label>
          <label class="text-xs text-gray-600"><span class="block">Título *</span>
            <input bind:value={form.titulo} maxlength={L.TITULO_MAX} placeholder="Ex.: Plano de ação 2026" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          <label class="text-xs text-gray-600"><span class="block">Início</span>
            <input type="date" bind:value={form.inicio} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          <label class="text-xs text-gray-600"><span class="block">Fim</span>
            <input type="date" bind:value={form.fim} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
        </div>
        {#if documentos.length}
          <label class="block text-xs text-gray-600"><span class="block">Arquivo do plano (opcional)</span>
            <select bind:value={form.documento_id} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              <option value="">Nenhum por enquanto</option>
              {#each documentos as d (d.id)}<option value={String(d.id)}>{d.nome} (v{d.versao_atual})</option>{/each}
            </select></label>
        {/if}
        <p class="text-xs text-gray-500">
          O plano nasce como rascunho. Os objetivos, as metas e as ações você cadastra na página do plano.
          O arquivo do plano (PDF do PPP, por exemplo) fica guardado em Documentos e planos; aqui você só aponta
          para ele.
        </p>
        <div class="flex justify-end gap-2">
          <button type="button" onclick={() => (form = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
          <button type="button" onclick={criar} disabled={salvando} class="px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700 disabled:opacity-50">{salvando ? "Criando…" : "Criar plano"}</button>
        </div>
      </section>
    {/if}

    <ul class="space-y-3" data-tour="planos-lista">
      {#each planos as p (p.id)}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-4">
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div class="min-w-0">
              <a href={`/gestor/planos/${p.id}`} class="text-base font-semibold text-blue-700 hover:underline">{p.titulo}</a>
              <p class="text-xs text-gray-500 mt-0.5">
                {PLANO_TIPO_LABEL[p.tipo] ?? p.tipo}
                {#if p.inicio || p.fim}{" · "}{fmtData(p.inicio)} a {fmtData(p.fim)}{/if}
              </p>
            </div>
            <div class="flex items-center gap-2">
              {#if p.arquivado}<span class="px-2 py-0.5 rounded-full text-[11px] font-medium bg-gray-200 text-gray-600">Arquivado</span>{/if}
              <span class={`px-2 py-0.5 rounded-full text-[11px] font-medium ${PLANO_SITUACAO_BADGE[p.situacao] ?? "bg-gray-100 text-gray-600"}`}>{PLANO_SITUACAO_LABEL[p.situacao] ?? p.situacao}</span>
            </div>
          </div>
          {#if p.resumo}
            <p class="text-xs text-gray-600 mt-2">
              {p.resumo.n_objetivos} objetivo(s) · {p.resumo.n_metas} meta(s) ·
              {p.resumo.n_acoes_concluidas} de {p.resumo.n_acoes} ação(ões) concluída(s)
              {#if p.resumo.n_acoes_atrasadas > 0}
                · <span class="text-red-700 font-semibold">{p.resumo.n_acoes_atrasadas} atrasada(s)</span>
              {/if}
            </p>
          {/if}
        </li>
      {:else}
        <li class="rounded-card bg-white border border-gray-200 p-8 text-center text-sm text-gray-500">
          Nenhum plano ainda. Comece pelo plano de ação do ano, ou pelo plano de gestão.
        </li>
      {/each}
    </ul>
  {/if}
</div>
