<script>
  import { createEventDispatcher } from 'svelte';
  
  export let escolas = [];
  export let loading = false;
  export let error = null;
  
  // Paginação
  export let pageSize = 20;        // itens por página
  export let currentPage = 1;      // página atual (1-indexed)

  const dispatch = createEventDispatcher();

  // Total de páginas
  $: totalPages = Math.ceil(escolas.length / pageSize);
  
  // Garantir que currentPage esteja dentro dos limites
  $: {
    if (currentPage > totalPages && totalPages > 0) {
      currentPage = totalPages;
    }
    if (currentPage < 1 && escolas.length > 0) {
      currentPage = 1;
    }
  }
  
  // Escolas da página atual (fatia do array)
  $: paginatedEscolas = escolas.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  
  // Funções de navegação
  function goToPage(page) {
    if (page >= 1 && page <= totalPages) {
      currentPage = page;
      // Disparar evento para que o componente pai possa, se quiser, fazer server-side pagination
      dispatch('pageChange', { page, pageSize });
    }
  }
  
  function nextPage() {
    if (currentPage < totalPages) {
      goToPage(currentPage + 1);
    }
  }
  
  function prevPage() {
    if (currentPage > 1) {
      goToPage(currentPage - 1);
    }
  }
  
  function handlePageSizeChange(event) {
    pageSize = parseInt(event.target.value, 10);
    currentPage = 1; // reset para primeira página
    dispatch('pageSizeChange', { pageSize });
  }
  
  // Resto das funções originais (getHeaderColor, getModalidadeIcon, etc.)
  const getHeaderColor = (tipo) => {
    if (!tipo) return 'header-default';
    const tipoLower = tipo.toLowerCase();
    if (tipoLower === 'municipal') return 'header-municipal';
    if (tipoLower === 'estadual') return 'header-estadual';
    if (tipoLower === 'privada') return 'header-privada';
    if (tipoLower === 'federal') return 'header-federal';
    return 'header-default';
  };

  const getModalidadeIcon = (modalidade) => {
    const icones = {
      'Educação Infantil': '🏫',
      'Ensino Fundamental': '📚',
      'Ensino Médio': '🎓',
      'Educação de Jovens Adultos': '👥',
      'Educação Profissional': '🔧'
    };
    return icones[modalidade] || '📖';
  };

  const formatTelefone = (telefone) => {
    if (!telefone) return null;
    const numeros = telefone.replace(/\D/g, '');
    if (numeros.length === 10) {
      return numeros.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3');
    } else if (numeros.length === 11) {
      return numeros.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
    }
    return telefone;
  };

  function handleViewPayroll(escola) {
    console.log('Disparando evento viewPayroll para:', escola);
    dispatch('viewPayroll', { escola });
  }

  // Corrigindo a função handleViewGrades
  function handleViewGrades(escola) {
    console.log('Disparando evento viewGrades para:', escola);
    dispatch('viewGrades', { escola });
  }
</script>

{#if loading}
  <div class="loading-container">
    <div class="spinner-large"></div>
    <p>Carregando escolas...</p>
  </div>
{:else if error}
  <div class="error-container">
    <p class="error-message">⚠️ {error}</p>
  </div>
{:else if escolas.length === 0}
  <div class="empty-container">
    <div class="empty-icon">🏫</div>
    <p class="empty-title">Nenhuma escola encontrada</p>
    <p class="empty-description">Tente buscar por outro nome ou cidade</p>
  </div>
{:else}
  <div class="schools-grid">
    {#each paginatedEscolas as escola (escola.codigo_inep)}
      <div class="school-card">
        <!-- Header com cor baseada no tipo -->
        <div class={`card-header ${getHeaderColor(escola.tipo)}`}>
          <div class="card-header-content">
            <h3 class="school-name">{escola.escola}</h3>
            <p class="school-inep">INEP: {escola.codigo_inep}</p>
          </div>
          <span class="tipo-badge">
            {escola.tipo || 'Não informado'}
          </span>
        </div>

        <div class="card-content">
          <div class="info-row">
            <span class="info-icon">📍</span>
            <div class="info-text">
              <p>{escola.endereco}</p>
              <p class="city-text">{escola.municipio} - {escola.uf}</p>
            </div>
          </div>

          {#if escola.modalidades && escola.modalidades.length}
            <div class="modalidades">
              {#each escola.modalidades as modalidade}
                <span class="modalidade-badge">
                  <span class="modalidade-icon">{getModalidadeIcon(modalidade)}</span>
                  {modalidade}
                </span>
              {/each}
            </div>
          {/if}

          {#if escola.porte_escola}
            <div class="info-row">
              <span class="info-icon">🏛️</span>
              <span class="info-text">{escola.porte_escola}</span>
            </div>
          {/if}

          {#if escola.telefone}
            <div class="info-row">
              <span class="info-icon">📞</span>
              <a href="tel:{escola.telefone}" class="phone-link">
                {formatTelefone(escola.telefone)}
              </a>
              {#if escola.whatsapp}
                <a href={escola.whatsapp} target="_blank" rel="noopener noreferrer" class="whatsapp-link">
                  💬 WhatsApp
                </a>
              {/if}
            </div>
          {/if}

          <!-- Botões de ação -->
          <div class="buttons-container">
            <button 
              class="payroll-btn"
              on:click={() => handleViewPayroll(escola)}>
              💰 Ver Folha de Pagamento
            </button>
            
            <button
              class="grades-btn"
              on:click={() => handleViewGrades(escola)}>
              📝 Notas INEP
            </button>
          </div>

          <div class="map-links">
            <a href={escola.osm} target="_blank" rel="noopener noreferrer" class="map-link">
              🗺️ OpenStreetMap
            </a>
            <button 
              class="map-link"
              on:click={() => {
                const url = `https://www.google.com/maps?q=${escola.latitude},${escola.longitude}`;
                window.open(url, '_blank');
              }}>
              🗺️ Google Maps
            </button>
          </div>

          <div class="coordinates">
            Lat: {escola.latitude} | Lon: {escola.longitude}
          </div>
        </div>
      </div>
    {/each}
  </div>
  
  <!-- Controles de Paginação -->
  <div class="pagination-container">
    <div class="pagination-controls">
      <button 
        class="pagination-btn" 
        on:click={prevPage} 
        disabled={currentPage === 1}>
        ← Anterior
      </button>
      
      <div class="page-info">
        Página <strong>{currentPage}</strong> de <strong>{totalPages}</strong>
      </div>
      
      <button 
        class="pagination-btn" 
        on:click={nextPage} 
        disabled={currentPage === totalPages}>
        Próxima →
      </button>
    </div>
    
    <div class="page-size-selector">
      <label for="pageSize">Itens por página:</label>
      <select id="pageSize" bind:value={pageSize} on:change={handlePageSizeChange}>
        <option value="10">10</option>
        <option value="20">20</option>
        <option value="50">50</option>
        <option value="100">100</option>
      </select>
    </div>
  </div>
  
  <div class="stats">
    <p>Mostrando {escolas.length} escola{escolas.length !== 1 ? 's' : ''}</p>
  </div>
{/if}

<style>
  .schools-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
    gap: 1.5rem;
  }

  .school-card {
    background: white;
    border-radius: 0.5rem;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.3s;
    border: 1px solid #e5e7eb;
  }

  .school-card:hover {
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);
  }

  /* Estilos base do header */
  .card-header {
    padding: 1rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 0.75rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  }

  /* Cores do header baseadas no tipo */
  .header-municipal {
    background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
    color: #166534;
  }

  .header-estadual {
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    color: #1e40af;
  }

  .header-privada {
    background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
    color: #6b21a5;
  }

  .header-federal {
    background: linear-gradient(135deg, #fef9c3 0%, #fde047 100%);
    color: #854d0e;
  }

  .header-default {
    background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    color: #374151;
  }

  .card-header-content {
    flex: 1;
  }

  .school-name {
    font-size: 1rem;
    font-weight: 700;
    margin-bottom: 0.25rem;
    line-height: 1.4;
    color: inherit;
  }

  .school-inep {
    font-size: 0.75rem;
    opacity: 0.7;
    color: inherit;
  }

  .tipo-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    background-color: rgba(255, 255, 255, 0.9);
    color: inherit;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  }

  .card-content {
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .info-row {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .info-icon {
    font-size: 1rem;
    flex-shrink: 0;
  }

  .info-text {
    flex: 1;
    color: #374151;
  }

  .city-text {
    font-size: 0.75rem;
    color: #6b7280;
    margin-top: 0.125rem;
  }

  .modalidades {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .modalidade-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.25rem 0.5rem;
    background-color: #f3f4f6;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 500;
    color: #374151;
  }

  .modalidade-icon {
    font-size: 0.75rem;
  }

  .phone-link, .whatsapp-link {
    color: #2563eb;
    text-decoration: none;
    font-size: 0.875rem;
  }

  .phone-link:hover, .whatsapp-link:hover {
    text-decoration: underline;
  }

  .buttons-container {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }
  
  .payroll-btn, .grades-btn {
    width: 100%;
    padding: 0.5rem;
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }
  
  .payroll-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
  
  .payroll-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }
  
  .grades-btn {
    background-color: #10b981;
  }
  
  .grades-btn:hover {
    background-color: #059669;
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }

  .map-links {
    display: flex;
    gap: 1rem;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e7eb;
  }

  .map-link {
    color: #2563eb;
    font-size: 0.75rem;
    text-decoration: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
  }

  .map-link:hover {
    text-decoration: underline;
  }

  .coordinates {
    font-size: 0.7rem;
    color: #9ca3af;
    padding-top: 0.5rem;
  }

  .loading-container, .error-container, .empty-container {
    text-align: center;
    padding: 3rem;
    background: white;
    border-radius: 0.5rem;
  }

  .spinner-large {
    display: inline-block;
    width: 2rem;
    height: 2rem;
    border: 3px solid #e5e7eb;
    border-radius: 50%;
    border-top-color: #2563eb;
    animation: spin 0.6s linear infinite;
    margin-bottom: 1rem;
  }

  .error-message {
    color: #dc2626;
  }

  .empty-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .empty-title {
    font-size: 1.125rem;
    font-weight: 500;
    color: #374151;
    margin-bottom: 0.5rem;
  }

  .empty-description {
    font-size: 0.875rem;
    color: #6b7280;
  }

  .stats {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
    text-align: center;
    font-size: 0.875rem;
    color: #6b7280;
  }

  .pagination-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
  }
  
  .pagination-controls {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  
  .pagination-btn {
    padding: 0.5rem 1rem;
    background-color: #f3f4f6;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .pagination-btn:hover:not(:disabled) {
    background-color: #e5e7eb;
    border-color: #9ca3af;
  }
  
  .pagination-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .page-info {
    font-size: 0.875rem;
    color: #374151;
  }
  
  .page-size-selector {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }
  
  .page-size-selector select {
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
    border: 1px solid #d1d5db;
    background-color: white;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (max-width: 640px) {
    .schools-grid {
      grid-template-columns: 1fr;
    }
    
    .tipo-badge {
      font-size: 0.7rem;
      padding: 0.2rem 0.6rem;
    }
    
    .buttons-container {
      grid-template-columns: 1fr;
    }
    .pagination-controls {
      justify-content: center;
    }
    .page-size-selector {
      justify-content: center;
    }
  }
</style>
