<script>
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import { ICONS } from "../icons/icon-data.js";
  import L from "leaflet";

  let {
    latitude,
    longitude,
    schoolName = "Escola",
    similarSchools = [],   // array com { latitude, longitude, nome }
    zoom = 15,
    height = "300px",
    class: className = "",
  } = $props();

  let mapRef = null;
  let markerRef = null;
  let similarGroup = null;
  let showSimilar = $state(false);

  const iconSvg = ICONS.edumaps.svg;

  // ---- Ícone da escola alvo (original) ----
  function createMainMarker(map) {
    const html = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 80" width="40" height="40">${iconSvg}</svg>`;
    const icon = L.divIcon({
      className: "custom-marker",
      html: html,
      iconSize: [40, 40],
      iconAnchor: [20, 40],
      popupAnchor: [0, -40],
    });
    markerRef = L.marker([latitude, longitude], { icon }).addTo(map);
    markerRef.bindPopup(`<b>${schoolName}</b>`);
  }

  // ---- Ícone para similares (apenas troca a cor) ----
  function createSimilarIcon() {
    const modifiedSvg = iconSvg
      .replace(/fill="[^"]*"/g, 'fill="#f97316"')
      .replace(/stroke="[^"]*"/g, 'stroke="#f97316"');
    const html = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 80" width="40" height="40">${modifiedSvg}</svg>`;
    return L.divIcon({
      className: "custom-marker similar-marker",
      html: html,
      iconSize: [40, 40],
      iconAnchor: [20, 40],
      popupAnchor: [0, -40],
    });
  }

  // ---- Atualiza os marcadores similares e o zoom ----
  function updateSimilarMarkers() {
    if (!mapRef) return;

    // Cria o grupo se não existir
    if (!similarGroup) {
      similarGroup = L.layerGroup().addTo(mapRef);
    }

    // Limpa o grupo
    similarGroup.clearLayers();

    if (showSimilar && similarSchools.length > 0) {
      // Adiciona cada escola similar
      similarSchools.forEach((school) => {
        const lat = parseFloat(school.latitude);
        const lng = parseFloat(school.longitude);
        if (!isNaN(lat) && !isNaN(lng)) {
          const marker = L.marker([lat, lng], { icon: createSimilarIcon() });
          marker.bindPopup(`<b>${school.nome || "Escola"}</b>`);
          similarGroup.addLayer(marker);
        }
      });

      // ---- Zoom para mostrar todos (inclusive a escola alvo) ----
      // Pega as coordenadas de todos os marcadores do grupo + o marcador principal
      const allMarkers = [markerRef, ...similarGroup.getLayers()];
      const latLngs = allMarkers
        .filter(m => m && m.getLatLng)
        .map(m => m.getLatLng());

      if (latLngs.length > 0) {
        try {
          const bounds = L.latLngBounds(latLngs);
          mapRef.fitBounds(bounds, { padding: [50, 50] });
        } catch (e) {
          console.warn("Erro ao ajustar bounds:", e);
        }
      }
    } else {
      // Remove os marcadores e volta para a visualização da escola alvo
      mapRef.setView([latitude, longitude], zoom);
    }
  }

  // ---- Evento: mapa pronto ----
  function handleMapReady(map) {
    mapRef = map;
    createMainMarker(map);
    map.setView([latitude, longitude], zoom);
    similarGroup = L.layerGroup().addTo(map);
  }

  // ---- Reatividade ----
  $effect(() => {
    // Quando a escola alvo muda, recria o marcador principal
    if (mapRef && latitude != null && longitude != null) {
      if (markerRef) {
        markerRef.remove();
        markerRef = null;
      }
      createMainMarker(mapRef);
      // Se o toggle estiver ativo, atualiza os similares; senão, centraliza
      if (showSimilar) {
        updateSimilarMarkers();
      } else {
        mapRef.setView([latitude, longitude], zoom);
      }
    }
  });

  $effect(() => {
    // Quando o toggle ou a lista de similares mudar
    if (mapRef) {
      updateSimilarMarkers();
    }
  });
</script>

<!-- ===== TEMPLATE ===== -->
<div class="map-wrapper" style="position: relative; height: {height}; width: 100%;">
  <LeafletMap
    center={[latitude || -15.5, longitude || -55.0]}
    {zoom}
    {height}
    class={className}
    onMapReady={handleMapReady}
  />

  {#if similarSchools.length > 0}
    <div class="map-control">
      <label>
        <input type="checkbox" bind:checked={showSimilar} />
        <span>Mostrar similares</span>
      </label>
    </div>
  {/if}
</div>

<style>
  .map-wrapper {
    position: relative;
    border-radius: 8px;
    overflow: hidden;
  }
  .map-control {
    position: absolute;
    top: 10px;
    right: 10px;
    z-index: 1000;
    background: white;
    padding: 6px 12px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    user-select: none;
  }
  .map-control label {
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
  }
  .map-control input[type="checkbox"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
  }
</style>
