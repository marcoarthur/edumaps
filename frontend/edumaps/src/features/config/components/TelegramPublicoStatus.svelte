<!-- src/features/config/components/TelegramPublicoStatus.svelte -->
<!--
  Painel "Status do bot público" (grupo Telegram (bot público) do Painel de
  Configuração). Mostra o estado do bot (ativado, modo de recebimento, usuário)
  e os dados do webhook ou do polling, com as ações do modo vigente:
  webhook → Registrar/Remover webhook; polling → Iniciar polling.
  Após cada ação o status é recarregado; os botões ficam desabilitados
  durante a requisição.
-->
<script>
  import { onMount } from "svelte";
  import {
    getTelegramStatus,
    registrarTelegramWebhook,
    removerTelegramWebhook,
    iniciarTelegramPolling,
  } from "../api/configApi.js";

  let status = $state(null);
  let carregando = $state(true);
  let erroStatus = $state(null);
  let ocupado = $state(false);
  let mensagem = $state(null); // { tipo: "ok" | "erro", texto }

  const modo = $derived(status?.recebimento ?? null);

  function textoErro(err, acao) {
    const detalhe = err?.message ?? "erro desconhecido";
    if (err?.status === 502) return `O Telegram recusou ${acao}: ${detalhe}`;
    if (err?.status === 409) return `Não foi possível ${acao}: ${detalhe}`;
    return `Falha ao ${acao}: ${detalhe}`;
  }

  async function carregarStatus() {
    erroStatus = null;
    try {
      status = await getTelegramStatus();
    } catch (err) {
      erroStatus = err?.message ?? "Não foi possível carregar o status do bot.";
    } finally {
      carregando = false;
    }
  }

  async function executar(fn, acao, sucesso) {
    ocupado = true;
    mensagem = null;
    try {
      const res = await fn();
      mensagem = { tipo: "ok", texto: sucesso(res) };
    } catch (err) {
      mensagem = { tipo: "erro", texto: textoErro(err, acao) };
    } finally {
      await carregarStatus();
      ocupado = false;
    }
  }

  const registrar = () =>
    executar(registrarTelegramWebhook, "registrar o webhook", (r) =>
      r?.url ? `Webhook registrado em ${r.url}.` : "Webhook registrado.",
    );

  const remover = () => executar(removerTelegramWebhook, "remover o webhook", () => "Webhook removido.");

  const iniciar = () =>
    executar(iniciarTelegramPolling, "iniciar o polling", (r) =>
      r?.ja_ativo ? "O polling já está ativo." : `Polling iniciado (job ${r?.job_id ?? "?"}).`,
    );

  onMount(carregarStatus);
</script>

<section class="mt-6 pt-4 border-t border-gray-100" aria-labelledby="tg-publico-status">
  <div class="flex items-center justify-between gap-2">
    <h3 id="tg-publico-status" class="font-semibold text-gray-800">Status do bot público</h3>
    <button
      type="button"
      onclick={carregarStatus}
      disabled={ocupado}
      class="text-xs text-indigo-700 hover:underline disabled:opacity-40"
    >
      Atualizar status
    </button>
  </div>

  {#if carregando}
    <p class="text-sm text-gray-500 mt-2">Carregando status do bot…</p>
  {:else if erroStatus && !status}
    <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
  {:else if status}
    <dl class="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
      <dt class="text-gray-500">Bot</dt>
      <dd class="text-gray-800" data-testid="tg-enabled">{status.enabled ? "ativado" : "desativado"}</dd>
      <dt class="text-gray-500">Recebimento</dt>
      <dd class="text-gray-800" data-testid="tg-recebimento">{modo ?? "—"}</dd>
      <dt class="text-gray-500">Usuário</dt>
      <dd class="text-gray-800" data-testid="tg-username">
        {status.bot_username ? `@${status.bot_username}` : "—"}
      </dd>

      {#if modo === "webhook"}
        <dt class="text-gray-500">URL do webhook</dt>
        <dd class="text-gray-800 break-all" data-testid="tg-webhook-url">
          {status.webhook?.url || "não registrado"}
        </dd>
        <dt class="text-gray-500">Pendentes</dt>
        <dd class="text-gray-800" data-testid="tg-webhook-pendentes">
          {status.webhook?.pending_update_count ?? "—"}
        </dd>
        <dt class="text-gray-500">Último erro</dt>
        <dd class="text-gray-800" data-testid="tg-webhook-erro">
          {status.webhook?.last_error_message || "nenhum"}
        </dd>
      {:else if modo === "polling"}
        <dt class="text-gray-500">Polling</dt>
        <dd class="text-gray-800" data-testid="tg-polling-ativo">{status.polling?.ativo ? "ativo" : "parado"}</dd>
        <dt class="text-gray-500">Offset</dt>
        <dd class="text-gray-800" data-testid="tg-polling-offset">{status.polling?.offset ?? "—"}</dd>
      {/if}
    </dl>

    {#if erroStatus}
      <p class="text-sm text-red-600 mt-2" role="alert">{erroStatus}</p>
    {/if}

    <div class="flex flex-wrap items-center gap-2 mt-3">
      {#if modo === "webhook"}
        <button
          type="button"
          onclick={registrar}
          disabled={ocupado}
          class="px-3 h-9 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-40"
        >
          Registrar webhook
        </button>
        <button
          type="button"
          onclick={remover}
          disabled={ocupado}
          class="px-3 h-9 rounded-md border border-gray-300 text-gray-700 text-sm font-medium hover:bg-gray-50 disabled:opacity-40"
        >
          Remover webhook
        </button>
      {:else if modo === "polling"}
        <button
          type="button"
          onclick={iniciar}
          disabled={ocupado}
          class="px-3 h-9 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-40"
        >
          Iniciar polling
        </button>
      {:else}
        <p class="text-xs text-gray-500">Defina o modo de recebimento para habilitar as ações.</p>
      {/if}
    </div>

    {#if mensagem}
      <p
        class="text-sm mt-2 {mensagem.tipo === 'erro' ? 'text-red-600' : 'text-green-700'}"
        role={mensagem.tipo === "erro" ? "alert" : "status"}
        data-testid="tg-mensagem"
      >
        {mensagem.texto}
      </p>
    {/if}
  {/if}
</section>
