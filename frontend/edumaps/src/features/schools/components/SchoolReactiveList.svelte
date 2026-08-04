<script>
  // src/features/schools/components/SchoolReactiveList.svelte
  import PageableList from "@/shared/ui/components/PageableList.svelte";
  import SchoolCard from "./SchoolCard.svelte";

  let {
    schools = [],
    meta = null,
    loading = false,
    error = null,
    hasSearched = false,
    perPageOptions = [5, 10, 20, 50],
    onPageChange = () => {},
    onPerPageChange = () => {},
  } = $props();
</script>

<PageableList
  items={schools}
  {meta}
  {loading}
  {error}
  {hasSearched}
  {perPageOptions}
  {onPageChange}
  {onPerPageChange}
>
  {#snippet children({ item: school })}
    <SchoolCard {school} />
  {/snippet}

  {#snippet loadingSnippet()}
    <div class="py-12 text-center text-gray-500">Buscando escolas...</div>
  {/snippet}

  {#snippet emptySnippet()}
    {#if !hasSearched}
      <div class="py-12 text-center text-gray-400">
        Informe um nome de escola ou município para começar.
      </div>
    {:else}
      <div class="py-12 text-center text-gray-500">Nenhuma escola encontrada.</div>
    {/if}
  {/snippet}

  {#snippet errorSnippet({ error: err })}
    <div class="py-12 text-center text-red-600">
      {typeof err === 'object' ? err?.message : err}
    </div>
  {/snippet}
</PageableList>
