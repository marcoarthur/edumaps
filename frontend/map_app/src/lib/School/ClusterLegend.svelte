<!-- ClusterLegend.svelte -->
<script>
  export let clusters = [];
  export let position = 'bottomright';
  
  const clusterInfo = {
    1: { name: 'Excelência', color: '#10b981', description: 'IDEB > 8.0, crescimento forte' },
    2: { name: 'Alto Desempenho', color: '#3b82f6', description: 'IDEB 6.0-8.0, consistente' },
    3: { name: 'Médio Desempenho', color: '#f59e0b', description: 'IDEB 4.5-6.0, estável' },
    4: { name: 'Baixo Desempenho', color: '#ef4444', description: 'IDEB < 4.5, atenção' },
    5: { name: 'Em Declínio', color: '#8b5cf6', description: 'Tendência negativa' },
    6: { name: 'Em Ascensão', color: '#06b6d4', description: 'Crescimento acelerado' }
  };
</script>

<div class="legend" class:bottomright={position === 'bottomright'} class:topright={position === 'topright'}>
  <div class="legend-title">📊 Clusters de Escolas</div>
  {#each Object.entries(clusterInfo) as [id, info]}
    <div class="legend-item">
      <div class="legend-color" style="background-color: {info.color}"></div>
      <div class="legend-info">
        <span class="legend-name">Cluster {id}: {info.name}</span>
        <span class="legend-desc">{info.description}</span>
      </div>
    </div>
  {/each}
</div>

<style>
  .legend {
    position: absolute;
    background: white;
    padding: 12px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    z-index: 1000;
    font-size: 12px;
    min-width: 200px;
    max-width: 250px;
  }
  
  .bottomright {
    bottom: 20px;
    right: 20px;
  }
  
  .topright {
    top: 20px;
    right: 20px;
  }
  
  .legend-title {
    font-weight: 600;
    margin-bottom: 8px;
    padding-bottom: 4px;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }
  
  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  
  .legend-info {
    flex: 1;
  }
  
  .legend-name {
    font-weight: 500;
    display: block;
  }
  
  .legend-desc {
    font-size: 10px;
    color: #6b7280;
  }
</style>
