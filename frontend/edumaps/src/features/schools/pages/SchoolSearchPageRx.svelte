<script>
  // src/features/schools/pages/SchoolSearchPageRx.svelte
  import { tap } from "rxjs/operators";
  import SchoolSearchForm from "../components/SchoolSearchForm.svelte";
  import SchoolList from "../components/SchoolReactiveList.svelte";
  import { createSchoolStore } from "../stores/schoolPaginationStore";
  import { eventBus, EVENTS } from "@/shared/events";
  import { SCHOOL_EVENTS } from "../constants/events.js";

  const schoolStore = createSchoolStore();

  let result = $state({
    data: [],
    meta: null,
    loading: false,
    error: null,
  });
  let hasSearched = $state(false);

  $effect(() => {
    let previousLoading = false;

    const subscription = schoolStore.result$
      .pipe(
        tap((state) => {
          // Detecta transição loading → não-loading
          const wasLoading = previousLoading && !state.loading;
          previousLoading = state.loading;
          result = state;

          if (wasLoading) {
            notifySearchOutcome(state);
          }
        })
      )
      .subscribe();

    return () => subscription.unsubscribe();
  });

  function notifySearchOutcome(state) {
    if (state.error) {
      eventBus.emit(EVENTS.TOAST_ADD, { message: state.error, type: "error", duration: 5000 });
      return;
    }
    if (state.meta?.total_entries === undefined) {
      console.log('⏳ meta.total_entries ainda não definido, ignorando');
      return;
    }

    const total = state.meta.total_entries;
    const message =
      total === 0
        ? "Nenhuma escola encontrada."
        : `Busca concluída: ${total} ${total === 1 ? "escola encontrada" : "escolas encontradas"}`;
    eventBus.emit(EVENTS.TOAST_ADD, { message, type: "info", duration: 3000 });
  }

  function handleSearch(filters) {
    hasSearched = true;
    schoolStore.setSearch({ ...filters, page: 1 });
  }

  function handleClear() {
    hasSearched = false;
    schoolStore.setSearch({ escola: "", municipio: "", page: 1 });
  }

  function handlePageChange(newPage) {
    schoolStore.goToPage(newPage);
    eventBus.emit(SCHOOL_EVENTS.PAGE_CHANGE, { page: newPage }, { source: "SchoolSearchPageRx" });
  }

  function handlePerPageChange(newPerPage) {
    schoolStore.setPerPage(newPerPage);
    eventBus.emit(
      SCHOOL_EVENTS.PER_PAGE_CHANGE,
      { perPage: newPerPage },
      { source: "SchoolSearchPageRx" }
    );
  }
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Busca de Escolas</h1>
    <p class="mt-1 text-sm text-gray-600">Encontre escolas pelo nome ou município.</p>
  </header>

  <SchoolSearchForm loading={result.loading} onSearch={handleSearch} onClear={handleClear} />

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
