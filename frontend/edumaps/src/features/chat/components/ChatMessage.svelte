<!-- src/features/chat/components/ChatMessage.svelte -->
<script>
  /**
   * @param {'user'|'assistant'} role
   * @param {string} content
   * @param {{ sql?: string, resultado?: object, origem?: string[], linhas?: number, colunas?: number, chart?: object, timestamp?: string }} [meta]
   */
  let { role, content, meta = {} } = $props();

  const isUser = $derived(role === "user");

  const hora = $derived.by(() => {
    if (!meta.timestamp) return "";
    const d = new Date(meta.timestamp);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleTimeString("pt-BR", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  });
</script>

<div class="flex gap-3 mb-4 {isUser ? 'flex-row-reverse' : ''}">
  <div class="flex items-center gap-2 w-10 shrink-0" aria-hidden="true">
    <div
      class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium text-white
        {isUser ? 'bg-blue-600' : 'bg-emerald-600'}"
    >
      {isUser ? 'U' : 'A'}
    </div>
  </div>

  <div
    class="max-w-[70%] rounded-2xl px-4 py-3
      {isUser
        ? 'bg-blue-600 text-white rounded-br-none shadow-sm'
        : 'bg-gray-100 text-gray-900 rounded-bl-none shadow-sm'}"
  >
    <div class="text-sm whitespace-pre-wrap break-words">
      {content}
    </div>

    {#if meta.sql}
      <details class="mt-3 text-xs">
        <summary class="cursor-pointer opacity-70 hover:opacity-100">
          Ver SQL executado
        </summary>
        <pre class="mt-2 p-2 bg-gray-800 text-green-300 rounded overflow-x-auto whitespace-pre-wrap">{meta.sql}</pre>
      </details>
    {/if}

    {#if meta.resultado}
      <details class="mt-3 text-xs">
        <summary class="cursor-pointer opacity-70 hover:opacity-100">
          Ver resultado ({meta.linhas ?? 0} linha{meta.linhas === 1 ? '' : 's'})
        </summary>
        <pre class="mt-2 p-2 bg-gray-800 text-green-300 rounded overflow-x-auto whitespace-pre-wrap text-xs">{JSON.stringify(meta.resultado, null, 2)}</pre>
      </details>
    {/if}

    {#if meta.origem && meta.origem.length}
      <div class="mt-2 text-xs opacity-60">
        Tabelas: {meta.origem.join(", ")}
      </div>
    {/if}

    {#if hora}
      <div class="mt-2 text-[10px] opacity-50">{hora}</div>
    {/if}
  </div>
</div>
