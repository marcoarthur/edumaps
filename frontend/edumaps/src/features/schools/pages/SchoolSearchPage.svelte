<script>
  // src/features/schools/pages/SchoolSearchPage.svelte
  import SchoolSearchForm from "../components/SchoolSearchForm.svelte";
  import SchoolList from "../components/SchoolList.svelte";
  import { searchSchools } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";

  let schools = $state([]);
  let loading = $state(false);
  let error = $state(null);
  let hasSearched = $state(false);

  async function handleSearch({ escola, municipio }) {
    loading = true;
    error = null;
    hasSearched = true;
    try {
      schools = await searchSchools({ escola, municipio });
    } catch (err) {
      schools = [];
      error = err instanceof ApiError ? err.message : "Erro inesperado ao buscar escolas.";
    } finally {
      loading = false;
    }
  }

  function handleClear() {
    schools = [];
    error = null;
    hasSearched = false;
  }
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Busca de Escolas</h1>
    <p class="text-gray-600 text-sm mt-1">Encontre escolas pelo nome ou município.</p>
  </header>

  <SchoolSearchForm {loading} onSearch={handleSearch} onClear={handleClear} />
  <SchoolList {schools} {loading} {error} {hasSearched} />
</div>
