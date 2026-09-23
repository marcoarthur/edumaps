<!-- src/features/chat/pages/ChatPage.svelte -->
<script>
  import { onMount, onDestroy } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { getGestorPanel } from "@/features/gestor/api/gestorApi.js";
  import { askChat, getChatProgress, extractSql, extractResposta, extractResultado, extractOrigem, extractMeta } from "../api/chatApi.js";
  import ChatHistory from "../components/ChatHistory.svelte";
  import ChatInput from "../components/ChatInput.svelte";

  // ---- estado da conversa --------------------------------------------------
  let messages = $state([]); // { id, role, content, meta }
  let loading = $state(false);
  let error = $state(null);
  let abortController = null;
  let cancelled = false;

  // ---- contexto do gestor --------------------------------------------------
  let contexto = $state({
    cod_municipio: "",
    cod_inep: "",
    nome_municipio: "",
    nome_escola: "",
    sg_uf: "",
  });
  let contextoCarregado = $state(false);
  let sessaoExpirada = $state(false);

  // Preenche o escopo com a escola do gestor logado (se houver sessão ativa).
  // Sem isso o assistente não sabe qual é "a minha escola" e pede o INEP.
  onMount(async () => {
    if (!restaurarSessao()) {
      console.info("[chat] sem sessão de gestor: contexto manual");
      return;
    }
    try {
      const me = await fetchMe();
      if (!me?.cod_inep) {
        console.warn("[chat] /me não retornou cod_inep", me);
        return;
      }
      const inep = String(me.cod_inep);
      contexto = { ...contexto, cod_inep: inep };

      const painel = await getGestorPanel(inep);
      const escola = painel?.escola;
      if (escola) {
        contexto = {
          cod_inep: inep,
          cod_municipio: escola.cod_municipio ? String(escola.cod_municipio) : "",
          nome_municipio: escola.municipio ?? "",
          nome_escola: escola.nome ?? "",
          sg_uf: escola.uf ?? "",
        };
        contextoCarregado = true;
      } else {
        console.warn("[chat] painel sem 'escola'", painel);
      }
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        sessaoExpirada = true;
        console.warn("[chat] sessão expirada (401): gestor precisa entrar novamente");
      } else {
        console.warn("[chat] falha ao carregar contexto da escola:", err?.message ?? err);
      }
    }
  });

  function generateId() {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  }

  function apiMessage(err, fallback) {
    return err instanceof ApiError ? err.message : fallback;
  }

  function contextoEnvio() {
    return {
      cod_municipio: contexto.cod_municipio || undefined,
      cod_inep: contexto.cod_inep || undefined,
      nome_municipio: contexto.nome_municipio || undefined,
      nome_escola: contexto.nome_escola || undefined,
      sg_uf: contexto.sg_uf || undefined,
    };
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
      const started = await askChat({ pergunta: texto, contexto: contextoEnvio() });
      const result = await pollJob(started.job_id);
      appendAssistantMessage(result);
    } catch (err) {
      if (err.name !== "AbortError") {
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
      <button
        onclick={clearChat}
        disabled={messages.length === 0}
        class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 disabled:opacity-50 transition-colors"
      >
        Limpar conversa
      </button>
    </div>

    {#if error}
      <div class="mt-3 bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-3 flex items-center justify-between">
        <span>{error}</span>
        <button onclick={() => (error = null)} class="text-red-500 hover:text-red-700 font-bold text-lg leading-none" aria-label="Fechar erro">×</button>
      </div>
    {/if}

    {#if sessaoExpirada}
      <div class="mt-3 bg-amber-50 border border-amber-200 text-amber-800 text-sm rounded-md p-3 flex items-center justify-between gap-3">
        <span>Sua sessão expirou. <a href="/gestor" class="underline font-medium">Entre novamente</a> para o assistente usar os dados da sua escola automaticamente.</span>
        <button onclick={() => (sessaoExpirada = false)} class="text-amber-600 hover:text-amber-800 font-bold text-lg leading-none" aria-label="Fechar aviso">×</button>
      </div>
    {/if}

    <div class="mt-4 bg-blue-50 border border-blue-200 rounded-lg p-4">
      <p class="font-semibold text-blue-800 mb-3 flex items-center gap-2">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.924 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
        </svg>
        Contexto do gestor (escopo da consulta)
      </p>
      <p class="text-sm text-blue-700 mb-3">
        {#if contextoCarregado}
          Preenchido automaticamente com os dados da sua escola. Ajuste os campos
          abaixo se quiser consultar outro escopo.
        {:else}
          O assistente filtrará automaticamente pelo seu município/escola. Preencha
          os campos abaixo para refinar o escopo.
        {/if}
      </p>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        <label class="block">
          <span class="text-xs font-medium text-blue-900 mb-1 block">Município (código IBGE)</span>
          <input
            type="text"
            bind:value={contexto.cod_municipio}
            placeholder="Ex: 3550308 (São Paulo)"
            class="w-full border border-blue-200 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            maxlength="7"
            pattern="\d{7}"
          />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-blue-900 mb-1">Nome do município</span>
          <input
            type="text"
            bind:value={contexto.nome_municipio}
            placeholder="Ex: São Paulo"
            class="w-full border border-blue-200 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-blue-900 mb-1">Escola (código INEP)</span>
          <input
            type="text"
            bind:value={contexto.cod_inep}
            placeholder="Ex: 12345678"
            class="w-full border border-blue-200 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            maxlength="8"
            pattern="\d{8}"
          />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-blue-900 mb-1">Nome da escola</span>
          <input
            type="text"
            bind:value={contexto.nome_escola}
            placeholder="Ex: EMEF João Silva"
            class="w-full border border-blue-200 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-blue-900 mb-1">UF</span>
          <input
            type="text"
            bind:value={contexto.sg_uf}
            placeholder="SP"
            class="w-full border border-blue-200 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            maxlength="2"
            pattern="[A-Za-z]{2}"
          />
        </label>
      </div>
    </div>
  </header>

  <div class="flex-1 min-h-0 flex flex-col">
    <ChatHistory {messages} {loading} />
    <ChatInput disabled={loading} contexto={contexto} onsend={handleSend} />
  </div>
</div>
