<!-- src/features/chat/components/ChatHistory.svelte -->
<script>
  import ChatMessage from "./ChatMessage.svelte";

  /**
   * @param {Array<{id: string, role: string, content: string, meta?: object}>} [messages]
   * @param {boolean} [loading]
   * @param {string} [emptyMessage]
   */
  let {
    messages = [],
    loading = false,
    emptyMessage = "Nenhuma mensagem ainda. Envie sua primeira pergunta!",
  } = $props();
</script>

<div class="flex-1 overflow-y-auto space-y-4 p-4" id="chat-history" role="log" aria-live="polite">
  {#if messages.length === 0 && !loading}
    <div class="text-center py-12 text-gray-500 text-sm">
      {emptyMessage}
    </div>
  {:else}
    <div class="space-y-4">
      {#each messages as msg (msg.id)}
        <ChatMessage {...msg} />
      {/each}
    </div>
  {/if}

  {#if loading}
    <div class="flex justify-center py-4">
      <div class="flex items-center gap-2 text-sm text-gray-500">
        <svg class="animate-spin h-5 w-5 text-blue-600" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"/>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
        </svg>
        <span>Consultando o assistente...</span>
      </div>
    </div>
  {/if}
</div>
