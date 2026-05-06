<script>
  import { onMount, onDestroy, setContext, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  export let center = [-15.5, -55.0];  // Centro do Brasil
  export let zoom = 4;
  export let style = {};
  export let tileLayer = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  export let tileLayerOptions = {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/">CartoDB</a>',
    subdomains: 'abcd',
    maxZoom: 19,
    minZoom: 3
  };

  let mapContainer;
  let mapReady = false;
  let map;
  const dispatch = createEventDispatcher();

  // Expor instância do mapa para componentes filhos via context
  setContext('leaflet-map', {
    getMap: () => map,
    isReady: () => mapReady
  });

  onMount(() => {
    // Inicializar o mapa
    map = L.map(mapContainer).setView(center, zoom);
    
    // Adicionar tile layer padrão (obrigatório para ver o mapa!)
    L.tileLayer(tileLayer, tileLayerOptions).addTo(map);
    
    mapReady = true;
    
    // Disparar evento personalizado para components que escutam
    dispatch('mapReady', { map });
  });

  onDestroy(() => {
    if (map) {
      map.remove();
    }
  });

  // Métodos públicos
  export function fitBounds(bounds) {
    map?.fitBounds(bounds);
  }

  export function getMap() {
    return map;
  }
  
  export function setView(lat, lng, newZoom) {
    map?.setView([lat, lng], newZoom);
  }
</script>

<div bind:this={mapContainer} class="map-container" style={style}>
  {#if mapReady}
    <slot />
  {/if}
</div>

<style>
  .map-container {
    height: 500px;
    width: 100%;
    border-radius: 8px;
    overflow: hidden;
    position: relative;
    z-index: 1;  /* Adicionar z-index baixo */
  }
  
  /* Estilos padrão para tiles Leaflet */
  :global(.leaflet-container) {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  
  :global(.leaflet-popup-content-wrapper) {
    border-radius: 8px;
  }

  /* Forçar todos os elementos do Leaflet terem z-index menor */
  :global(.leaflet-pane),
  :global(.leaflet-top),
  :global(.leaflet-bottom),
  :global(.leaflet-control-container),
  :global(.leaflet-popup) {
    z-index: 1000 !important;
  }
</style>
