<script>
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  export let cityName = '';
  export let statusMessage = '';
  export let showClusters = false;  // Novo prop
  export let selectedClusters = [1, 2, 3, 4, 5, 6]; // Novos clusters padrão

  function handleKeyPress(e) {
    if (e.key === 'Enter') dispatch('search');
  }

  function toggleClusters() {
    showClusters = !showClusters;
    dispatch('toggleClusters', { showClusters });
  }

  function updateClusterFilter(clusterId, checked) {
    if (checked) {
      selectedClusters = [...selectedClusters, clusterId];
    } else {
      selectedClusters = selectedClusters.filter(id => id !== clusterId);
    }
    dispatch('clusterFilterChange', { selectedClusters });
  }
</script>

<div class="controls">
  <div class="controls-row">
    <button on:click={() => dispatch('search')}>🔍 Search City</button>
    <button on:click={() => dispatch('clear')}>🗑️ Clear Map</button>
    <input
      bind:value={cityName}
      on:keypress={handleKeyPress}
      type="text"
      placeholder="Enter city name"
      class="form-control"
    />
    <span id="status">{statusMessage}</span>
  </div>
  
  <!-- Controle de Clusterização -->
  <div class="cluster-controls">
    <label class="cluster-toggle">
      <input 
        type="checkbox" 
        bind:checked={showClusters} 
        on:change={toggleClusters}
      />
      <span>📊 Ativar Análise por Clusters</span>
    </label>
    
    {#if showClusters}
      <div class="cluster-filters">
        <span class="filter-label">Filtrar por cluster:</span>
        <label class="filter-chip cluster-1">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(1)}
            on:change={(e) => updateClusterFilter(1, e.target.checked)}
          />
          <span>🏆 Excelência</span>
        </label>
        <label class="filter-chip cluster-2">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(2)}
            on:change={(e) => updateClusterFilter(2, e.target.checked)}
          />
          <span>⭐ Alto</span>
        </label>
        <label class="filter-chip cluster-3">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(3)}
            on:change={(e) => updateClusterFilter(3, e.target.checked)}
          />
          <span>📊 Médio</span>
        </label>
        <label class="filter-chip cluster-4">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(4)}
            on:change={(e) => updateClusterFilter(4, e.target.checked)}
          />
          <span>⚠️ Baixo</span>
        </label>
        <label class="filter-chip cluster-5">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(5)}
            on:change={(e) => updateClusterFilter(5, e.target.checked)}
          />
          <span>📉 Declínio</span>
        </label>
        <label class="filter-chip cluster-6">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(6)}
            on:change={(e) => updateClusterFilter(6, e.target.checked)}
          />
          <span>📈 Ascensão</span>
        </label>
      </div>
    {/if}
  </div>
</div>

<style>
  .controls {
    margin-bottom: 15px;
    padding: 14px;
    background: #f5f5f5;
    border-radius: 5px;
  }
  
  .controls-row {
    display: flex;
    gap: 10px;
    align-items: center;
    flex-wrap: wrap;
  }
  
  .form-control {
    display: inline-block;
    width: 200px;
    padding: 6px 12px;
    font-size: 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
  }
  
  .cluster-controls {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #ddd;
  }
  
  .cluster-toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-weight: 500;
    margin-bottom: 10px;
  }
  
  .cluster-toggle input {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }
  
  .cluster-filters {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-left: 24px;
  }
  
  .filter-label {
    font-size: 12px;
    color: #666;
    margin-right: 4px;
  }
  
  .filter-chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    background: white;
    border-radius: 16px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s;
    border: 1px solid #ddd;
  }
  
  .filter-chip:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }
  
  .filter-chip input {
    margin: 0;
    cursor: pointer;
  }
  
  .cluster-1 { border-left: 3px solid #10b981; }
  .cluster-2 { border-left: 3px solid #3b82f6; }
  .cluster-3 { border-left: 3px solid #f59e0b; }
  .cluster-4 { border-left: 3px solid #ef4444; }
  .cluster-5 { border-left: 3px solid #8b5cf6; }
  .cluster-6 { border-left: 3px solid #06b6d4; }
</style>
