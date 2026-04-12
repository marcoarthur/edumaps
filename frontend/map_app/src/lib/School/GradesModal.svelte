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
  let selectedSerie = 'serie_1_4_anos'; // Opção padrão
  
  // Dados para o gráfico
  let chartData = [];
  let chartOptions = {};
  
  // Opções de séries escolares
  const seriesOptions = {
    'serie_1_4_anos': '1º ao 4º Ano (Ensino Fundamental I)',
    'serie_iniciais_1_4': 'Séries Iniciais (1º-4º)',
    'serie_5_8_anos': '5º ao 8º Ano (Ensino Fundamental II)',
    'ensino_medio': 'Ensino Médio',
    'serie_4': '4ª Série / 5º Ano'
  };
  
  // Anos disponíveis (baseado nos dados da API)
  let availableYears = [2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2021, 2023];
  
  function closeModal() {
    isOpen = false;
    dispatch('close');
  }
  
  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  }
  
  async function fetchSchoolData() {
    const id = school?.codigo_inep;
    
    console.log('FetchSchoolData chamado:', { school, id, isOpen });
    
    if (!school || !id) {
      console.log('School ou ID não disponível');
      error = 'Dados da escola não disponíveis.';
      return;
    }
    
    isLoading = true;
    error = null;
    schoolData = null;
    
    try {
      const url = `/api/school/${id}/full_grades`;
      console.log('Buscando dados da URL:', url);
      
      const response = await fetch(url);
      console.log('Resposta da API:', response.status);
      
      if (!response.ok) {
        throw new Error(`Erro ao carregar dados: ${response.status}`);
      }
      
      const data = await response.json();
      console.log('Dados recebidos:', data);
      schoolData = data;
      
      // Atualiza anos disponíveis baseado nos dados
      if (data.notas_por_serie && data.notas_por_serie[selectedSerie]) {
        const anos = Object.keys(data.notas_por_serie[selectedSerie].matematica || {});
        if (anos.length > 0) {
          availableYears = anos.map(Number).sort((a, b) => a - b);
          // Ajusta seleção de anos se necessário
          if (selectedSince < Math.min(...availableYears)) {
            selectedSince = Math.min(...availableYears);
          }
          if (selectedUntil > Math.max(...availableYears)) {
            selectedUntil = Math.max(...availableYears);
          }
        }
      }
      
      prepareChartData();
    } catch (err) {
      console.error('Erro ao buscar dados:', err);
      error = err.message || 'Erro ao carregar os dados da escola.';
      schoolData = null;
    } finally {
      isLoading = false;
    }
  }
  
  function prepareChartData() {
    if (!schoolData || !schoolData.notas_por_serie) {
      chartData = [];
      return;
    }
    
    const serieData = schoolData.notas_por_serie[selectedSerie];
    if (!serieData) {
      chartData = [];
      return;
    }
    
    // Prepara dados para o gráfico de linhas
    chartData = [];
    
    // Filtra anos pelo período selecionado
    const anos = Object.keys(serieData.matematica || {})
      .map(Number)
      .filter(ano => ano >= selectedSince && ano <= selectedUntil)
      .sort((a, b) => a - b);
    
    anos.forEach(ano => {
      const anoStr = ano.toString();
      
      // Dados de Matemática
      const matematica = serieData.matematica[anoStr];
      if (matematica !== null && matematica !== undefined) {
        chartData.push({
          group: 'Matemática',
          year: anoStr,
          value: parseFloat(matematica)
        });
      }
      
      // Dados de Português
      const portugues = serieData.portugues[anoStr];
      if (portugues !== null && portugues !== undefined) {
        chartData.push({
          group: 'Português',
          year: anoStr,
          value: parseFloat(portugues)
        });
      }
      
      // Dados da Média (opcional - pode ser adicionada como terceira linha)
      const media = serieData.media[anoStr];
      if (media !== null && media !== undefined && false) { // Desabilitado por padrão
        chartData.push({
          group: 'Média',
          year: anoStr,
          value: parseFloat(media)
        });
      }
    });
    
    // Configuração do gráfico
    chartOptions = {
      title: `Evolução das Notas - ${seriesOptions[selectedSerie] || selectedSerie}`,
      axes: {
        bottom: {
          title: 'Ano',
          mapsTo: 'year',
          scaleType: 'labels'
        },
        left: {
          title: 'Nota (0-10)',
          mapsTo: 'value',
          domain: [0, 10],
          ticks: {
            formatter: (tick) => tick.toFixed(1)
          }
        }
      },
      curve: 'curveLinear',
      points: {
        enabled: true,
        radius: 4,
        fillOpacity: 0.8
      },
      line: {
        strokeWidth: 2
      },
      legend: {
        enabled: true,
        position: 'top'
      },
      tooltip: {
        enabled: true,
        customHTML: (data) => {
          const { group, year, value } = data;
          // Verifica se value é válido antes de chamar toFixed
          const formattedValue = (value !== null && value !== undefined && !isNaN(value)) 
          return `
            <div style="padding: 8px; background: white; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15);">
              <strong>${group || 'N/A'}</strong><br/>
              Ano: ${year || 'N/A'}<br/>
              Nota: ${formattedValue}
            </div>
          `;
        }
      },
      grid: {
        x: {
          enabled: true,
          numberOfTicks: Math.min(10, anos.length)
        },
        y: {
          enabled: true,
          numberOfTicks: 10
        }
      },
      color: {
        scale: {
          'Matemática': '#2563eb',
          'Português': '#7c3aed',
          'Média': '#059669'
        }
      },
      height: '400px',
      resizable: true
    };
  }
  
  function handleSinceChange(e) {
    selectedSince = parseInt(e.target.value);
    if (selectedSince > selectedUntil) {
      selectedUntil = selectedSince;
    }
    prepareChartData();
  }
  
  function handleUntilChange(e) {
    selectedUntil = parseInt(e.target.value);
    if (selectedUntil < selectedSince) {
      selectedSince = selectedUntil;
    }
    prepareChartData();
  }
  
  function handleSerieChange(e) {
    selectedSerie = e.target.value;
    prepareChartData();
  }
  
  function formatValue(value, decimals = 2) {
    if (value === null || value === undefined) return 'N/A';
    return parseFloat(value).toFixed(decimals);
  }
  
  function formatPercent(value) {
    if (value === null || value === undefined) return 'N/A';
    return `${value}%`;
  }
  
  function formatIndicator(value) {
    if (value === null || value === undefined) return 'N/A';
    return (value * 100).toFixed(1) + '%';
  }
  
  // Reage a mudanças
  $: {
    if (school && isOpen) {
      fetchSchoolData();
    }
  }
  
  $: if (schoolData && schoolData.notas_por_serie) {
    prepareChartData();
  }
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
          <!-- Informações da Escola -->
          <div class="school-info">
            <h3>{schoolData.escola.nome}</h3>
            <div class="school-details">
              <span class="detail">Código INEP: {schoolData.escola.codigo_inep}</span>
              <span class="detail">Município: {schoolData.escola.municipio}/{schoolData.escola.uf}</span>
              <span class="detail">Rede: {schoolData.escola.rede}</span>
              <span class="detail">Código IBGE: {schoolData.escola.codigo_ibge}</span>
            </div>
          </div>
          
          <!-- Filtros -->
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
            <div class="loading">
              <div class="spinner"></div>
              <p>Carregando dados...</p>
            </div>
          {:else if error}
            <div class="error">
              <p>❌ {error}</p>
            </div>
          {:else}
            <!-- Gráfico de notas por série -->
            {#if chartData.length > 0}
              <div class="chart-container">
                <LineChart data={chartData} options={chartOptions} />
              </div>
            {:else}
              <div class="no-data">
                <p>📊 Nenhum dado disponível para o período selecionado.</p>
              </div>
            {/if}
            
            <!-- Tabela de Notas por Série -->
            {#if schoolData.notas_por_serie && schoolData.notas_por_serie[selectedSerie]}
              <div class="data-section">
                <h4>Notas por Ano - {seriesOptions[selectedSerie]}</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead>
                      <tr>
                        <th>Ano</th>
                        <th>Matemática</th>
                        <th>Português</th>
                        <th>Média</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const matematica = schoolData.notas_por_serie[selectedSerie].matematica[anoStr]}
                        {@const portugues = schoolData.notas_por_serie[selectedSerie].portugues[anoStr]}
                        {@const media = schoolData.notas_por_serie[selectedSerie].media[anoStr]}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell math-grade">{formatValue(matematica)}</td>
                          <td class="grade-cell portuguese-grade">{formatValue(portugues)}</td>
                          <td class="grade-cell average-grade">{formatValue(media)}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- Taxas de Aprovação -->
            {#if schoolData.taxas_aprovacao}
              <div class="data-section">
                <h4>Taxas de Aprovação (%)</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead>
                      <tr>
                        <th>Ano</th>
                        {#each Object.entries(seriesOptions) as [key, label]}
                          {#if schoolData.taxas_aprovacao[key]}
                            <th>{label}</th>
                          {/if}
                        {/each}
                      </tr>
                    </thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          {#each Object.entries(seriesOptions) as [key, label]}
                            {#if schoolData.taxas_aprovacao[key]}
                              <td class="grade-cell">
                                {formatPercent(schoolData.taxas_aprovacao[key][anoStr])}
                              </td>
                            {/if}
                          {/each}
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- Indicador de Rendimento -->
            {#if schoolData.indicador_rendimento}
              <div class="data-section">
                <h4>Indicador de Rendimento</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead>
                      <tr><th>Ano</th><th>Indicador</th></tr>
                    </thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatIndicator(schoolData.indicador_rendimento[anoStr])}</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- Valores Observados e Projeções -->
            {#if schoolData.valores_observados_e_projecoes}
              <div class="data-section">
                <h4>IDEB - Observado vs Projeção</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead>
                      <tr><th>Ano</th><th>Observado</th><th>Projeção</th><th>Meta Atingida?</th></tr>
                    </thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const dados = schoolData.valores_observados_e_projecoes[anoStr]}
                        {@const observado = dados?.observado}
                        {@const projecao = dados?.projecao}
                        {@const metaAtingida = observado !== null && projecao !== null && observado >= projecao}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatValue(observado)}</td>
                          <td class="grade-cell">{formatValue(projecao)}</td>
                          <td class="grade-cell {metaAtingida ? 'success' : observado !== null ? 'warning' : ''}">
                            {#if observado !== null && projecao !== null}
                              {metaAtingida ? '✓ Sim' : '✗ Não'}
                            {:else if observado !== null}
                              Sem projeção
                            {:else}
                              Sem dados
                            {/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- Metadados -->
            {#if schoolData.dados_extras?.metadados}
              <div class="metadata">
                <small>
                  📐 Escalas: 
                  Notas: {schoolData.dados_extras.metadados.escala_notas} | 
                  Taxas: {schoolData.dados_extras.metadados.escala_taxas_aprovacao} | 
                  Indicador: {schoolData.dados_extras.metadados.escala_indicador_rendimento}
                </small>
              </div>
            {/if}
          {/if}
        {:else if !isLoading}
          <div class="error">
            <p>⚠️ Dados da escola não disponíveis</p>
          </div>
        {/if}
      </div>
      
      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeModal}>Fechar</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
  }
  
  .modal {
    background: white;
    border-radius: 8px;
    width: 95%;
    max-width: 1200px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .modal-header h2 {
    margin: 0;
    font-size: 1.25rem;
    color: #111827;
  }
  
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #6b7280;
    padding: 0;
    width: 2rem;
    height: 2rem;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 4px;
  }
  
  .close-btn:hover {
    background-color: #f3f4f6;
    color: #111827;
  }
  
  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }
  
  .school-info {
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .school-info h3 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
    color: #111827;
  }
  
  .school-details {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    font-size: 0.875rem;
    color: #6b7280;
  }
  
  .detail {
    background-color: #f3f4f6;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
  }
  
  .filters {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    padding: 1rem;
    background-color: #f9fafb;
    border-radius: 6px;
    flex-wrap: wrap;
  }
  
  .filter-group {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }
  
  .filter-group label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #374151;
  }
  
  .filter-group select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    font-size: 0.875rem;
    background-color: white;
    cursor: pointer;
    min-width: 150px;
  }
  
  .filter-group select:hover {
    border-color: #9ca3af;
  }
  
  .chart-container {
    margin-bottom: 2rem;
    padding: 1rem;
    background-color: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
  }
  
  .data-section {
    margin-bottom: 2rem;
  }
  
  .data-section h4 {
    margin: 0 0 1rem 0;
    font-size: 1rem;
    color: #374151;
  }
  
  .loading, .error, .no-data {
    text-align: center;
    padding: 2rem;
    color: #6b7280;
  }
  
  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
  }
  
  .spinner {
    width: 40px;
    height: 40px;
    border: 3px solid #f3f3f3;
    border-top: 3px solid #10b981;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  
  .error {
    color: #dc2626;
    background-color: #fef2f2;
    border-radius: 6px;
  }
  
  .grades-table-container {
    overflow-x: auto;
  }
  
  .grades-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }
  
  .grades-table th,
  .grades-table td {
    padding: 0.75rem;
    text-align: left;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .grades-table th {
    background-color: #f9fafb;
    font-weight: 600;
    color: #374151;
    position: sticky;
    top: 0;
  }
  
  .grades-table tbody tr:hover {
    background-color: #f9fafb;
  }
  
  .year-cell {
    font-weight: 500;
    color: #111827;
  }
  
  .grade-cell {
    font-family: monospace;
    font-size: 0.875rem;
  }
  
  .math-grade {
    color: #2563eb;
    font-weight: 500;
  }
  
  .portuguese-grade {
    color: #7c3aed;
    font-weight: 500;
  }
  
  .average-grade {
    color: #059669;
    font-weight: 600;
  }
  
  .success {
    color: #059669;
    font-weight: 600;
  }
  
  .warning {
    color: #d97706;
    font-weight: 600;
  }
  
  .metadata {
    margin-top: 1.5rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
    font-size: 0.75rem;
    color: #6b7280;
    text-align: center;
  }
  
  .modal-footer {
    padding: 1rem 1.5rem;
    border-top: 1px solid #e5e7eb;
    display: flex;
    justify-content: flex-end;
  }
  
  .btn {
    padding: 0.5rem 1rem;
    border-radius: 4px;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    border: none;
  }
  
  .btn-secondary {
    background-color: #f3f4f6;
    color: #374151;
  }
  
  .btn-secondary:hover {
    background-color: #e5e7eb;
  }
</style>
