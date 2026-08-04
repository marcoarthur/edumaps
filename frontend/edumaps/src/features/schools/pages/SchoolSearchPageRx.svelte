<script>
  // src/features/schools/pages/SchoolSearchPageRx.svelte
  import { onMount, onDestroy } from "svelte";
  import SchoolSearchForm from "../components/SchoolSearchForm.svelte";
  import SchoolList from "../components/SchoolReactiveList.svelte";
  import { createSchoolStore } from "../stores/schoolPaginationStore";

  // Instância da store reativa
  const schoolStore = createSchoolStore();

  // Estados reativos com Svelte 5 Runes
  let result = $state({
    data: [],
    meta: null,
    loading: false,
    error: null,
  });
  let hasSearched = $state(false);

  let subscription;

  onMount(() => {
    // Inscreve na store do RxJS
    subscription = schoolStore.result$.subscribe((state) => {
      result = state;
    });
  });

  onDestroy(() => {
    if (subscription && typeof subscription.unsubscribe === 'function') {
      subscription.unsubscribe();
    }
  });

  function handleSearch(filters) {
    hasSearched = true;
    console.log('handleSearch filters:', filters);
    schoolStore.setSearch({
      ...filters,
      page: 1,
    });
  }

  function handleClear() {
    hasSearched = false;
    schoolStore.setSearch({ escola: "", municipio: "", page: 1 });
  }

  function handlePageChange(newPage) {
    schoolStore.goToPage(newPage);
  }

  function handlePerPageChange(newPerPage) {
    schoolStore.setPerPage(newPerPage);
  }
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Busca de Escolas</h1>
    <p class="mt-1 text-sm text-gray-600">Encontre escolas pelo nome ou município.</p>
  </header>

  <SchoolSearchForm
    loading={result.loading}
    onSearch={handleSearch}
    onClear={handleClear}
  />

  <SchoolList
    schools={result.data}
    meta={result.meta}
    loading={result.loading}
    error={result.error}
    {hasSearched}
    onPageChange={handlePageChange}
    onPerPageChange={handlePerPageChange}
  />
</div>
