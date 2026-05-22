<script>
  import { createEventDispatcher } from 'svelte';
  import { LineChart } from '@carbon/charts-svelte';
  import '@carbon/styles/css/styles.css';
  import '@carbon/charts-svelte/styles.css';
  
  export let school = null;
  export let isOpen = false;
  
  const dispatch = createEventDispatcher();
  
  let schoolData = null;
  let isLoading = false;
  let error = null;
  let selectedSince = 2005;
  let selectedUntil = 2023;
  let selectedSerie = 'fundamental_i';
  
  let chartData = [];
  let chartOptions = {};
  
  const seriesOptions = {
    'fundamental_i': '1º ao 4º Ano (Fundamental I)',
    'fundamental_ii': '5º ao 9º Ano (Fundamental II)',
    'ensino_medio': 'Ensino Médio'
  };
  
  let availableYears = []; // será preenchido dinamicamente baseado nos dados reais
  
  let hasNotasData = false; // indica se a API forneceu notas_por_serie
  
  function closeModal() {
    isOpen = false;
    dispatch('close');
  }
  
  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) closeModal();
  }
  
  async function fetchSchoolData() {
    const id = school?.codigo_inep;
    if (!id) {
      error = 'Identificador da escola não encontrado.';
      return;
    }
    
    isLoading = true;
    error = null;
    schoolData = null;
    
    try {
      const url = `/api/school/${id}/full_grades`;
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      schoolData = data;
      
      // Verifica se existem dados de notas (matemática/português)
      hasNotasData = !!(schoolData?.notas_por_serie && Object.keys(schoolData.notas_por_serie).length > 0);
      
      // Determina os anos disponíveis com base nos dados que existem
      updateAvailableYears();
      
      // Prepara gráfico apenas se houver dados de notas
      if (hasNotasData) prepareChartData();
    } catch (err) {
      console.error(err);
      error = err.message || 'Erro ao carregar os dados da escola.';
    } finally {
      isLoading = false;
    }
  }
  
  function updateAvailableYears() {
    let anosSet = new Set();
    
    // Tenta extrair anos das notas, se existirem
    if (hasNotasData && schoolData?.notas_por_serie?.[selectedSerie]?.matematica) {
      Object.keys(schoolData.notas_por_serie[selectedSerie].matematica).forEach(ano => anosSet.add(Number(ano)));
    }
    
    // Se não houver notas, ou para complementar, busca anos do indicador_rendimento para a série selecionada
    const indicadorSeries = schoolData?.indicador_rendimento?.[selectedSerie];
    if (indicadorSeries && typeof indicadorSeries === 'object') {
      Object.keys(indicadorSeries).forEach(ano => anosSet.add(Number(ano)));
    }
    
    let anos = Array.from(anosSet).filter(ano => !isNaN(ano)).sort((a,b) => a-b);
    if (anos.length === 0) {
      // Fallback: anos comuns das avaliações
      anos = [2005,2007,2009,2011,2013,2015,2017,2019,2021,2023];
    }
    availableYears = anos;
    
    // Ajusta os seletores de ano
    if (selectedSince < Math.min(...anos)) selectedSince = Math.min(...anos);
    if (selectedUntil > Math.max(...anos)) selectedUntil = Math.max(...anos);
  }
  
  function prepareChartData() {
    if (!hasNotasData || !schoolData?.notas_por_serie?.[selectedSerie]) {
      chartData = [];
      return;
    }
    
    const serieData = schoolData.notas_por_serie[selectedSerie];
    const newChartData = [];
    const anos = availableYears.filter(ano => ano >= selectedSince && ano <= selectedUntil).sort();
    
    anos.forEach(ano => {
      const anoStr = ano.toString();
      const matematica = serieData.matematica?.[anoStr];
      const portugues = serieData.portugues?.[anoStr];
      if (matematica != null) {
        newChartData.push({ group: 'Matemática', year: anoStr, value: parseFloat(matematica) });
      }
      if (portugues != null) {
        newChartData.push({ group: 'Português', year: anoStr, value: parseFloat(portugues) });
      }
    });
    
    chartData = newChartData;
    
    chartOptions = {
      title: `Evolução das Notas - ${seriesOptions[selectedSerie]}`,
      axes: {
        bottom: { title: 'Ano', mapsTo: 'year', scaleType: 'labels' },
        left: { title: 'Nota (0-10)', mapsTo: 'value', domain: [0, 10], ticks: { formatter: (tick) => tick.toFixed(1) } }
      },
      curve: 'curveLinear',
      points: { enabled: true, radius: 4 },
      line: { strokeWidth: 2 },
      legend: { position: 'top' },
      tooltip: {
        enabled: true,
        customHTML: (data) => {
          const { group, year, value } = data;
          const formattedValue = (value != null && !isNaN(value)) ? value.toFixed(2) : 'N/A';
          return `<div style="padding:8px;background:white;border-radius:4px;box-shadow:0 2px 8px rgba(0,0,0,0.15);">
            <strong>${group}</strong><br/>Ano: ${year}<br/>Nota: ${formattedValue}
          </div>`;
        }
      },
      grid: { x: { numberOfTicks: Math.min(10, anos.length) }, y: { numberOfTicks: 10 } },
      color: { scale: { 'Matemática': '#2563eb', 'Português': '#7c3aed' } },
      height: '400px',
      resizable: true
    };
  }
  
  function handleSinceChange(e) {
    selectedSince = parseInt(e.target.value);
    if (selectedSince > selectedUntil) selectedUntil = selectedSince;
    if (hasNotasData) prepareChartData();
  }
  
  function handleUntilChange(e) {
    selectedUntil = parseInt(e.target.value);
    if (selectedUntil < selectedSince) selectedSince = selectedUntil;
    if (hasNotasData) prepareChartData();
  }
  
  function handleSerieChange(e) {
    selectedSerie = e.target.value;
    updateAvailableYears();
    if (hasNotasData) prepareChartData();
  }
  
  function formatValue(value, decimals = 2) {
    if (value === null || value === undefined) return 'N/A';
    const num = parseFloat(value);
    return isNaN(num) ? 'N/A' : num.toFixed(decimals);
  }
  
  // Extrai o valor do indicador de rendimento (pode estar em 'total_serie' ou 'media')
  function getIndicadorValue(anoData) {
    if (!anoData) return null;
    // Prioriza total_serie (usado nos dados reais), depois media
    if (anoData.total_serie !== undefined && anoData.total_serie !== null) return anoData.total_serie;
    if (anoData.media !== undefined && anoData.media !== null) return anoData.media;
    return null;
  }
  
  // Reatividade
  $: if (school && isOpen) fetchSchoolData();
  $: if (schoolData && hasNotasData) prepareChartData();
</script>

{#if isOpen}
  <div class="modal-backdrop" on:click={handleBackdropClick}>
    <div class="modal">
      <div class="modal-header">
        <h2>Dados Completos da Escola</h2>
        <button class="close-btn" on:click={closeModal}>×</button>
      </div>
      
      <div class="modal-content">
        {#if schoolData}
          <div class="school-info">
            <h3>{school.escola || 'Nome não informado'}</h3>
            <div class="school-details">
              <span class="detail">Código INEP: {school.codigo_inep || '—'}</span>
              <span class="detail">Município: {school.municipio || '—'}</span>
              <span class="detail">Rede: {school.tipo || '—'}</span>
            </div>
          </div>
          
          <div class="filters">
            <div class="filter-group">
              <label for="serie">Série Escolar:</label>
              <select id="serie" bind:value={selectedSerie} on:change={handleSerieChange}>
                {#each Object.entries(seriesOptions) as [value, label]}
                  <option value={value}>{label}</option>
                {/each}
              </select>
            </div>
            <div class="filter-group">
              <label for="since">Ano Inicial:</label>
              <select id="since" bind:value={selectedSince} on:change={handleSinceChange}>
                {#each availableYears.filter(y => y <= selectedUntil) as year}
                  <option value={year}>{year}</option>
                {/each}
              </select>
            </div>
            <div class="filter-group">
              <label for="until">Ano Final:</label>
              <select id="until" bind:value={selectedUntil} on:change={handleUntilChange}>
                {#each availableYears.filter(y => y >= selectedSince) as year}
                  <option value={year}>{year}</option>
                {/each}
              </select>
            </div>
          </div>
          
          {#if isLoading}
            <div class="loading"><div class="spinner"></div><p>Carregando dados...</p></div>
          {:else if error}
            <div class="error"><p>❌ {error}</p></div>
          {:else}
            <!-- Seção de gráfico e tabela de notas – só aparece se houver dados de notas -->
            {#if hasNotasData}
              {#if chartData.length > 0}
                <div class="chart-container"><LineChart data={chartData} options={chartOptions} /></div>
              {:else}
                <div class="no-data"><p>📊 Nenhum dado de nota disponível para o período selecionado.</p></div>
              {/if}
              
              <!-- Tabela de Notas (matemática/português) -->
              {#if schoolData.notas_por_serie?.[selectedSerie]}
                <div class="data-section">
                  <h4>Notas por Ano - {seriesOptions[selectedSerie]}</h4>
                  <div class="grades-table-container">
                    <table class="grades-table">
                      <thead><tr><th>Ano</th><th>Matemática</th><th>Português</th><th>Média</th></tr></thead>
                      <tbody>
                        {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                          {@const anoStr = ano.toString()}
                          {@const mat = schoolData.notas_por_serie[selectedSerie].matematica?.[anoStr]}
                          {@const port = schoolData.notas_por_serie[selectedSerie].portugues?.[anoStr]}
                          {@const med = schoolData.notas_por_serie[selectedSerie].media?.[anoStr]}
                          <tr>
                            <td class="year-cell">{ano}</td>
                            <td class="grade-cell math-grade">{formatValue(mat)}</td>
                            <td class="grade-cell portuguese-grade">{formatValue(port)}</td>
                            <td class="grade-cell average-grade">{formatValue(med)}</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                </div>
              {/if}
            {:else}
              <div class="info">
                <p>ℹ️ Esta escola não possui dados de notas (Matemática/Português) disponíveis. Os indicadores de rendimento são apresentados abaixo.</p>
              </div>
            {/if}
            
            <!-- Indicador de Rendimento (agora lê total_serie ou media) -->
            {#if schoolData.indicador_rendimento?.[selectedSerie]}
              <div class="data-section">
                <h4>Indicador de Rendimento (Taxa de aprovação média)</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead><tr><th>Ano</th><th>Indicador (%)</th></tr></thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const anoData = schoolData.indicador_rendimento[selectedSerie][anoStr]}
                        {@const indicador = getIndicadorValue(anoData)}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatValue(indicador, 1)}%</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- IDEB Observado vs Projeção (apenas se for um objeto válido) -->
            {#if schoolData.valores_observados_e_projecoes && typeof schoolData.valores_observados_e_projecoes === 'object' && !Array.isArray(schoolData.valores_observados_e_projecoes)}
              <div class="data-section">
                <h4>IDEB - Observado vs Projeção</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead><tr><th>Ano</th><th>Observado</th><th>Projeção</th><th>Meta Atingida?</th></tr></thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const dados = schoolData.valores_observados_e_projecoes[anoStr]}
                        {@const observado = dados?.observado}
                        {@const projecao = dados?.projecao}
                        {@const metaAtingida = observado != null && projecao != null && parseFloat(observado) >= parseFloat(projecao)}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatValue(observado)}</td>
                          <td class="grade-cell">{formatValue(projecao)}</td>
                          <td class="grade-cell {metaAtingida ? 'success' : observado != null ? 'warning' : ''}">
                            {#if observado != null && projecao != null}
                              {metaAtingida ? '✓ Sim' : '✗ Não'}
                            {:else if observado != null}Sem projeção{:else}Sem dados{/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
          {/if}
        {:else if !isLoading}
          <div class="error"><p>⚠️ Dados da escola não disponíveis</p></div>
        {/if}
      </div>
      
      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeModal}>Fechar</button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Mantenha os estilos exatamente como estavam (já fornecidos anteriormente) */
  .modal-backdrop { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background-color: rgba(0,0,0,0.5); display: flex; justify-content: center; align-items: center; z-index: 1000; }
  .modal { background: white; border-radius: 8px; width: 95%; max-width: 1200px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
  .modal-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.5rem; border-bottom: 1px solid #e5e7eb; }
  .modal-header h2 { margin: 0; font-size: 1.25rem; color: #111827; }
  .close-btn { background: none; border: none; font-size: 1.5rem; cursor: pointer; color: #6b7280; padding: 0; width: 2rem; height: 2rem; display: flex; align-items: center; justify-content: center; border-radius: 4px; }
  .close-btn:hover { background-color: #f3f4f6; color: #111827; }
  .modal-content { flex: 1; overflow-y: auto; padding: 1.5rem; }
  .school-info { margin-bottom: 1.5rem; padding-bottom: 1rem; border-bottom: 1px solid #e5e7eb; }
  .school-info h3 { margin: 0 0 0.5rem 0; font-size: 1.1rem; color: #111827; }
  .school-details { display: flex; flex-wrap: wrap; gap: 1rem; font-size: 0.875rem; color: #6b7280; }
  .detail { background-color: #f3f4f6; padding: 0.25rem 0.5rem; border-radius: 4px; }
  .filters { display: flex; gap: 1rem; margin-bottom: 1.5rem; padding: 1rem; background-color: #f9fafb; border-radius: 6px; flex-wrap: wrap; }
  .filter-group { display: flex; flex-direction: column; gap: 0.5rem; }
  .filter-group label { font-size: 0.875rem; font-weight: 500; color: #374151; }
  .filter-group select { padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 4px; font-size: 0.875rem; background-color: white; cursor: pointer; min-width: 180px; }
  .chart-container { margin-bottom: 2rem; padding: 1rem; background-color: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; }
  .data-section { margin-bottom: 2rem; }
  .data-section h4 { margin: 0 0 1rem 0; font-size: 1rem; color: #374151; }
  .loading, .error, .no-data, .info { text-align: center; padding: 2rem; color: #6b7280; }
  .loading { display: flex; flex-direction: column; align-items: center; gap: 1rem; }
  .spinner { width: 40px; height: 40px; border: 3px solid #f3f3f3; border-top: 3px solid #10b981; border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  .error { color: #dc2626; background-color: #fef2f2; border-radius: 6px; }
  .info { color: #2563eb; background-color: #eff6ff; border-radius: 6px; }
  .grades-table-container { overflow-x: auto; }
  .grades-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
  .grades-table th, .grades-table td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #e5e7eb; }
  .grades-table th { background-color: #f9fafb; font-weight: 600; color: #374151; position: sticky; top: 0; }
  .grades-table tbody tr:hover { background-color: #f9fafb; }
  .year-cell { font-weight: 500; color: #111827; }
  .grade-cell { font-family: monospace; font-size: 0.875rem; }
  .math-grade { color: #2563eb; font-weight: 500; }
  .portuguese-grade { color: #7c3aed; font-weight: 500; }
  .average-grade { color: #059669; font-weight: 600; }
  .success { color: #059669; font-weight: 600; }
  .warning { color: #d97706; font-weight: 600; }
  .modal-footer { padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; display: flex; justify-content: flex-end; }
  .btn { padding: 0.5rem 1rem; border-radius: 4px; font-size: 0.875rem; font-weight: 500; cursor: pointer; border: none; }
  .btn-secondary { background-color: #f3f4f6; color: #374151; }
  .btn-secondary:hover { background-color: #e5e7eb; }
</style>
