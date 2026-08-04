<script>
  let {
    items = [],
    meta = null,
    loading = false,
    error = null,
    hasSearched = false,
    perPageOptions = [5, 10, 20, 50],
    onPageChange = () => {},
    onPerPageChange = () => {},
    id = 'pageable-list',
    children,
    loadingSnippet,
    emptySnippet,
    errorSnippet,
  } = $props();
</script>

<div class="flex flex-col gap-4">
  {#if loading}
    {#if loadingSnippet}
      {@render loadingSnippet?.()}
    {:else}
      <div class="p-4 text-center text-gray-500">Carregando...</div>
    {/if}
  {:else if error}
    {#if errorSnippet}
      {@render errorSnippet?.({ error })}
    {:else}
      <div class="rounded-md bg-red-100 p-4 text-center text-red-600">
        {typeof error === 'object' ? error?.message : error}
      </div>
    {/if}
  {:else if !hasSearched || items.length === 0}
    {#if emptySnippet}
      {@render emptySnippet?.()}
    {:else}
      <div class="p-4 text-center text-gray-500">
        {!hasSearched ? 'Realize uma busca para ver resultados.' : 'Nenhum item encontrado.'}
      </div>
    {/if}
  {:else}
    <div class="flex flex-col gap-2">
      {#each items as item, index (item.id ?? item.codigo_inep ?? index)}
        {@render children?.({ item, index })}
      {/each}
    </div>

    <!-- ✅ Corrigido: usar total_pages em vez de last_page -->
    {#if meta && meta.total_pages > 1}
      <div class="flex flex-wrap items-center justify-between gap-2 border-t border-gray-200 pt-3">
        <div class="flex items-center gap-2">
          <button
            class="rounded-md border border-gray-300 bg-white px-3 py-1 text-sm font-medium transition-colors hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
            disabled={meta.current_page <= 1}
            onclick={() => onPageChange(meta.current_page - 1)}
          >
            Anterior
          </button>
          <span class="text-sm text-gray-700">
            Página {meta.current_page} de {meta.total_pages}
          </span>
          <button
            class="rounded-md border border-gray-300 bg-white px-3 py-1 text-sm font-medium transition-colors hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-50"
            disabled={meta.current_page >= meta.total_pages}
            onclick={() => onPageChange(meta.current_page + 1)}
          >
            Próxima
          </button>
        </div>

        <div class="flex items-center gap-2 text-sm text-gray-700">
          <label for="{id}-per-page">Itens por página:</label>
          <select
            id="{id}-per-page"
            class="rounded-md border border-gray-300 bg-white p-1 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
            value={meta.per_page}
            onchange={(e) => onPerPageChange(Number(e.target.value))}
          >
            {#each perPageOptions as opt}
              <option value={opt}>{opt}</option>
            {/each}
          </select>
        </div>
      </div>
    {/if}
  {/if}
</div>
