<script>
  import { onMount, onDestroy, setContext } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  export let center = [-23.56, -45.15];
  export let zoom = 15;
  export let style = {};

  let mapContainer;
  let map;
  let mapReady = false;

  // Expose map instance to child components via context
  setContext('leaflet-map', {
    getMap: () => map,
    isReady: () => mapReady
  });

  onMount(() => {
    // Aguardar o próximo tick para garantir que o DOM está pronto
    setTimeout(() => {
      map = L.map(mapContainer).setView(center, zoom);
      mapReady = true;
    }, 0);
  });

  onDestroy(() => {
    map?.remove();
  });

  // Public methods
  export function fitBounds(bounds) {
    map?.fitBounds(bounds);
  }

  export function getMap() {
    return map;
  }
</script>

<div class="map-container" bind:this={mapContainer} style={style}>
  {#if mapReady}
    <slot />
  {/if}
</div>

<style>
  .map-container {
    height: 600px;
    width: 100%;
    border: 2px solid #ccc;
    border-radius: 8px;
  }
</style>
