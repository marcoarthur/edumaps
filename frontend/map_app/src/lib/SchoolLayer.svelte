<script>
  import { onMount, getContext } from 'svelte';
  import L from 'leaflet';
  import SchoolPopup from './SchoolPopup.svelte';
  import { selectedSchool, hoveredSchool } from './js/schoolStore.js';
  import CoverArea from './School/CoverArea.svelte';
  import { activeCoverSchool } from './stores/activeCoverStore.js';

  export let schoolData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  let pointsLayer;
  let mapReady = false;
  let markersMap = new Map(); // codigo_inep → marker

  // Estilos
  const styleDefault  = { radius: 6,  fillColor: '#ff7800', color: '#000', weight: 1, fillOpacity: 0.8 };
  const styleSelected = { radius: 10, fillColor: '#e63946', color: '#fff', weight: 2, fillOpacity: 1   };
  const styleHovered  = { radius: 8,  fillColor: '#ffd166', color: '#333', weight: 1.5, fillOpacity: 1 };

  $: if (schoolData && mapReady) updateLayer(schoolData);

  // Reage a selectedSchool vindo da tabela → destaca no mapa e dá pan
  $: if (mapReady && $selectedSchool) {
    highlightMarker($selectedSchool, styleSelected);
    const map = getMap();
    const coords = $selectedSchool.geometry.coordinates;
    map?.panTo([coords[1], coords[0]], { animate: true });
  }

  // Reage a hoveredSchool vindo da tabela → destaca sem pan
  $: if (mapReady) {
    markersMap.forEach((marker, id) => {
      const isSelected = $selectedSchool?.properties.codigo_inep === id;
      const isHovered  = $hoveredSchool?.properties.codigo_inep  === id;
      marker.setStyle(isSelected ? styleSelected : isHovered ? styleHovered : styleDefault);
      if (isHovered || isSelected) marker.bringToFront();
    });
  }

  onMount(() => {
    const check = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          pointsLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(check);
        }
      }
    }, 50);
    return () => {
      clearInterval(check);
      pointsLayer?.clearLayers();
      pointsLayer?.remove();
    };
  });

  function updateLayer(data) {
    if (!pointsLayer) return;
    pointsLayer.clearLayers();
    markersMap.clear();

    L.geoJSON(data, {
      pointToLayer: (feature, latlng) => {
        const marker = L.circleMarker(latlng, { ...styleDefault });
        const id = feature.properties.codigo_inep;
        markersMap.set(id, marker);

        marker.on('click', () => selectedSchool.set(feature));
        marker.on('mouseover', () => hoveredSchool.set(feature));
        marker.on('mouseout',  () => hoveredSchool.set(null));

        const popup = document.createElement('div');
        new SchoolPopup({ target: popup, props: { school: feature.properties } });
        marker.bindPopup(popup);
        return marker;
      }
    }).addTo(pointsLayer);
  }

  function highlightMarker(feature, style) {
    markersMap.forEach((m, id) => {
      m.setStyle(id === feature.properties.codigo_inep ? style : styleDefault);
    });
  }
</script>

<CoverArea />
