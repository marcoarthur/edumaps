<script>
  import { onDestroy } from 'svelte';
  
  export let map = null;
  export let clusterData = null;
  export let visible = false;
  export let onSchoolSelect = null;
  
  let layerGroup = null;
  let initializationAttempts = 0;
  let retryInterval = null;
  
  const clusterColors = {
    1: { bg: '#10b981', name: 'Excelência', icon: '🏆' },
    2: { bg: '#3b82f6', name: 'Alto Desempenho', icon: '⭐' },
    3: { bg: '#f59e0b', name: 'Médio Desempenho', icon: '📊' },
    4: { bg: '#ef4444', name: 'Baixo Desempenho', icon: '⚠️' },
    5: { bg: '#8b5cf6', name: 'Em Declínio', icon: '📉' },
    6: { bg: '#06b6d4', name: 'Em Ascensão', icon: '📈' }
  };
  
  function getClusterIcon(clusterId, size = 32) {
    const cluster = clusterColors[clusterId] || { bg: '#6b7280', name: 'Outro', icon: '📍' };
    
    return L.divIcon({
      className: 'cluster-marker',
      html: `
        <div style="
          background-color: ${cluster.bg};
          width: ${size}px;
          height: ${size}px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: ${size * 0.5}px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          border: 2px solid white;
          cursor: pointer;
          transition: transform 0.2s;
        "
        onmouseover="this.style.transform='scale(1.1)'"
        onmouseout="this.style.transform='scale(1)'">
          ${cluster.icon}
        </div>
      `,
      iconSize: [size, size],
      popupAnchor: [0, -size/2]
    });
  }
  
  function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  
  function createPopupContent(school, clusterInfo) {
    const cluster = clusterColors[clusterInfo.cluster_id] || clusterColors[3];
    
    return `
      <div class="cluster-popup">
        <div class="popup-header" style="border-left-color: ${cluster.bg}">
          <h4>${escapeHtml(school.escola || 'Escola sem nome')}</h4>
          <span class="cluster-badge" style="background: ${cluster.bg}">
            ${cluster.icon} ${cluster.name}
          </span>
        </div>
        <div class="popup-body">
          <p><strong>📍 Local:</strong> ${escapeHtml(school.municipio)}/${school.uf}</p>
          <p><strong>🏫 Rede:</strong> ${school.rede || 'N/A'}</p>
          <hr/>
          <p><strong>⭐ IDEB 2023:</strong> <span class="value">${school.ideb?.toFixed(2) || 'N/A'}</span></p>
          <p><strong>📈 Nota Média:</strong> <span class="value">${school.nota?.toFixed(2) || 'N/A'}</span></p>
          <p><strong>✅ Aprovação:</strong> <span class="value">${school.aprovacao?.toFixed(1) || 'N/A'}%</span></p>
          <p><strong>📉 Tendência:</strong> <span class="value ${school.tendencia >= 0 ? 'positive' : 'negative'}">
            ${school.tendencia >= 0 ? '📈 +' : '📉 '}${school.tendencia?.toFixed(2) || '0'}
          </span></p>
        </div>
        <div class="popup-footer">
          <button class="btn-details" data-id="${school.id_escola}">
            Ver Detalhes
          </button>
        </div>
      </div>
    `;
  }
  
  function handleDetailClick(e) {
    const schoolId = parseInt(e.target.dataset.id);
    if (onSchoolSelect) onSchoolSelect(schoolId);
  }
  
  function bindPopupEvents() {
    setTimeout(() => {
      document.querySelectorAll('.btn-details').forEach(btn => {
        btn.removeEventListener('click', handleDetailClick);
        btn.addEventListener('click', handleDetailClick);
      });
    }, 100);
  }
  
  function isValidMap(mapInstance) {
    return mapInstance && 
           typeof mapInstance === 'object' && 
           typeof mapInstance.hasLayer === 'function' &&
           typeof mapInstance.addLayer === 'function';
  }
  
  function clearMarkers() {
    if (layerGroup) {
      layerGroup.clearLayers();
      if (map && isValidMap(map) && map.hasLayer(layerGroup)) {
        map.removeLayer(layerGroup);
      }
      layerGroup = null;
    }
  }
  
  function updateMarkers() {
    // Limpar markers existentes primeiro
    clearMarkers();
    
    // Verificar se o mapa é válido
    if (!isValidMap(map)) {
      console.log('ClusterLayer: Aguardando mapa ficar disponível...', { mapExists: !!map, hasLayer: map?.hasLayer });
      // Tentar novamente em 500ms se o mapa ainda não estiver pronto
      if (retryInterval) clearTimeout(retryInterval);
      retryInterval = setTimeout(() => {
        if (isValidMap(map)) {
          updateMarkers();
        }
      }, 500);
      return;
    }
    
    // Verificar condições para mostrar markers
    if (!visible || !clusterData || !Array.isArray(clusterData) || clusterData.length === 0) {
      console.log('ClusterLayer: Sem dados para mostrar', { visible, hasData: !!clusterData });
      return;
    }
    
    console.log('ClusterLayer: Atualizando markers', { 
      clusters: clusterData.length, 
      mapIsValid: true 
    });
    
    // Criar novo layer group
    layerGroup = L.layerGroup();
    
    // Adicionar novos markers
    let totalMarkers = 0;
    clusterData.forEach(cluster => {
      const clusterId = cluster.cluster_id;
      
      if (cluster.escolas && Array.isArray(cluster.escolas)) {
        cluster.escolas.forEach(school => {
          if (school.latitude && school.longitude) {
            const marker = L.marker([school.latitude, school.longitude], {
              icon: getClusterIcon(clusterId)
            });
            
            marker.bindPopup(createPopupContent(school, cluster), {
              maxWidth: 300,
              minWidth: 250,
              className: 'cluster-popup-wrapper'
            });
            
            marker.on('popupopen', bindPopupEvents);
            marker.addTo(layerGroup);
            totalMarkers++;
          }
        });
      }
    });
    
    console.log(`ClusterLayer: Adicionados ${totalMarkers} markers ao mapa`);
    
    // Adicionar ao mapa se tiver markers
    if (totalMarkers > 0) {
      layerGroup.addTo(map);
      
      // Ajustar zoom para mostrar todos os marcadores
      try {
        const bounds = L.latLngBounds(
          layerGroup.getLayers().map(layer => layer.getLatLng())
        );
        map.fitBounds(bounds, { padding: [50, 50] });
      } catch (e) {
        console.warn('Erro ao ajustar bounds:', e);
      }
    }
  }
  
  // Reagir a mudanças nas props
  $: {
    if (map && clusterData && visible) {
      // Pequeno delay para garantir que o mapa está completamente inicializado
      setTimeout(() => {
        updateMarkers();
      }, 100);
    } else if (!visible) {
      clearMarkers();
    }
  }
  
  // Limpeza no destroy
  onDestroy(() => {
    if (retryInterval) clearTimeout(retryInterval);
    clearMarkers();
  });
</script>
