<!-- src/features/chat/pages/ChatPage.svelte -->
<script>
  // Assistente do Censo. Exige sessão do gestor (#224): sem token, ou com 401
  // em qualquer chamada (me, ask, progress, salvar), mostra o cartão de login.
  // O escopo da consulta (escola, município, UF) é decidido NO SERVIDOR a
  // partir da escola do gestor da sessão; aqui ele só é exibido, a partir do
  // recorte-padrão da escola — a pergunta vai sem contexto.
  import { onMount, onDestroy } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { getRecortePadrao } from "@/features/gestor/api/gestorRelatoriosApi.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import {
    askChat,
    getChatProgress,
    extractSql,
    extractResposta,
    extractResultado,
    extractOrigem,
    extractMeta,
    extractChart,
  } from "../api/chatApi.js";
  import { saveConversa } from "../api/chatApi.js";
  import { router } from "@/app/router.svelte.js";
  import ChatHistory from "../components/ChatHistory.svelte";
  import ChatInput from "../components/ChatInput.svelte";

  // ---- estado da conversa --------------------------------------------------
  let messages = $state([]); // { id, role, content, meta }
  let loading = $state(false);
  let error = $state(null);
  let abortController = null;
  let cancelled = false;

  // ---- modal de salvar conversa -------------------------------------------
  let showSaveModal = $state(false);
  let saveTitle = $state("");
  let saving = $state(false);
  let saveError = $state(null);

  // ---- sessão e escopo (somente leitura) -----------------------------------
  let carregando = $state(true);
  let precisaLogin = $state(false);
  let gestor = $state(null);
  let escopo = $state(null); // recorte-padrão da escola do gestor

  // Chips do ChatInput: o escopo que o servidor aplica (informativo).
  const contextoExibido = $derived(
    escopo
      ? Object.fromEntries(
          Object.entries({
            nome_escola: escopo.escola?.nome,
            cod_inep: escopo.escola?.cod_inep,
            nome_municipio: escopo.municipio?.nome,
            sg_uf: escopo.uf?.codigo,
          }).filter(([, v]) => v),
        )
      : {},
  );

  const is401 = (err) => err instanceof ApiError && err.status === 401;

  async function carregar() {
    carregando = true;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      gestor = me;
      escopo = null;
      if (me?.cod_inep) {
        try {
          escopo = await getRecortePadrao(String(me.cod_inep));
        } catch (err) {
          if (is401(err)) throw err;
          // Sem o recorte a tela só não exibe o escopo; o servidor o aplica igual.
          console.warn("[chat] escopo da escola indisponível:", err?.message ?? err);
        }
      }
    } catch (err) {
      if (is401(err)) {
        precisaLogin = true;
      } else {
        error = apiMessage(err, "Não foi possível carregar a sua sessão.");
      }
    } finally {
      carregando = false;
    }
  }

  function onLogin(sessao) {
    setSessaoToken(sessao?.token);
    restaurarSessao();
    error = null;
    carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });

  function generateId() {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  }

  function apiMessage(err, fallback) {
    return err instanceof ApiError ? err.message : fallback;
  }

  // ---- polling de progresso ------------------------------------------------
  async function pollJob(jobId) {
    for (;;) {
      if (cancelled) throw new DOMException("Aborted", "AbortError");
      await new Promise((resolve) => setTimeout(resolve, 1500));
      const progress = await getChatProgress(jobId);
      if (progress.state === "failed") {
        throw new Error(progress.error || "Falha ao consultar o assistente.");
      }
      if (progress.state === "finished") return progress.result ?? null;
    }
  }

  // ---- enviar pergunta -----------------------------------------------------
  async function handleSend(pergunta) {
    const texto = (pergunta ?? "").trim();
    if (!texto || loading) return;

    messages = [
      ...messages,
      {
        id: generateId(),
        role: "user",
        content: texto,
        meta: { timestamp: new Date().toISOString() },
      },
    ];

    loading = true;
    error = null;
    cancelled = false;
    abortController = new AbortController();

    try {
      const started = await askChat({ pergunta: texto });
      const result = await pollJob(started.job_id);
      appendAssistantMessage(result);
    } catch (err) {
      if (is401(err)) {
        // Sessão expirou no meio da conversa: volta ao login (a conversa fica).
        precisaLogin = true;
      } else if (err.name !== "AbortError") {
        error = apiMessage(err, "Erro ao consultar o Assistente do Censo.");
        messages = [
          ...messages,
          {
            id: generateId(),
            role: "assistant",
            content: `Erro: ${error}`,
            meta: { timestamp: new Date().toISOString() },
          },
        ];
      }
    } finally {
      loading = false;
    }
  }

  function appendAssistantMessage(result) {
    const content = extractResposta(result) ?? "Resposta processada.";
    const meta = {
      sql: extractSql(result),
      resultado: extractResultado(result),
      origem: extractOrigem(result),
      ...extractMeta(result),
      chart: extractChart(result),
      timestamp: new Date().toISOString(),
    };

    messages = [
      ...messages,
      { id: generateId(), role: "assistant", content, meta },
    ];
  }

  function clearChat() {
    messages = [];
    error = null;
  }

  // ---- salvar conversa -----------------------------------------------------
  function openSaveModal() {
    saveTitle = "";
    saveError = null;
    showSaveModal = true;
  }

  async function handleSave() {
    if (messages.length === 0) return;
    saving = true;
    saveError = null;
    try {
      await saveConversa({
        titulo: saveTitle.trim() || undefined,
        messages: messages.map(m => ({ role: m.role, content: m.content, meta: m.meta })),
      });
      showSaveModal = false;
    } catch (err) {
      if (is401(err)) {
        showSaveModal = false;
        precisaLogin = true;
        return;
      }
      saveError = err instanceof ApiError ? err.message : "Falha ao salvar conversa";
    } finally {
      saving = false;
    }
  }

  function goToHistorico() {
    router.navigate("/chat/historico");
  }

  onDestroy(() => {
    cancelled = true;
    if (abortController) abortController.abort();
  });
</script>

<div class="flex flex-col h-full">
  <header class="mb-6">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Assistente do Censo</h1>
        <p class="text-sm text-gray-600 mt-1">
          Pergunte em linguagem natural sobre escolas, matrículas, infraestrutura,
          indicadores e muito mais. O assistente traduz para SQL e consulta o
          Censo Escolar automaticamente.
        </p>
      </div>
      {#if gestor && !precisaLogin}
      <div class="flex items-center gap-2 flex-wrap">
        <button
          onclick={clearChat}
          disabled={messages.length === 0}
          class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 disabled:opacity-50 transition-colors"
        >
          Limpar conversa
        </button>
        <button
          onclick={openSaveModal}
          disabled={messages.length === 0}
          class="px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          Salvar conversa
        </button>
        <button
          onclick={goToHistorico}
          class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 transition-colors"
        >
          Buscar conversas anteriores
        </button>
      </div>
      {/if}
    </div>

    {#if error}
      <div class="mt-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-3 flex items-center justify-between">
        <span>{error}</span>
        <button onclick={() => (error = null)} class="text-red-500 hover:text-red-700 font-bold text-lg leading-none" aria-label="Fechar erro">×</button>
      </div>
    {/if}

    {#if showSaveModal}
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" role="dialog" aria-modal="true" aria-labelledby="save-modal-title">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
          <div class="flex items-center justify-between p-4 border-b">
            <h2 id="save-modal-title" class="text-lg font-semibold text-gray-900">Salvar conversa</h2>
            <button onclick={() => (showSaveModal = false)} class="text-gray-400 hover:text-gray-600 text-2xl leading-none" aria-label="Fechar">×</button>
          </div>
          <div class="p-4 space-y-4">
            <p class="text-sm text-gray-600">Dê um título opcional para facilitar a busca posterior.</p>
            <label class="block">
              <span class="text-sm font-medium text-gray-700 mb-1 block">Título (opcional)</span>
              <input
                type="text"
                bind:value={saveTitle}
                placeholder="Ex: Consulta sobre escolas em SP"
                class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                maxlength="100"
              />
            </label>
            {#if saveError}
              <p class="text-sm text-red-600">{saveError}</p>
            {/if}
          </div>
          <div class="flex justify-end gap-2 p-4 border-t">
            <button
              onclick={() => (showSaveModal = false)}
              class="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 text-sm font-medium"
            >
              Cancelar
            </button>
            <button
              onclick={handleSave}
              disabled={saving}
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50"
            >
              {saving ? "Salvando..." : "Salvar"}
            </button>
          </div>
        </div>
      </div>
    {/if}

    {#if !carregando && !precisaLogin && gestor}
      <section
        class="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4"
        aria-labelledby="chat-escopo-titulo"
        data-testid="chat-escopo"
      >
        <h2 id="chat-escopo-titulo" class="font-semibold text-blue-800 mb-1 text-sm">
          Escopo da consulta
        </h2>
        {#if escopo}
          <p class="text-sm text-blue-700">
            As perguntas consideram a sua escola,
            <strong>{escopo.escola?.nome ?? escopo.escola?.cod_inep}</strong>{#if escopo.municipio?.nome},
              em <strong>{escopo.municipio.nome}{escopo.uf?.codigo ? ` (${escopo.uf.codigo})` : ""}</strong>{/if}.
          </p>
        {:else}
          <p class="text-sm text-blue-700">As perguntas consideram a escola vinculada à sua conta.</p>
        {/if}
        <p class="text-xs text-blue-600 mt-1">
          O escopo vem da sua conta de gestor e não pode ser alterado aqui.
        </p>
      </section>
    {/if}
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando a sua sessão…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard
      onLogin={onLogin}
      titulo="Entrar para usar o Assistente"
      descricao="O Assistente do Censo é exclusivo para gestores escolares cadastrados."
      mensagem="Entre para usar o Assistente do Censo."
    />
  {:else if gestor}
    <div class="flex-1 min-h-0 flex flex-col">
      <ChatHistory {messages} {loading} />
      <ChatInput disabled={loading} contexto={contextoExibido} onsend={handleSend} />
    </div>
  {/if}
</div>
