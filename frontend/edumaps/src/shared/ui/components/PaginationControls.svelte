<script>
  // src/shared/ui/components/PaginationControls.svelte
  export let pagination = { current_page: 1, total_pages: 1, per_page: 10 };
  export let perPageOptions = [5, 10, 20, 50];
  export let onPageChange = () => {};
  export let onPerPageChange = () => {};
</script>

<div class="mt-4 flex flex-wrap items-center justify-between border-t border-gray-200 pt-3 text-sm text-gray-700">
  <div class="flex items-center gap-2">
    <button
      class="rounded border border-gray-300 bg-white px-3 py-1 font-medium transition-colors hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
      disabled={pagination.current_page <= 1}
      on:click={() => onPageChange(pagination.current_page - 1)}
    >
      Anterior
    </button>

    <span>Página {pagination.current_page} de {pagination.total_pages}</span>

    <button
      class="rounded border border-gray-300 bg-white px-3 py-1 font-medium transition-colors hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
      disabled={pagination.current_page >= pagination.total_pages}
      on:click={() => onPageChange(pagination.current_page + 1)}
    >
      Próxima
    </button>
  </div>

  <div class="mt-2 sm:mt-0">
    <label class="flex items-center gap-1">
      Itens por página:
      <select
        class="rounded border border-gray-300 bg-white p-1 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        value={pagination.per_page}
        on:change={(e) => onPerPageChange(Number(e.target.value))}
      >
        {#each perPageOptions as opt}
          <option value={opt}>{opt}</option>
        {/each}
      </select>
    </label>
  </div>
</div>
