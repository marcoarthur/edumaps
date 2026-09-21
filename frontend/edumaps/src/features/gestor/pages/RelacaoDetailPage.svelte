<!-- src/features/gestor/pages/RelacaoDetailPage.svelte -->
<script>
  // Detalhe da relação institucional: dados, timeline de interações e
  // documentos/anexos. Exige sessão do gestor.
  import { onMount } from "svelte";
  import {
    getRelacao,
    createInteracao,
    updateInteracao,
    deleteInteracao,
    uploadDocumento,
    downloadDocumento,
    deleteDocumento,
  } from "../api/gestorRelacoesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    RELACAO_STATUS_LABELS,
    RELACAO_STATUS_BADGE,
    RELACAO_PRIORIDADE_LABELS,
    RELACAO_PRIORIDADE_BADGE,
    INTERACAO_CANAIS,
    DOCUMENTO_TIPOS,
    RELACAO_LIMITS as L,
  } from "../constants/relacoes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  const relacaoId = Number(new URL(location.href).pathname.match(/\/(\d+)$/)?.[1]);

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let relacao = $state(null);
  let interacoes = $state([]);
  let documentos = $state([]);

  let interForm = $state(null);
  let docForm = $state({ tipo: "", data: "", referencia: "", arquivo: null });
  let enviandoDoc = $state(false);

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
      const det = await getRelacao(me.cod_inep, relacaoId);
      relacao = det;
      interacoes = det.interacoes ?? [];
      documentos = det.documentos ?? [];
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a relação.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  function novaInteracao() {
    interForm = {
      id: null,
      data: new Date().toISOString().slice(0, 10),
      canal: "",
      participante: "",
      assunto: "",
      descricao: "",
      resultado: "",
    };
  }

  function editarInteracao(i) {
    interForm = {
      id: i.id,
      data: i.data ? i.data.slice(0, 10) : "",
      canal: i.canal ?? "",
      participante: i.participante ?? "",
      assunto: i.assunto,
      descricao: i.descricao ?? "",
      resultado: i.resultado ?? "",
    };
  }

  async function salvarInteracao() {
    if (!interForm.assunto.trim()) {
      addToast("Informe o assunto da interação.", "warning");
      return;
    }
    const payload = {
      data: interForm.data || null,
      canal: interForm.canal.trim() || null,
      participante: interForm.participante.trim() || null,
      assunto: interForm.assunto.trim(),
      descricao: interForm.descricao.trim() || null,
      resultado: interForm.resultado.trim() || null,
    };
    try {
      if (interForm.id) {
        const atual = await updateInteracao(inep, relacaoId, interForm.id, payload);
        const idx = interacoes.findIndex((i) => i.id === interForm.id);
        if (idx !== -1) interacoes[idx] = atual;
        addToast("Interação atualizada.", "success");
      } else {
        interacoes = [await createInteracao(inep, relacaoId, payload), ...interacoes];
        addToast("Interação registrada.", "success");
      }
      interForm = null;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar a interação.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirInteracao(i) {
    if (!window.confirm("Excluir esta interação?")) return;
    try {
      await deleteInteracao(inep, relacaoId, i.id);
      interacoes = interacoes.filter((x) => x.id !== i.id);
      addToast("Interação excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a interação.");
      if (msg) addToast(msg, "error");
    }
  }

  async function enviarDocumento() {
    if (!docForm.arquivo) {
      addToast("Selecione um arquivo.", "warning");
      return;
    }
    enviandoDoc = true;
    try {
      const res = await uploadDocumento(inep, relacaoId, docForm);
      documentos = res.documentos ?? [];
      docForm = { tipo: "", data: "", referencia: "", arquivo: null };
      addToast("Documento anexado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível enviar o documento.");
      if (msg) addToast(msg, "error");
    } finally {
      enviandoDoc = false;
    }
  }

  async function baixarDocumento(d) {
    try {
      const { blob, filename } = await downloadDocumento(inep, relacaoId, d.id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível baixar o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  async function removerDocumento(d) {
    if (!window.confirm(`Remover "${d.nome_original}"?`)) return;
    try {
      await deleteDocumento(inep, relacaoId, d.id);
      documentos = documentos.filter((x) => x.id !== d.id);
      addToast("Documento removido.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível remover o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  function fmtData(d) {
    if (!d) return "";
    const [a, m, dia] = d.slice(0, 10).split("-");
    return `${dia}/${m}/${a}`;
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

<div class="space-y-6 max-w-3xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">{relacao?.assunto ?? "Relação"}</h1>
      <p class="text-sm text-gray-600 mt-1">
        {#if relacao}{relacao.entidade_nome}{#if relacao.entidade_tipo} ({relacao.entidade_tipo}){/if}{/if}
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors">Sair</button>
      {/if}
      <a href="/gestor/relacoes" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">← Relações</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando relação…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver a relação." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if relacao}
    <!-- resumo -->
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-2">
      <div class="flex flex-wrap items-center gap-2">
        <span class={`px-2 py-0.5 rounded-full text-[11px] font-medium ${RELACAO_STATUS_BADGE[relacao.status] ?? "bg-gray-100 text-gray-600"}`}>{RELACAO_STATUS_LABELS[relacao.status] ?? relacao.status}</span>
        <span class={`px-2 py-0.5 rounded-full text-[11px] font-medium ${RELACAO_PRIORIDADE_BADGE[relacao.prioridade] ?? "bg-gray-100 text-gray-600"}`}>{RELACAO_PRIORIDADE_LABELS[relacao.prioridade] ?? relacao.prioridade}</span>
        {#if relacao.vencida}<span class="text-[10px] uppercase text-red-600 font-semibold">vencida</span>{/if}
      </div>
      <dl class="grid gap-2 sm:grid-cols-2 text-sm">
        <div><dt class="text-xs text-gray-500">Finalidade</dt><dd class="text-gray-800">{relacao.finalidade ?? "—"}</dd></div>
        <div><dt class="text-xs text-gray-500">Responsável interno</dt><dd class="text-gray-800">{relacao.responsavel_interno ?? "—"}</dd></div>
        <div><dt class="text-xs text-gray-500">Próxima ação</dt><dd class="text-gray-800">{relacao.proxima_acao ?? "—"}</dd></div>
        <div><dt class="text-xs text-gray-500">Prazo</dt><dd class="text-gray-800">{relacao.prazo ? fmtData(relacao.prazo) : "—"}</dd></div>
      </dl>
      {#if relacao.descricao}<p class="text-sm text-gray-700 whitespace-pre-line">{relacao.descricao}</p>{/if}
    </section>

    <!-- timeline de interações -->
    <section class="space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="text-sm font-semibold text-gray-900">Histórico de interações</h2>
        <button type="button" onclick={novaInteracao} class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700">+ Interação</button>
      </div>

      {#if interForm}
        <div class="rounded-card border border-blue-200 bg-blue-50 p-3 space-y-2">
          <div class="grid gap-2 sm:grid-cols-3">
            <label class="text-xs text-gray-600"><span class="block">Data</span>
              <input type="date" bind:value={interForm.data} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
            <label class="text-xs text-gray-600"><span class="block">Canal</span>
              <input bind:value={interForm.canal} list="canais-int" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" />
              <datalist id="canais-int">{#each INTERACAO_CANAIS as c (c)}<option value={c}></option>{/each}</datalist></label>
            <label class="text-xs text-gray-600"><span class="block">Participante</span>
              <input bind:value={interForm.participante} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          </div>
          <label class="block text-xs text-gray-600"><span class="block">Assunto *</span>
            <input bind:value={interForm.assunto} maxlength={L.ASSUNTO_MAX} placeholder="Ex.: Reunião inicial" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          <label class="block text-xs text-gray-600"><span class="block">Descrição</span>
            <textarea bind:value={interForm.descricao} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea></label>
          <label class="block text-xs text-gray-600"><span class="block">Resultado / encaminhamento</span>
            <textarea bind:value={interForm.resultado} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea></label>
          <div class="flex justify-end gap-2">
            <button type="button" onclick={() => (interForm = null)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Cancelar</button>
            <button type="button" onclick={salvarInteracao} class="px-4 py-1.5 rounded-md bg-green-600 text-white text-xs font-semibold hover:bg-green-700">Salvar</button>
          </div>
        </div>
      {/if}

      <ol class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
        {#each interacoes as i (i.id)}
          <li class="p-3">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-800">
                  {i.assunto}
                  {#if i.canal}<span class="ml-2 text-[11px] text-gray-400">{i.canal}</span>{/if}
                </p>
                <p class="text-xs text-gray-500">
                  {fmtData(i.data)}{#if i.participante} · {i.participante}{/if}
                </p>
                {#if i.descricao}<p class="text-xs text-gray-600 mt-0.5">{i.descricao}</p>{/if}
                {#if i.resultado}<p class="text-xs text-gray-700 mt-0.5"><span class="font-medium">Encaminhamento:</span> {i.resultado}</p>{/if}
              </div>
              <div class="flex items-center gap-1 shrink-0">
                <button type="button" onclick={() => editarInteracao(i)} class="px-2.5 py-1 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Editar</button>
                <button type="button" onclick={() => excluirInteracao(i)} class="px-2.5 py-1 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">✕</button>
              </div>
            </div>
          </li>
        {:else}
          <li class="p-6 text-center text-sm text-gray-400">Nenhuma interação registrada.</li>
        {/each}
      </ol>
    </section>

    <!-- documentos -->
    <section class="space-y-3">
      <h2 class="text-sm font-semibold text-gray-900">Documentos</h2>
      <div class="rounded-card border border-gray-200 bg-white p-3 space-y-2">
        <div class="grid gap-2 sm:grid-cols-3">
          <label class="text-xs text-gray-600"><span class="block">Tipo</span>
            <input bind:value={docForm.tipo} list="tipos-doc" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" />
            <datalist id="tipos-doc">{#each DOCUMENTO_TIPOS as t (t)}<option value={t}></option>{/each}</datalist></label>
          <label class="text-xs text-gray-600"><span class="block">Data</span>
            <input type="date" bind:value={docForm.data} class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
          <label class="text-xs text-gray-600"><span class="block">Referência</span>
            <input bind:value={docForm.referencia} placeholder="nº ofício/protocolo" class="mt-1 w-full h-9 px-2 rounded-md border border-gray-300 text-sm" /></label>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <input type="file" accept=".pdf,.docx,.xlsx,.png,.jpg,.jpeg,.txt"
            onchange={(e) => (docForm.arquivo = e.target.files?.[0] ?? null)}
            class="text-xs" />
          <button type="button" onclick={enviarDocumento} disabled={enviandoDoc}
            class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50">
            {enviandoDoc ? "Enviando…" : "Anexar"}
          </button>
        </div>
      </div>

      <ul class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
        {#each documentos as d (d.id)}
          <li class="flex items-center justify-between gap-2 p-3">
            <div class="min-w-0">
              <button type="button" onclick={() => baixarDocumento(d)} class="text-sm text-blue-600 hover:underline truncate">{d.nome_original}</button>
              <p class="text-xs text-gray-500">
                {d.tipo ?? "documento"}{#if d.referencia} · {d.referencia}{/if}{#if d.data} · {fmtData(d.data)}{/if}
              </p>
            </div>
            <button type="button" onclick={() => removerDocumento(d)} class="px-2.5 py-1 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100 shrink-0">Remover</button>
          </li>
        {:else}
          <li class="p-6 text-center text-sm text-gray-400">Nenhum documento anexado.</li>
        {/each}
      </ul>
    </section>
  {/if}
</div>
