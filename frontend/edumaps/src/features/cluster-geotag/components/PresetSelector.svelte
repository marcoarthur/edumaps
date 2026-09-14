<script>
  // src/features/cluster-geotag/components/PresetSelector.svelte
  let {
    presets = [],
    value = $bindable(null),
    onchange = () => {},
    disabled = false,
  } = $props();

  function pick(id) {
    value = id;
    onchange(id);
  }
</script>

<div class="grid grid-cols-1 md:grid-cols-3 gap-3">
  {#each presets as p (p.id)}
    <button
      type="button"
      aria-pressed={value === p.id}
      disabled={disabled}
      onclick={() => pick(p.id)}
      class="text-left border rounded-md px-3 py-2 transition-colors disabled:opacity-60
        {value === p.id
          ? 'border-blue-600 bg-blue-50 ring-1 ring-blue-600'
          : 'border-gray-200 bg-white hover:bg-gray-50'}"
    >
      <span class="block text-sm font-semibold text-gray-800">{p.name}</span>
      <span class="block text-xs text-gray-500 mt-0.5 leading-relaxed">
        {p.description}
      </span>
      {#if p.year_filter}
        <span class="inline-block mt-1.5 text-[10px] font-medium text-sky-700 bg-sky-50 rounded-full px-2 py-0.5">
          exige escolha do ano
        </span>
      {/if}
    </button>
  {/each}
</div>