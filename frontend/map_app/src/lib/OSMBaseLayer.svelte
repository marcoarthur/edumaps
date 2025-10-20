<script>
  import { onMount, getContext } from 'svelte';
  import L from 'leaflet';

  export let attribution = '© OpenStreetMap contributors';
  export let url = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  const { getMap, isReady } = getContext('leaflet-map');
  let tileLayer;

  onMount(() => {
    // Aguardar o mapa estar pronto
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          tileLayer = L.tileLayer(url, { attribution }).addTo(map);
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      tileLayer?.remove();
    };
  });
</script>
