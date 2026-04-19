<script>
  import SearchForm from './SearchForm.svelte';
  import SchList from './SchList.svelte';
  import PayrollModal from './PayrollModal.svelte';
  import GradesModal from './GradesModal.svelte';
  
  let escolas = [];           // resultados originais da API
  let loading = false;
  let error = null;
  let buscaRealizada = false;
  let showPayrollModal = false;
  let showGradesModal = false;
  let selectedEscola = null;

  // --- Filtros ---
  let filtroTipo = 'todos';      // 'todos' ou um valor específico (ex: 'Municipal')
  let filtroCidade = 'todas';    // 'todas' ou um valor específico (ex: 'São Paulo - SP')
  let opcoesTipos = [];          // ex: ['Municipal', 'Estadual', 'Privada', 'Federal']
  let opcoesCidades = [];        // ex: ['São Paulo - SP', 'Rio de Janeiro - RJ']

  // --- Lista filtrada (reativa) ---
  $: listaFiltrada = aplicarFiltros(escolas, filtroTipo, filtroCidade);

  // Função que aplica os filtros sobre a lista original
  function aplicarFiltros(lista, tipo, cidade) {
    if (!lista || lista.length === 0) return [];
    
    return lista.filter(escola => {
      // Filtro por tipo 
      if (tipo !== 'todos' && escola.tipo !== tipo) {
        return false;
      }
      
      // Filtro por cidade/estado (combinação "municipio - UF")
      if (cidade !== 'todas') {
        const cidadeEstado = `${escola.municipio} - ${escola.uf}`;
        if (cidadeEstado !== cidade) {
          return false;
        }
      }
      
      return true;
    });
  }

  // Extrai os valores únicos de tipo e cidade/estado a partir dos resultados da busca
  function atualizarOpcoesFiltro(resultados) {
    if (!resultados || resultados.length === 0) {
      opcoesTipos = [];
      opcoesCidades = [];
      return;
    }
    
    // Tipos únicos
    const tiposSet = new Set();
    resultados.forEach(escola => {
      if (escola.tipo) {
        tiposSet.add(escola.tipo);
      }
    });
    opcoesTipos = Array.from(tiposSet).sort();
    
    // Cidades/Estados únicos (formato "municipio - UF")
    const cidadesSet = new Set();
    resultados.forEach(escola => {
      if (escola.municipio && escola.uf) {
        cidadesSet.add(`${escola.municipio} - ${escola.uf}`);
      }
    });
    opcoesCidades = Array.from(cidadesSet).sort();
  }

  // Reseta os filtros para "todos"/"todas"
  function resetarFiltros() {
    filtroTipo = 'todos';
    filtroCidade = 'todas';
  }

  // Limpa a busca atual e reseta os filtros
  function handleClear() {
    escolas = [];
    error = null;
    buscaRealizada = false;
    resetarFiltros();
    opcoesTipos = [];
    opcoesCidades = [];
  }

  // Busca de escolas (já existente)
  async function handleSearch(event) {
    const { nome, cidade } = event.detail;
    
    loading = true;
    error = null;
    escolas = [];
    buscaRealizada = true;
    resetarFiltros();  // toda nova busca reinicia os filtros

    try {
      let url = '/api/school/search';
      if (nome && nome.trim()) {
        url += `/${encodeURIComponent(nome)}`;
      }
      if (cidade && cidade.trim()) {
        const cidadeParam = encodeURIComponent(cidade.trim());
        url += (url.includes('?') ? `&cidade=${cidadeParam}` : `?cidade=${cidadeParam}`);
      }
      
      const response = await fetch(url);
      if (!response.ok) throw new Error(`Erro na busca: ${response.status}`);
      
      const data = await response.json();
      escolas = data;
      
      // Após obter os resultados, atualiza as opções dos filtros
      atualizarOpcoesFiltro(escolas);
      
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

  function openGradesModal(school) {
    selectedEscola = school;
    showGradesModal = true;
  }

  function closeGradesModal() {
    showGradesModal = false;
    selectedEscola = null;
  }

  function handleViewPayroll(event) {
    selectedEscola = event.detail.escola;
    showPayrollModal = true;
  }

  function handleViewGrades(event) {
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

  {#if buscaRealizada}
    <!-- Barra de filtros (exibida somente se houver resultados) -->
    {#if escolas.length > 0}
      <div class="filtros-bar">
        <div class="filtro-group">
          <label>🏫 Tipo de escola:</label>
          <select bind:value={filtroTipo}>
            <option value="todos">Todos</option>
            {#each opcoesTipos as tipo}
              <option value={tipo}>{tipo}</option>
            {/each}
          </select>
        </div>

        <div class="filtro-group">
          <label>📍 Cidade / Estado:</label>
          <select bind:value={filtroCidade}>
            <option value="todas">Todas</option>
            {#each opcoesCidades as cidade}
              <option value={cidade}>{cidade}</option>
            {/each}
          </select>
        </div>

        <!-- Exibe contagem de resultados filtrados -->
        <div class="contagem">
          Exibindo <strong>{listaFiltrada.length}</strong> de {escolas.length} escola(s)
        </div>
      </div>
    {/if}

    <div class="results-section">
      <SchList 
        escolas={listaFiltrada}
        loading={loading}
        error={error}
        on:viewPayroll={handleViewPayroll}
        on:viewGrades={handleViewGrades}
      />
    </div>
  {/if}
</div>

<!-- Modais -->
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
  
  /* Estilos dos filtros */
  .filtros-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 1.5rem;
    align-items: flex-end;
    background: #f9fafb;
    padding: 1rem 1.5rem;
    border-radius: 12px;
    margin-top: 1rem;
    margin-bottom: 1rem;
    border: 1px solid #e5e7eb;
  }
  .filtro-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .filtro-group label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #4b5563;
  }
  .filtro-group select {
    padding: 0.5rem 2rem 0.5rem 0.75rem;
    border-radius: 8px;
    border: 1px solid #d1d5db;
    background-color: white;
    font-size: 0.875rem;
    cursor: pointer;
  }
  .contagem {
    margin-left: auto;
    font-size: 0.875rem;
    color: #6b7280;
    background: white;
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    border: 1px solid #e5e7eb;
  }
</style>
