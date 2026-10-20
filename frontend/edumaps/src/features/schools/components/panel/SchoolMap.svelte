<script>
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import { ICONS } from "../icons/icon-data.js";
  import { ISOCRONA_FAIXAS, isocronaCor, isocronaRotulo } from "../../constants/ivet.js";
  import { cellToBoundary } from "h3-js";
  import L from "leaflet";

  let {
    latitude,
    longitude,
    schoolName = "Escola",
    similarSchools = [],   // array com { latitude, longitude, nome }
    isocrona = null,       // payload de getSchoolIsocrona() ou null
    zoom = 15,
    height = "300px",
    class: className = "",
  } = $props();

  let mapRef = null;
  let markerRef = null;
  let similarGroup = null;
  let isocronaGroup = null;
  let showSimilar = $state(false);
  // Faixas visíveis (15/45): todas ligadas por padrão; o Set é reatribuído a
  // cada toggle (padrão da skill frontend-svelte) para disparar a reatividade.
  let hiddenFaixas = $state(new Set());

  const iconSvg = ICONS.edumaps.svg;

  // ---- Isócrona: cada célula H3 vira um polígono do Leaflet ----
  // O backend entrega só a grade (grid_id + população); a conversão
  // célula→polígono é feita aqui com h3-js (cellToBoundary).
  function drawIsocrona() {
    if (!mapRef) return;
    if (!isocronaGroup) isocronaGroup = L.layerGroup().addTo(mapRef);
    isocronaGroup.clearLayers();

    for (const faixa of isocrona?.tempos ?? []) {
      if (hiddenFaixas.has(faixa.tempo_minutos)) continue;

      const cor = isocronaCor(faixa.tempo_minutos);
      for (const celula of faixa.celulas ?? []) {
        // cellToBoundary devolve [lat, lng] em graus; o Leaflet usa [lat, lng].
        const boundary = cellToBoundary(celula.grid_id);
        const latlngs = boundary.map(([lat, lng]) => [lat, lng]);
        const poly = L.polygon(latlngs, {
          color: cor,
          weight: 1,
          fillColor: cor,
          fillOpacity: 0.18,
        });
        const pop =
          celula.populacao == null
            ? "sem dado de população"
            : `população: ${celula.populacao.toLocaleString("pt-BR")}`;
        poly.bindTooltip(`${isocronaRotulo(faixa.tempo_minutos)}<br>${pop}`);
        isocronaGroup.addLayer(poly);
      }
    }
  }

  function toggleFaixa(tempo) {
    const next = new Set(hiddenFaixas);
    if (next.has(tempo)) next.delete(tempo);
    else next.add(tempo);
    hiddenFaixas = next;
  }

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
    isocronaGroup = L.layerGroup().addTo(map);
    drawIsocrona();
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

  $effect(() => {
    // Isócrona: redesenha quando os dados ou as faixas visíveis mudam
    if (mapRef && isocrona) {
      drawIsocrona();
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
    <div class="map-control" class:stacked={isocrona}>
      <label>
        <input type="checkbox" bind:checked={showSimilar} />
        <span>Mostrar similares</span>
      </label>
    </div>
  {/if}

  {#if isocrona && isocrona.tempos?.length > 0}
    <!-- Legenda clicável: liga/desliga cada faixa da isócrona sem recarregar -->
    <div class="map-legend" aria-label="Legenda da área de influência">
      <span class="legend-title">Área de influência</span>
      {#each ISOCRONA_FAIXAS as faixa (faixa.tempo_minutos)}
        {@const oculta = hiddenFaixas.has(faixa.tempo_minutos)}
        <button
          type="button"
          class="legend-item"
          class:off={oculta}
          aria-pressed={!oculta}
          onclick={() => toggleFaixa(faixa.tempo_minutos)}
        >
          <span class="swatch" style:background-color={faixa.cor}></span>
          <span class="legend-label">{faixa.rotulo}</span>
        </button>
      {/each}
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
  /* Com a legenda da isócrona no canto inferior, o controle sobe para não
     disputar o canto com ela em telas estreitas. */
  .map-control.stacked {
    top: 10px;
  }
  .map-legend {
    position: absolute;
    bottom: 10px;
    right: 10px;
    z-index: 1000;
    background: rgba(255, 255, 255, 0.95);
    padding: 8px 10px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.85rem;
  }
  .legend-title {
    font-weight: 600;
    color: #374151;
    margin-bottom: 2px;
  }
  .legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    background: none;
    border: none;
    padding: 2px 4px;
    cursor: pointer;
    text-align: left;
    border-radius: 4px;
    color: #1f2937;
  }
  .legend-item:hover {
    background: rgba(0, 0, 0, 0.05);
  }
  .legend-item.off {
    opacity: 0.5;
  }
  .legend-item.off .legend-label {
    text-decoration: line-through;
  }
  .swatch {
    display: inline-block;
    width: 14px;
    height: 14px;
    border-radius: 3px;
    border: 1px solid rgba(0, 0, 0, 0.2);
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
