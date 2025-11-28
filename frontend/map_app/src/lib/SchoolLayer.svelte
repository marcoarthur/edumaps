<script>
  import { onMount, getContext } from 'svelte';
  import L from 'leaflet';
  import SchoolPopup from './SchoolPopup.svelte';

  export let schoolData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  let pointsLayer;
  let mapReady = false;

  $: if (schoolData && mapReady) {
    updateLayer(schoolData);
  }

  onMount(() => {
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          pointsLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      pointsLayer?.clearLayers();
      pointsLayer?.remove();
    };
  });

  function updateLayer(data) {
    if (!pointsLayer || !data) return;

    pointsLayer.clearLayers();

    L.geoJSON(data, {
      pointToLayer: (_, latlng) =>
        L.circleMarker(latlng, {
          radius: 6,
          fillColor: "#ff7800",
          color: "#000",
          weight: 1,
          fillOpacity: 0.8
        }),
      onEachFeature: (feature, layer) => {
        const popupContainer = document.createElement('div');
        new SchoolPopup({
          target: popupContainer,
          props: { school: feature.properties }
        });
        layer.bindPopup(popupContainer);
      }
    }).addTo(pointsLayer);
  }

  export function clear() {
    pointsLayer?.clearLayers();
  }
</script>
