<script>
  import { mount } from 'svelte';
  import { onMount, getContext, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import CityPopup from './CityPopup.svelte';

  export let cityData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  const dispatch = createEventDispatcher();
  
  let geoJsonLayer;
  let mapReady = false;

  $: if (cityData && mapReady) {
    updateLayer(cityData);
  }

  onMount(() => {
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          geoJsonLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      geoJsonLayer?.clearLayers();
      geoJsonLayer?.remove();
    };
  });

  function updateLayer(data) {
    if (!geoJsonLayer || !data) return;

    geoJsonLayer.clearLayers();

    const layer = L.geoJSON(data, {
      style: {
        color: '#3388ff',
        weight: 2,
        fillColor: '#3388ff',
        fillOpacity: 0.2
      },
      onEachFeature: (feature, layer) => {
        const popup = L.popup();
        const popupContainer = document.createElement('div');

        mount(CityPopup, {
          target: popupContainer,
          props: {
            feature: feature.properties,
            onDetails: (fid) => dispatch('details', { fid }),
            onSchools: (city) => dispatch('schools', { city }),
            onOSM: (fid) => dispatch('osm', { fid }),
          }
        });

        popup.setContent(popupContainer);
        layer.bindPopup(popup);
      }
    });

    layer.addTo(geoJsonLayer);

    // Fit bounds to the new data
    const map = getMap();
    if (map && layer.getBounds().isValid()) {
      map.fitBounds(layer.getBounds());
    }
  }

  export function clear() {
    geoJsonLayer?.clearLayers();
  }
</script>
