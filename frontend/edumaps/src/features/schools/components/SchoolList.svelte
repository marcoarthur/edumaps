<script>
  // src/features/schools/components/SchoolList.svelte
  import SchoolCard from "./SchoolCard.svelte";

  let { schools = [], loading = false, error = null, hasSearched = false } = $props();
</script>

{#if loading}
  <div class="text-center py-12 text-gray-500">Buscando escolas...</div>
{:else if error}
  <div class="text-center py-12 text-red-600">{error}</div>
{:else if !hasSearched}
  <div class="text-center py-12 text-gray-400">
    Informe um nome de escola ou município para começar.
  </div>
{:else if schools.length === 0}
  <div class="text-center py-12 text-gray-500">Nenhuma escola encontrada.</div>
{:else}
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
    {#each schools as school (school.codigo_inep)}
      <SchoolCard {school} />
    {/each}
  </div>
{/if}
