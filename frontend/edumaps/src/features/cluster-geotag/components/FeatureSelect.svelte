<script>
  // src/features/cluster-geotag/components/FeatureSelect.svelte
  import {
    featureLabel,
    SOURCE_LABELS,
    SOURCE_TAG_COLORS,
  } from "../constants/cluster.js";

  let {
    columns = [],
    value = $bindable([]),
    placeholder = "Buscar indicador…",
    disabled = false,
  } = $props();

  let query = $state("");
  let open = $state(false);

  // Somente as colunas ainda não selecionadas entram no autocomplete.
  const available = $derived(
    columns.filter((col) => !value.includes(col.column_name)),
  );

  const filtered = $derived(() => {
    const q = query.trim().toLowerCase();
    const base = q
      ? available.filter((col) => {
          const name = col.column_name.toLowerCase();
          const comment = (col.comment || "").toLowerCase();
          return name.includes(q) || comment.includes(q);
        })
      : available;
    return base.slice(0, 30);
  });

  function select(col) {
    if (!value.includes(col.column_name)) {
      value = [...value, col.column_name];
    }
    query = "";
    open = false;
  }

  function remove(name) {
    value = value.filter((f) => f !== name);
  }

  function toggleOpen() {
    if (!disabled) open = !open;
  }

  function featureFor(name) {
    return columns.find((c) => c.column_name === name);
  }
</script>

<div class="bg-gray-50 border border-gray-200 rounded-md p-3">
  <div class="flex flex-wrap gap-1.5 mb-2">
    {#if value.length === 0}
      <span class="text-xs text-gray-400">
        Nenhum indicador selecionado — adicione ao menos um.
      </span>
    {:else}
      {#each value as name}
        {#if featureFor(name)}
          <span
            class="inline-flex items-center gap-1.5 text-xs font-medium bg-white border border-gray-200 rounded-full px-2 py-1 select-none"
          >
            <span>{featureLabel(featureFor(name))}</span>
            <code class="hidden text-[10px] text-gray-400">{name}</code>
            {#if !disabled}
              <button
                type="button"
                onclick={() => remove(name)}
                aria-label={`Remover ${name}`}
                class="text-gray-400 hover:text-red-600 font-bold leading-none"
              >
                ×
              </button>
            {/if}
          </span>
        {/if}
      {/each}
      <span class="self-center ml-auto text-[11px] text-gray-400">
        {value.length} selecionado(s)
      </span>
    {/if}
  </div>

  <div class="relative">
    <input
      type="text"
      bind:value={query}
      placeholder={placeholder}
      aria-label="Buscar indicador"
      disabled={disabled}
      onfocus={toggleOpen}
      oninput={() => (open = true)}
      onblur={() => (open = false)}
      class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
    />

    {#if open && filtered.length > 0 && !disabled}
      <ul
        class="absolute z-20 mt-1 w-full max-h-72 overflow-y-auto bg-white border border-gray-200 rounded-md shadow-lg"
      >
        {#each filtered as col}
          <li>
            <button
              type="button"
              role="option"
              aria-selected="false"
              onclick={() => select(col)}
              class="w-full text-left px-3 py-2 hover:bg-blue-50 transition-colors"
            >
              <div class="flex items-center justify-between gap-2">
                <span class="text-sm text-gray-800">
                  {featureLabel(col)}
                </span>
                <span class="shrink-0">
                  <span
                    class="text-[10px] px-1.5 py-0.5 rounded-full bg-gray-100 text-gray-500"
                  >
                    {SOURCE_LABELS[col.table_name] ?? col.table_name}
                  </span>
                </span>
              </div>
              <code class="block text-[11px] text-gray-400 mt-0.5">
                {col.column_name}
              </code>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
</div>