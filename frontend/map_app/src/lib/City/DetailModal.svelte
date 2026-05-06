<script>
  import { createEventDispatcher } from 'svelte';

  export let isOpen = false;
  export let cityData = null;
  export let onClose = () => {};

  let activeTab = 'resumo';
  let loading = false;
  let error = null;

  const dispatch = createEventDispatcher();

  const closeModal = () => {
    isOpen = false;
    onClose();
    dispatch('close');
  };

  // Formatação de números
  const formatNumber = (value, decimals = 0) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toLocaleString('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
  };

  const formatPercent = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    if ( num < 1 ) {
      return (num * 100).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
    } else {
      return (num).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
    }
  };

  const formatCurrency = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return 'R$ ' + num.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  const formatScore = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toFixed(1);
  };

  const getIdebColor = (ideb) => {
    const i = parseFloat(ideb);
    if (i >= 7) return '#059669';
    if (i >= 5) return '#22c55e';
    if (i >= 3) return '#f59e0b';
    return '#ef4444';
  };

  // Função para gerar segmentos do pie chart
  const generatePieSegments = () => {
    if (!cityData) return [];
    
    const values = [
      { label: 'Agro', value: parseFloat(cityData.agro_percent) || 0, color: '#22c55e' },
      { label: 'Indústria', value: parseFloat(cityData.industria_percent) || 0, color: '#3b82f6' },
      { label: 'Serviços', value: parseFloat(cityData.servicos_percent) || 0, color: '#f59e0b' },
      { label: 'Governo', value: parseFloat(cityData.governo_percent) || 0, color: '#ef4444' }
    ];
    
    const nonZero = values.filter(v => v.value > 0);
    const total = nonZero.reduce((sum, v) => sum + v.value, 0);
    let currentAngle = 0;
    
    return nonZero.map(v => {
      const angle = (v.value / total) * 360;
      const startAngle = currentAngle;
      const endAngle = currentAngle + angle;
      currentAngle = endAngle;
      
      const startRad = (startAngle - 90) * Math.PI / 180;
      const endRad = (endAngle - 90) * Math.PI / 180;
      const radius = 80;
      const centerX = 100;
      const centerY = 100;
      const x1 = centerX + radius * Math.cos(startRad);
      const y1 = centerY + radius * Math.sin(startRad);
      const x2 = centerX + radius * Math.cos(endRad);
      const y2 = centerY + radius * Math.sin(endRad);
      const largeArc = angle > 180 ? 1 : 0;
      
      return {
        label: v.label,
        value: (v.value * 100).toFixed(1),
        color: v.color,
        path: `M ${centerX} ${centerY} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z`
      };
    });
  };
</script>

{#if isOpen && cityData}
  <div class="modal-overlay" on:click={closeModal}>
    <div class="modal-container" on:click|stopPropagation>
      <div class="modal-header">
        <div class="modal-title">
          <h2>
            {cityData.no_municipio || cityData.nome_municipio}
            <span class="uf-badge">{cityData.sg_uf || cityData.sigla_estado}</span>
          </h2>
          <p class="modal-subtitle">
            Região {cityData.no_regiao || ''} • Código IBGE {cityData.co_municipio || cityData.codigo_ibge}
          </p>
        </div>
        <button class="close-btn" on:click={closeModal}>✕</button>
      </div>

      <div class="modal-tabs">
        <button class="tab" class:active={activeTab === 'resumo'} on:click={() => activeTab = 'resumo'}>
          📊 Resumo
        </button>
        <button class="tab" class:active={activeTab === 'infra'} on:click={() => activeTab = 'infra'}>
          🏗️ Infraestrutura
        </button>
        <button class="tab" class:active={activeTab === 'economia'} on:click={() => activeTab = 'economia'}>
          💰 Economia
        </button>
        <button class="tab" class:active={activeTab === 'demografia'} on:click={() => activeTab = 'demografia'}>
          👥 Demografia
        </button>
      </div>

      <div class="modal-body">
        {#if activeTab === 'resumo'}
          <div class="summary-grid">
            <div class="card">
              <div class="card-title">📚 População Escolar</div>
              <div class="stat-large">{formatNumber(cityData.total_alunos)}</div>
              <div class="stat-detail">
                <span>👶 Infantil: {formatNumber(cityData.alunos_infantil)}</span>
                <span>📘 Fundamental: {formatNumber(cityData.alunos_fundamental)}</span>
                <span>🎓 Médio: {formatNumber(cityData.alunos_medio)}</span>
                <span>📖 EJA: {formatNumber(cityData.alunos_eja)}</span>
              </div>
            </div>

            <div class="card">
              <div class="card-title">🎯 Qualidade do Ensino (IDEB)</div>
              <div class="ideb-grid">
                <div class="ideb-item">
                  <span class="ideb-label">Fund. I</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_i)}">
                    {formatNumber(cityData.ideb_fund_i, 1)}
                  </span>
                </div>
                <div class="ideb-item">
                  <span class="ideb-label">Fund. II</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_ii)}">
                    {formatNumber(cityData.ideb_fund_ii, 1)}
                  </span>
                </div>
                <div class="ideb-item">
                  <span class="ideb-label">Médio</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_medio)}">
                    {formatNumber(cityData.ideb_medio, 1)}
                  </span>
                </div>
              </div>
              <div class="card-footnote">Ano referência: {cityData.ano_ideb || 2023}</div>
            </div>

            <div class="card">
              <div class="card-title">👩‍🏫 Corpo Docente</div>
              <div class="stat-large">{formatNumber(cityData.total_docentes)}</div>
              <div class="stat-detail">
                <span>🎓 Superior: {formatPercent(cityData.perc_docentes_superior)}</span>
                <span>⚖️ Concursados: {formatPercent(cityData.perc_docentes_concursados)}</span>
                <span>👨‍👩‍👧 Aluno/Docente: {cityData.alunos_por_docente}</span>
              </div>
            </div>

            <div class="card">
              <div class="card-title">🏫 Rede Escolar</div>
              <div class="stat-large">{formatNumber(cityData.total_escolas)} escolas</div>
              <div class="stat-detail">
                <span>🏛️ Pública: {cityData.escolas_publicas}</span>
                <span>🏨 Privada: {cityData.escolas_privadas}</span>
                <span>🌆 Urbana: {cityData.escolas_urbanas}</span>
                <span>🌾 Rural: {cityData.escolas_rurais}</span>
              </div>
            </div>
          </div>

          <div class="cards-row">
            <div class="card half">
              <div class="card-title">📈 Infraestrutura (Score 0-10)</div>
              <div class="scores-grid">
                <div class="score-item">
                  <span>🏗️ Básica</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_infra_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_infra_medio)}</span>
                </div>
                <div class="score-item">
                  <span>💻 Tecnologia</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_tecnologia_medio)}</span>
                </div>
                <div class="score-item">
                  <span>♿ Acessibilidade</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_acessibilidade_medio)}</span>
                </div>
                <div class="score-item">
                  <span>🗳️ Gestão</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_gestao_medio)}</span>
                </div>
              </div>
            </div>

            <div class="card half">
              <div class="card-title">👥 Atendimento Educacional</div>
              <div class="stats-compact">
                <div class="stat-row">
                  <span>📊 Alunos por 1.000 hab:</span>
                  <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)}</strong>
                </div>
                <div class="stat-row">
                  <span>📚 Alunos por escola:</span>
                  <strong>{formatNumber(cityData.alunos_por_escola)}</strong>
                </div>
                <div class="stat-row">
                  <span>👩‍🏫 Alunos por docente:</span>
                  <strong>{cityData.alunos_por_docente}</strong>
                </div>
              </div>
            </div>
          </div>
        {/if}

        {#if activeTab === 'infra'}
          <div class="full-card">
            <div class="card-title">🏗️ Indicadores de Infraestrutura Escolar</div>
            <div class="scores-detailed">
              <div class="score-detailed-item">
                <div class="score-label">Infraestrutura Básica</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_infra_medio) * 10}%; background: #2563eb;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_infra_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Tecnologia e Conectividade</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%; background: #059669;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_tecnologia_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Acessibilidade e Inclusão</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%; background: #d97706;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_acessibilidade_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Gestão e Participação</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%; background: #7c3aed;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_gestao_medio)}/10</div>
              </div>
            </div>
          </div>
        {/if}

        {#if activeTab === 'economia'}
          <div class="grid-2cols">
            <div class="card">
              <div class="card-title">💰 Produto Interno Bruto</div>
              <div class="stat-large">{formatCurrency(cityData.pib_total)}</div>
              <div class="stat-detail">PIB total (R$ milhares)</div>
              <div class="stat-large" style="font-size: 1.5rem;">{formatCurrency(cityData.pib_per_capita)}</div>
              <div class="stat-detail">PIB per capita</div>
              <div class="card-footnote">Ano referência: {cityData.ano_pib || 2021}</div>
            </div>

            <div class="card">
              <div class="card-title">🏭 Composição Setorial do PIB</div>
              {#if parseFloat(cityData.agro_percent) || parseFloat(cityData.industria_percent) || parseFloat(cityData.servicos_percent) || parseFloat(cityData.governo_percent)}
                <div class="pie-container">
                  <div class="pie-chart">
                    <svg viewBox="0 0 200 200" width="160" height="160">
                      {#each generatePieSegments() as segment}
                        <path d={segment.path} fill={segment.color} stroke="white" stroke-width="2" />
                      {/each}
                      <circle cx="100" cy="100" r="45" fill="white" />
                      <text x="100" y="95" text-anchor="middle" font-size="11" font-weight="bold" fill="#333">Total</text>
                      <text x="100" y="110" text-anchor="middle" font-size="9" fill="#666">100%</text>
                    </svg>
                  </div>
                  <div class="pie-legend">
                    {#each generatePieSegments() as segment}
                      <div class="legend-item">
                        <span class="legend-color" style="background: {segment.color}"></span>
                        <span class="legend-label">{segment.label}</span>
                        <span class="legend-value">{segment.value}%</span>
                      </div>
                    {/each}
                  </div>
                </div>
              {:else}
                <div class="no-data-message">
                  <p>📭 Dados de composição setorial não disponíveis</p>
                </div>
              {/if}
            </div>
          </div>
        {/if}

        {#if activeTab === 'demografia'}
          <div class="grid-2cols">
            <div class="card">
              <div class="card-title">👥 População</div>
              <div class="stat-large">{formatNumber(cityData.populacao_estimada)}</div>
              <div class="stat-detail">habitantes estimados</div>
              <div class="pyramid-container">
                <div class="age-group">
                  <span>0-14 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_0_a_14 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_0_a_14 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>15-24 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_15_a_24 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_15_a_24 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>25-59 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_25_a_59 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_25_a_59 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>60+ anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_60_mais / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_60_mais / cityData.populacao_estimada)}</span>
                </div>
              </div>
            </div>

            <div class="card">
              <div class="card-title">📊 Indicadores de Cobertura</div>
              <div class="stats-compact">
                <div class="stat-row">
                  <span>📚 Cobertura escolar:</span>
                  <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)} alunos/1.000 hab</strong>
                </div>
                <div class="stat-row">
                  <span>🏫 Densidade de escolas:</span>
                  <strong>{(cityData.total_escolas / cityData.populacao_estimada * 1000).toFixed(2)} escolas/1.000 hab</strong>
                </div>
                <div class="stat-row">
                  <span>👩‍🎓 % população na escola:</span>
                  <strong>{formatPercent(cityData.total_alunos / cityData.populacao_estimada)}</strong>
                </div>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 99999;
  }

  .modal-container {
    background: #f3f4f6;
    border-radius: 1rem;
    width: 90vw;
    max-width: 1200px;
    height: 85vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 25px 50px rgba(0,0,0,0.3);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 1.25rem 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .modal-title h2 {
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.25rem;
  }

  .uf-badge {
    background: #2563eb;
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .modal-subtitle {
    color: #6b7280;
    font-size: 0.875rem;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #6b7280;
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
  }

  .close-btn:hover {
    background: #f3f4f6;
    color: #111827;
  }

  .modal-tabs {
    display: flex;
    gap: 0.5rem;
    padding: 0 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .tab {
    padding: 0.75rem 1.5rem;
    background: none;
    border: none;
    font-size: 0.875rem;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.2s;
  }

  .tab:hover {
    color: #2563eb;
  }

  .tab.active {
    color: #2563eb;
    border-bottom: 2px solid #2563eb;
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }

  /* Reutilizando os estilos já existentes */
  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.25rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .half {
    flex: 1;
  }

  .card-title {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #6b7280;
    margin-bottom: 1rem;
  }

  .stat-large {
    font-size: 2rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .stat-detail {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    font-size: 0.75rem;
    color: #6b7280;
    border-top: 1px solid #e5e7eb;
    padding-top: 0.75rem;
    margin-top: 0.5rem;
  }

  .ideb-grid {
    display: flex;
    justify-content: space-around;
    text-align: center;
  }

  .ideb-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .ideb-label {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .ideb-value {
    font-size: 1.5rem;
    font-weight: 700;
  }

  .scores-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .score-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .score-bar {
    flex: 1;
    height: 6px;
    background: #e5e7eb;
    border-radius: 3px;
    overflow: hidden;
  }

  .score-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 3px;
  }

  .score-value {
    min-width: 2rem;
    text-align: right;
    font-weight: 500;
  }

  .cards-row {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .stats-compact {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .stat-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
  }

  .grid-2cols {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 1rem;
  }

  .full-card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .scores-detailed {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .score-detailed-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .score-label {
    width: 180px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .score-bar-large {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .score-fill-large {
    height: 100%;
    border-radius: 4px;
  }

  .score-number {
    min-width: 3rem;
    text-align: right;
    font-weight: 600;
  }

  .pyramid-container {
    margin-top: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .age-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.875rem;
  }

  .age-bar {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .age-bar-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 4px;
  }

  .card-footnote {
    margin-top: 0.75rem;
    font-size: 0.7rem;
    color: #9ca3af;
    text-align: right;
  }

  .pie-container {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 2rem;
    flex-wrap: wrap;
  }

  .pie-chart {
    flex-shrink: 0;
  }

  .pie-legend {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .legend-label {
    min-width: 70px;
    color: #374151;
  }

  .legend-value {
    font-weight: 600;
    color: #111827;
    margin-left: auto;
  }

  .no-data-message {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    color: #6b7280;
  }
</style>
