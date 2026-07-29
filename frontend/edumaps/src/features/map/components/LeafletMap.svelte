<script>
  // src/features/map/components/LeafletMap.svelte
  //
  // Substitui AppMap.svelte / BaseMap.svelte / AnalBaseMap.svelte / Map.svelte
  // do frontend antigo — todos faziam a mesma inicialização de Leaflet
  // com pequenas variações de estilo e tile layer.
  import { onMount, onDestroy } from "svelte";
  import L from "leaflet";
  import "leaflet/dist/leaflet.css";
  import { provideMapContext } from "../context.js";

  let {
    center = [-15.5, -55.0], // centro do Brasil por padrão
    zoom = 4,
    minZoom = 3,
    maxZoom = 19,
    tileUrl = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
    attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/">CartoDB</a>',
    class: className = "",
    height = "100%",
    children,
    onMapReady,
  } = $props();

  let mapContainer;
  let map = $state(null);
  let ready = $state(false);

  // Objeto reativo único, publicado no contexto — todas as layers
  // filhas leem `mapState.map` e `mapState.ready`, sem precisar
  // de polling (`setInterval(checkMap, 50)`) como no código antigo.
  const mapState = $state({ map: null, ready: false });
  provideMapContext(mapState);

  onMount(() => {
    map = L.map(mapContainer, { minZoom, maxZoom }).setView(center, zoom);

    L.tileLayer(tileUrl, { attribution, minZoom, maxZoom }).addTo(map);

    ready = true;
    mapState.map = map;
    mapState.ready = true;

    onMapReady?.(map);
  });

  onDestroy(() => {
    map?.remove();
    mapState.map = null;
    mapState.ready = false;
  });

  // API pública exposta via bind:this — mantém compatibilidade
  // com o padrão usado no código antigo (baseMap.getMap(), fitBounds etc.)
  export function getMap() {
    return map;
  }

  export function fitBounds(bounds, options) {
    map?.fitBounds(bounds, options);
  }

  export function setView(lat, lng, newZoom = zoom) {
    map?.setView([lat, lng], newZoom);
  }

  export function invalidateSize() {
    // necessário quando o container muda de tamanho (ex: painel lateral abre/fecha)
    map?.invalidateSize();
  }
</script>

<div
  bind:this={mapContainer}
  class="relative z-0 w-full overflow-hidden rounded-card {className}"
  style:height
>
  {#if ready}
    {@render children?.()}
  {/if}
</div>
