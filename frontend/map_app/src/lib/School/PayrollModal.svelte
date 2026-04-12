<script>
  import { createEventDispatcher } from 'svelte';
  
  export let show = false;
  export let escola = null;
  
  let payroll = null;
  let loading = false;
  let error = null;
  let selectedYear = new Date().getFullYear();
  let selectedMonth = new Date().getMonth() + 1;
  
  const dispatch = createEventDispatcher();
  
  const months = [
    { value: 1, name: 'Janeiro' },
    { value: 2, name: 'Fevereiro' },
    { value: 3, name: 'Março' },
    { value: 4, name: 'Abril' },
    { value: 5, name: 'Maio' },
    { value: 6, name: 'Junho' },
    { value: 7, name: 'Julho' },
    { value: 8, name: 'Agosto' },
    { value: 9, name: 'Setembro' },
    { value: 10, name: 'Outubro' },
    { value: 11, name: 'Novembro' },
    { value: 12, name: 'Dezembro' }
  ];
  
  const years = [2021, 2022, 2023, 2024, 2025];
  
  async function loadPayroll() {
    if (!escola) return;
    
    loading = true;
    error = null;
    payroll = null;
    
    try {
      const url = `/api/school/${escola.codigo_inep}/payroll?year=${selectedYear}&month=${selectedMonth}`;
      console.log('Carregando payroll:', url);
      
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`Erro ao carregar payroll: ${response.status}`);
      }
      
      const data = await response.json();
      console.log('Payroll carregado:', data);
      
      // Garantir que profissionais seja sempre um array
      payroll = {
        ...data,
        profissionais: data.profissionais || [],
        resumo_categoria: data.resumo_categoria || {},
        resumo_segmento: data.resumo_segmento || {}
      };
    } catch (err) {
      error = err.message;
      console.error('Erro ao carregar payroll:', err);
    } finally {
      loading = false;
    }
  }
  
  function formatCurrency(value) {
    if (!value && value !== 0) return 'R$ 0,00';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(value);
  }
  
  function formatCPF(cpf) {
    if (!cpf) return '';
    // Remove caracteres não numéricos
    const clean = cpf.replace(/\D/g, '');
    if (clean.length === 11) {
      return clean.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
    }
    return cpf;
  }
  
  function closeModal() {
    show = false;
    payroll = null;
    dispatch('close');
  }
  
  function handleOverlayClick(e) {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  }
  
  $: if (show && escola) {
    loadPayroll();
  }
</script>

{#if show}
  <div class="modal-overlay" on:click={handleOverlayClick}>
    <div class="modal-container">
      <div class="modal-header">
        <div>
          <h2>💰 Folha de Pagamento</h2>
          <p class="school-name">{escola?.escola}</p>
          <p class="school-info">INEP: {escola?.codigo_inep} | {escola?.municipio} - {escola?.uf}</p>
        </div>
        <button class="close-btn" on:click={closeModal}>✕</button>
      </div>
      
      <div class="modal-controls">
        <div class="controls-group">
          <label for="year">Ano:</label>
          <select id="year" bind:value={selectedYear} on:change={loadPayroll} disabled={loading}>
            {#each years as year}
              <option value={year}>{year}</option>
            {/each}
          </select>
        </div>
        
        <div class="controls-group">
          <label for="month">Mês:</label>
          <select id="month" bind:value={selectedMonth} on:change={loadPayroll} disabled={loading}>
            {#each months as month}
              <option value={month.value}>{month.name}</option>
            {/each}
          </select>
        </div>
        
        <button class="refresh-btn" on:click={loadPayroll} disabled={loading}>
          {#if loading}
            <span class="spinner-small"></span>
          {:else}
            🔄
          {/if}
          Atualizar
        </button>
      </div>
      
      <div class="modal-content">
        {#if loading}
          <div class="loading-state">
            <div class="spinner"></div>
            <p>Carregando dados da folha de pagamento...</p>
          </div>
        {:else if error}
          <div class="error-state">
            <p class="error-icon">⚠️</p>
            <p class="error-message">{error}</p>
            <p class="error-hint">Verifique se os dados estão disponíveis para o período selecionado.</p>
          </div>
        {:else if payroll && payroll.escola}
          <div class="payroll-info">
            <div class="info-card">
              <h3>📊 Resumo da Escola</h3>
              <div class="info-grid">
                <div class="info-item">
                  <span class="info-label">Escola:</span>
                  <span class="info-value">{payroll.escola.escola}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Dependência:</span>
                  <span class="info-value">{payroll.escola.dependencia_administrativa}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Período:</span>
                  <span class="info-value">{payroll.escola.mes || months[selectedMonth-1]?.name}/{payroll.escola.ano || selectedYear}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Total Profissionais:</span>
                  <span class="info-value">{payroll.profissionais?.length || 0}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Total Salários:</span>
                  <span class="info-value total-salario">
                    {formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_total || 0), 0))}
                  </span>
                </div>
              </div>
            </div>
            
            <div class="profissionais-section">
              <h3>👥 Profissionais ({payroll.profissionais?.length || 0})</h3>
              
              {#if payroll.profissionais && payroll.profissionais.length > 0}
                <div class="profissionais-table-container">
                  <table class="profissionais-table">
                    <thead>
                      <tr>
                        <th>Nome</th>
                        <th>CPF</th>
                        <th>Categoria</th>
                        <th>Situação</th>
                        <th>Carga Horária</th>
                        <th>Salário Base</th>
                        <th>Salário Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each payroll.profissionais as profissional, index (index)}
                        <tr>
                          <td class="nome-cell">{profissional.nome}</td>
                          <td class="cpf-cell">{formatCPF(profissional.cpf)}</td>
                          <td class="categoria-cell">{profissional.categoria}</td>
                          <td>
                            <span class={`situacao-badge ${profissional.situacao === 'Efetivo' ? 'situacao-efetivo' : 'situacao-outro'}`}>
                              {profissional.situacao}
                            </span>
                          </td>
                          <td>{profissional.carga_horaria}h</td>
                          <td class="valor-cell">{formatCurrency(profissional.salario_base)}</td>
                          <td class="valor-cell destaque">{formatCurrency(profissional.salario_total)}</td>
                        </tr>
                      {/each}
                    </tbody>
                    <tfoot>
                      <tr class="total-row">
                        <td colspan="5"><strong>Total Geral</strong></td>
                        <td class="valor-cell">
                          <strong>{formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_base || 0), 0))}</strong>
                        </td>
                        <td class="valor-cell destaque">
                          <strong>{formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_total || 0), 0))}</strong>
                        </td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              {:else}
                <div class="empty-profissionais">
                  <p>📭 Nenhum profissional encontrado para o período selecionado.</p>
                  <p class="empty-hint">Tente selecionar outro ano ou mês.</p>
                </div>
              {/if}
            </div>
          </div>
        {:else}
          <div class="error-state">
            <p class="error-icon">📭</p>
            <p class="error-message">Nenhum dado disponível</p>
            <p class="error-hint">Não foi possível carregar os dados para este período.</p>
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
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
    animation: fadeIn 0.2s ease;
  }
  
  .modal-container {
    background: white;
    border-radius: 0.75rem;
    width: 90%;
    max-width: 1300px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    animation: slideUp 0.3s ease;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }
  
  .modal-header {
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-radius: 0.75rem 0.75rem 0 0;
  }
  
  .modal-header h2 {
    font-size: 1.5rem;
    font-weight: bold;
    margin-bottom: 0.25rem;
  }
  
  .school-name {
    font-size: 1rem;
    font-weight: 500;
    opacity: 0.9;
    margin-bottom: 0.25rem;
  }
  
  .school-info {
    font-size: 0.875rem;
    opacity: 0.8;
  }
  
  .close-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background-color 0.2s;
  }
  
  .close-btn:hover {
    background: rgba(255, 255, 255, 0.3);
  }
  
  .modal-controls {
    padding: 1rem 1.5rem;
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    gap: 1rem;
    align-items: flex-end;
  }
  
  .controls-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  
  .controls-group label {
    font-size: 0.75rem;
    font-weight: 500;
    color: #6b7280;
  }
  
  .controls-group select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    background: white;
  }
  
  .refresh-btn {
    padding: 0.5rem 1rem;
    background-color: #3b82f6;
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    transition: background-color 0.2s;
  }
  
  .refresh-btn:hover:not(:disabled) {
    background-color: #2563eb;
  }
  
  .refresh-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }
  
  .loading-state, .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    text-align: center;
  }
  
  .spinner {
    width: 3rem;
    height: 3rem;
    border: 3px solid #e5e7eb;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-bottom: 1rem;
  }
  
  .spinner-small {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }
  
  .error-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }
  
  .error-message {
    font-size: 1.125rem;
    font-weight: 500;
    color: #dc2626;
    margin-bottom: 0.5rem;
  }
  
  .error-hint {
    font-size: 0.875rem;
    color: #6b7280;
  }
  
  .payroll-info {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  
  .info-card {
    background: #f9fafb;
    border-radius: 0.5rem;
    padding: 1.25rem;
    border: 1px solid #e5e7eb;
  }
  
  .info-card h3 {
    font-size: 1rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 1rem;
  }
  
  .info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }
  
  .info-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  
  .info-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: #6b7280;
    text-transform: uppercase;
  }
  
  .info-value {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
  }
  
  .total-salario {
    color: #059669;
    font-size: 1.125rem;
  }
  
  .profissionais-section h3 {
    font-size: 1rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 1rem;
  }
  
  .profissionais-table-container {
    overflow-x: auto;
  }
  
  .profissionais-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }
  
  .profissionais-table thead {
    background: #f3f4f6;
  }
  
  .profissionais-table th {
    padding: 0.75rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .profissionais-table td {
    padding: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
    color: #6b7280;
  }
  
  .profissionais-table tr:hover {
    background: #f9fafb;
  }
  
  .nome-cell {
    font-weight: 500;
    color: #1f2937;
  }
  
  .cpf-cell {
    font-family: monospace;
    font-size: 0.75rem;
  }
  
  .categoria-cell {
    max-width: 200px;
    white-space: normal;
    word-break: break-word;
  }
  
  .valor-cell {
    text-align: right;
    font-family: monospace;
  }
  
  .destaque {
    font-weight: 600;
    color: #059669;
  }
  
  .situacao-badge {
    display: inline-block;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-size: 0.75rem;
    font-weight: 500;
  }
  
  .situacao-efetivo {
    background-color: #dcfce7;
    color: #166534;
  }
  
  .situacao-outro {
    background-color: #f3f4f6;
    color: #374151;
  }
  
  .total-row {
    background: #f9fafb;
    font-weight: 600;
  }
  
  .total-row td {
    border-top: 2px solid #e5e7eb;
    padding-top: 0.75rem;
  }
  
  .empty-profissionais {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
  }
  
  .empty-profissionais p {
    color: #6b7280;
    margin-bottom: 0.5rem;
  }
  
  .empty-hint {
    font-size: 0.75rem;
    color: #9ca3af;
  }
  
  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
  
  @keyframes slideUp {
    from {
      transform: translateY(20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }
  
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  
  @media (max-width: 768px) {
    .modal-container {
      width: 95%;
      max-height: 95vh;
    }
    
    .modal-header h2 {
      font-size: 1.25rem;
    }
    
    .info-grid {
      grid-template-columns: 1fr;
    }
    
    .profissionais-table th,
    .profissionais-table td {
      padding: 0.5rem;
      font-size: 0.75rem;
    }
  }
</style>
