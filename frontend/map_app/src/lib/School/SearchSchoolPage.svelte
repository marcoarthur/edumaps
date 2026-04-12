<script>
  import SearchForm from './SearchForm.svelte';
  import SchList from './SchList.svelte';
  import PayrollModal from './PayrollModal.svelte';
  import GradesModal from './GradesModal.svelte';
  
  let escolas = [];
  let loading = false;
  let error = null;
  let buscaRealizada = false;
  let showPayrollModal = false;
  let showGradesModal = false;
  let selectedEscola = null;

  function openGradesModal(school) {
    selectedEscola = school;
    showGradesModal = true;
  }

  function closeGradesModal() {
    showGradesModal = false;
    selectedEscola = null;
  }

  async function handleSearch(event) {
    const { nome, cidade } = event.detail;
    
    loading = true;
    error = null;
    escolas = [];
    buscaRealizada = true;

    try {
      let url = '/api/school/search';
      
      if (nome && nome.trim()) {
        url += `/${encodeURIComponent(nome)}`;
      }
      
      if (cidade && cidade.trim()) {
        const cidadeParam = encodeURIComponent(cidade.trim());
        if (url.includes('?')) {
          url += `&cidade=${cidadeParam}`;
        } else {
          url += `?cidade=${cidadeParam}`;
        }
      }
      
      console.log('URL final:', url);
      
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`Erro na busca: ${response.status}`);
      }
      
      const data = await response.json();
      escolas = data;
      
      if (escolas.length === 0) {
        error = 'Nenhuma escola encontrada com os critérios informados';
      }
    } catch (err) {
      error = err.message;
      console.error('Erro ao buscar escolas:', err);
    } finally {
      loading = false;
    }
  }

  function handleError(event) {
    error = event.detail.message;
  }

  function handleClear() {
    escolas = [];
    error = null;
    buscaRealizada = false;
  }

  function handleViewPayroll(event) {
    console.log('Evento viewPayroll recebido:', event.detail);
    selectedEscola = event.detail.escola;
    showPayrollModal = true;
  }

  function handleViewGrades(event) {
    console.log('Evento viewGrades recebido:', event.detail);
    selectedEscola = event.detail.escola;
    showGradesModal = true;
  }
</script>

<div class="busca-escolas-page">
  <div class="page-header">
    <h1>🔍 Busca de Escolas</h1>
    <p>Encontre escolas pelo nome ou cidade</p>
  </div>

  <SearchForm 
    on:search={handleSearch}
    on:error={handleError}
    on:clear={handleClear}
    {loading}
  />

  <div class="results-section">
    {#if buscaRealizada}
      <SchList 
        escolas={escolas}
        loading={loading}
        error={error}
        on:viewPayroll={handleViewPayroll}
        on:viewGrades={handleViewGrades}
      />
    {/if}
  </div>
</div>

<!-- Modal de Payroll -->
<PayrollModal 
  bind:show={showPayrollModal}
  escola={selectedEscola}
  on:close={() => {
    showPayrollModal = false;
    selectedEscola = null;
  }}
/>

<GradesModal
  school={selectedEscola}
  bind:isOpen={showGradesModal}
  on:close={closeGradesModal}
/>

<style>
  .busca-escolas-page {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }

  .page-header {
    text-align: center;
    margin-bottom: 2rem;
  }

  .page-header h1 {
    font-size: 2rem;
    font-weight: bold;
    color: #1f2937;
    margin-bottom: 0.5rem;
  }

  .page-header p {
    color: #6b7280;
  }

  .results-section {
    margin-top: 2rem;
  }
</style>
