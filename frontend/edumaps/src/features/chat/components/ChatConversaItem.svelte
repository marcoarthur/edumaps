<!-- src/features/chat/components/ChatConversaItem.svelte -->
<script>
  /**
   * @param {Object} conversa
   * @param {number} conversa.id
   * @param {string} conversa.titulo
   * @param {string} conversa.created_at
   * @param {string} conversa.updated_at
   * @param {number} conversa.msg_count
   * @param {string} [conversa.snippet]
   * @param {boolean} selected
   * @param {Function} onClick
   * @param {Function} onExport
   * @param {Function} onDelete
   */
  let { conversa, selected = false, onClick, onExport, onDelete } = $props();

  function formatDate(iso) {
    const d = new Date(iso);
    return d.toLocaleDateString("pt-BR", { day: "2-digit", month: "2-digit", year: "numeric" }) +
      " " + d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
  }
</script>

<article class="group relative bg-white border border-gray-200 rounded-lg p-4 hover:border-blue-300 hover:shadow-md transition-all {selected ? 'ring-2 ring-blue-500 bg-blue-50' : ''}">
  <div class="flex items-start justify-between gap-4">
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2 mb-1">
        <h4 class="font-medium text-gray-900 truncate">{conversa.titulo || "Sem título"}</h4>
        <span class="text-xs text-gray-500 whitespace-nowrap">{conversa.msg_count} msg</span>
      </div>
      <p class="text-sm text-gray-600 mb-2">Criada em {formatDate(conversa.created_at)}</p>
      {#if snippet}
        <p class="text-sm text-gray-500 line-clamp-2 bg-gray-50 p-2 rounded">{snippet}</p>
      {/if}
    </div>

    <div class="flex items-center gap-2 flex-shrink-0">
      <button
        onclick={(e) => { e.stopPropagation(); onExport(conversa.id); }}
        class="p-2 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-md transition-colors"
        aria-label="Exportar conversa"
        title="Exportar .md"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path>
        </svg>
      </button>
      <button
        onclick={(e) => { e.stopPropagation(); onDelete(conversa.id); }}
        class="p-2 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors"
        aria-label="Excluir conversa"
        title="Excluir"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v12M10 3h4a1 1 0 011 1v1H7V4a1 1 0 011-1h4zm-6 0v1h12V3H7z"></path>
        </svg>
      </button>
    </div>
  </div>

  <button
    onclick={(e) => { e.stopPropagation(); onClick(); }}
    class="absolute inset-0 w-full h-full focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
    aria-label="Ver conversa"
  ></button>
</article>