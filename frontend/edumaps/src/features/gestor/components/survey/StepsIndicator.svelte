<!-- src/features/gestor/components/survey/StepsIndicator.svelte -->
<script>
  // Indicador de etapas do wizard (número + rótulo + chevron), leve e sem estado.
  /** @type {{ steps: Array<string>, current: number }} */
  let { steps = [], current = 0 } = $props();

  let currentIndex = $derived(/^\d+/.test(`${current}`) ? Number(current) : 0);

  function stepClass(i) {
    if (i === currentIndex) return "text-blue-700 font-semibold";
    if (i < currentIndex) return "text-gray-500";
    return "text-gray-400";
  }
</script>

<nav aria-label="Etapas da pesquisa">
  <ol class="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs">
    {#each steps as label, i (label)}
      <li class="flex items-center gap-2">
        <span class={stepClass(i)}>
          <span class="mr-1 inline-flex h-5 w-5 items-center justify-center rounded-full bg-gray-100 text-[10px] {i === currentIndex ? 'bg-blue-600 text-white' : ''}">
            {i + 1}
          </span>
          {label}
        </span>
        {#if i < steps.length - 1}
          <span class="text-gray-300" aria-hidden="true">›</span>
        {/if}
      </li>
    {/each}
  </ol>
</nav>