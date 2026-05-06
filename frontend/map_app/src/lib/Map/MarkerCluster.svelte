<script>
  import { onDestroy } from 'svelte';
  import L from 'leaflet';
  import 'leaflet.markercluster/dist/leaflet.markercluster';
  import 'leaflet.markercluster/dist/MarkerCluster.css';
  import 'leaflet.markercluster/dist/MarkerCluster.Default.css';

  export let getMarkerColor = null;        // função que retorna cor baseada nos dados
  export let getPopupContent = null;       // função que retorna HTML do popup
  export let fetchMarkers = null;          // função async para buscar marcadores (bbox, zoom) => dados
  export let onMarkerClick = null;         // callback quando marcador é clicado
  export let clusterSize = {
    small: { radius: 30, threshold: 10 },
    medium: { radius: 35, threshold: 50 },
    large: { radius: 40, threshold: Infinity }
  };
  export let markerRadius = 7;
  export let clusterSpiderfy = true;
  export let debounceDelay = 300;

  let mapInstance = null;
  let markerClusterGroup = null;
  let loading = false;
  let loadedMarkers = new Set();
  let debounceTimer;

  // Configuração padrão de cores
  const defaultGetMarkerColor = (data) => data.color || '#3b82f6';
  
  // Popup padrão
  const defaultGetPopupContent = (data) => `
    <div style="font-family: sans-serif;">
      <strong>${data.name || 'Sem nome'}</strong><br>
      <button onclick="window.location.href='${data.link || '#'}'">Ver detalhes</button>
    </div>
  `;

  const finalGetMarkerColor = getMarkerColor || defaultGetMarkerColor;
  const finalGetPopupContent = getPopupContent || defaultGetPopupContent;

  // Criar ícone de cluster customizado
  const createClusterIcon = (cluster) => {
    const childCount = cluster.getChildCount();
    let size = 'small';
    
    if (childCount > clusterSize.medium.threshold) {
      size = 'large';
    } else if (childCount > clusterSize.small.threshold) {
      size = 'medium';
    }
    
    const radius = clusterSize[size].radius;
    const fontSize = radius * 0.4;
    
    return L.divIcon({
      html: `<div class="cluster-${size}" style="width: ${radius}px; height: ${radius}px; font-size: ${fontSize}px;">${childCount}</div>`,
      className: 'marker-cluster-custom',
      iconSize: [radius, radius]
    });
  };

  // Adicionar marcadores ao mapa
  const addMarkers = (markersData) => {
    if (!mapInstance || !markersData || markersData.length === 0) return;
    
    if (!markerClusterGroup) {
      markerClusterGroup = L.markerClusterGroup({
        maxClusterRadius: 40,
        spiderfyOnMaxZoom: clusterSpiderfy,
        iconCreateFunction: createClusterIcon
      });
      mapInstance.addLayer(markerClusterGroup);
    }
    
    markersData.forEach(item => {
      if (!item.latitude || !item.longitude) return;
      
      const markerId = item.id || `${item.latitude},${item.longitude}`;
      if (loadedMarkers.has(markerId)) return;
      
      const marker = L.circleMarker([item.latitude, item.longitude], {
        radius: markerRadius,
        fillColor: finalGetMarkerColor(item),
        color: 'white',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.85
      });
      
      marker.options.data = item;
      
      marker.bindPopup(finalGetPopupContent(item));
      
      if (onMarkerClick) {
        marker.on('click', () => onMarkerClick(item, marker));
      }
      
      markerClusterGroup.addLayer(marker);
      loadedMarkers.add(markerId);
    });
  };

  // Carregar marcadores visíveis no viewport
  const loadVisibleMarkers = async () => {
    if (!mapInstance || !fetchMarkers) return;
    
    loading = true;
    
    const bounds = mapInstance.getBounds();
    const zoom = mapInstance.getZoom();
    const bbox = `${bounds.getWest()},${bounds.getSouth()},${bounds.getEast()},${bounds.getNorth()}`;
    
    try {
      const data = await fetchMarkers(bbox, zoom);
      addMarkers(data);
    } catch (err) {
      console.error('Erro ao carregar marcadores:', err);
    } finally {
      loading = false;
    }
  };

  // Handler para eventos do mapa
  const handleMapMoveEnd = () => {
    if (!fetchMarkers) return;
    
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      loadVisibleMarkers();
    }, debounceDelay);
  };

  // Destacar um marcador específico
  export function highlightMarker(id, highlightColor = '#f59e0b', duration = 2000) {
    if (!markerClusterGroup) return;
    
    markerClusterGroup.eachLayer(layer => {
      if (layer.options.data?.id === id || layer.options.data?.co_municipio === id) {
        const originalColor = finalGetMarkerColor(layer.options.data);
        layer.setStyle({ fillColor: highlightColor, radius: markerRadius + 3 });
        
        if (duration > 0) {
          setTimeout(() => {
            if (layer.setStyle) {
              layer.setStyle({ fillColor: originalColor, radius: markerRadius });
            }
          }, duration);
        }
        
        layer.openPopup();
      }
    });
  }

  // Limpar todos os marcadores
  export function clearMarkers() {
    if (markerClusterGroup) {
      markerClusterGroup.clearLayers();
      loadedMarkers.clear();
    }
  }

  // Forçar recarregamento
  export function reload() {
    clearMarkers();
    loadVisibleMarkers();
  }

  // Inicialização do mapa
  export function init(map) {
    mapInstance = map;
    mapInstance.on('moveend', handleMapMoveEnd);
    mapInstance.on('zoomend', handleMapMoveEnd);
    loadVisibleMarkers();
  }

  // Limpeza
  onDestroy(() => {
    if (mapInstance) {
      mapInstance.off('moveend', handleMapMoveEnd);
      mapInstance.off('zoomend', handleMapMoveEnd);
    }
    if (markerClusterGroup) {
      markerClusterGroup.clearLayers();
    }
  });
</script>

<!-- Este componente não renderiza nada visual diretamente -->
<!-- Toda a lógica é gerenciada via JavaScript e Leaflet -->

<style>
  /* Estilos dos clusters */
  :global(.cluster-small) {
    background: #3b82f6;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }

  :global(.cluster-medium) {
    background: #2563eb;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }

  :global(.cluster-large) {
    background: #1d4ed8;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }
</style>
