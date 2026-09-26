<!-- src/features/chat/components/ChatConversaList.svelte -->
<script>
  import ChatConversaItem from "./ChatConversaItem.svelte";
  import { onMount } from "svelte";

  /**
   * @param {Array} conversas
   * @param {boolean} loading
   * @param {string} searchQuery
   * @param {Function} onSearch
   * @param {string} selectedDate
   * @param {Function} onExportSelected
   * @param {Function} onExportAll
   */
  let {
    conversas = [],
    loading = false,
    searchQuery = "",
    onSearch = () => {},
    selectedDate = "",
    onExportSelected = () => {},
    onExportAll = () => {},
  } = $props();

  let selectedIds = $state([]);

  function toggleSelect(id) {
    selectedIds = selectedIds.includes(id) ? selectedIds.filter(i => i !== id) : [...selectedIds, id];
  }

  function selectAll() {
    if (selectedIds.length === conversas.length) {
      selectedIds = [];
    } else {
      selectedIds = conversas.map(c => c.id);
    }
  }

  function handleExportSelected() {
    if (selectedIds.length > 0) onExportSelected(selectedIds);
  }

  function handleExportAll() {
    onExportAll();
  }
</script>

<div class="flex-1 flex flex-col min-h-0">
  <div class="flex flex-col sm:flex-row gap-3 mb-4 p-4 bg-gray-50 rounded-lg border">
    <div class="flex-1">
      <label class="block">
        <span class="sr-only">Buscar conversas</span>
        <input
          type="text"
          bind:value={searchQuery}
          placeholder="Buscar por texto nas conversas..."
          class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          oninput={onSearch}
        />
      </label>
    </div>
    <div class="flex items-center gap-2 flex-wrap">
      <button
        onclick={() => {}}
        class="px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 transition-colors"
        disabled={conversas.length === 0}
      >
        Exportar todas (.md)
      </button>
      <button
        onclick={() => {}}
        class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 transition-colors"
        disabled={conversas.length === 0}
      >
        Exportar selecionadas ({selectedIds.length})
      </button>
    </div>
  </div>

  <div class="flex-1 overflow-y-auto">
    {#if loading}
      <div class="flex justify-center py-8">
        <div class="flex items-center gap-2 text-sm text-gray-500">
          <svg class="animate-spin h-5 w-5 text-blue-600" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          <span>Carregando conversas...</span>
        </div>
      </div>
    {:else if conversas.length === 0}
      <div class="text-center py-12 text-gray-500 text-sm">
        Nenhuma conversa encontrada.
      </div>
    {:else}
      <div class="space-y-3 p-4">
        {#each conversas as conversa}
          <ChatConversaItem
            {conversa}
            selected={false}
            onClick={() => {}}
            onExport={(id) => {}}
            onDelete={(id) => {}}
          />
        {/each}
      </div>
    {/if}
  </div>
</div>