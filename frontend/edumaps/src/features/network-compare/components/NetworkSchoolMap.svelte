<script>
  // src/features/network-compare/components/NetworkSchoolMap.svelte
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import { NETWORK_ORDER, NETWORK_LABELS, NETWORK_COLORS } from "../constants/indicators.js";
  import L from "leaflet";

  let { markers = [], height = "440px", class: className = "" } = $props();

  let mapRef = $state(null);
  // NÃO é $state — a lista de camadas é desenhada de forma imperativa.
  // Deixá-la reativa faria o $effect abaixo lê-la e escrevê-la no mesmo
  // ciclo (o Svelte rastreia leituras aninhadas), causando loop infinito.
  let layersByRede = {};
  let visible = $state({});

  // Contagens por rede derivam dos markers (reativos), não de layersByRede.
  const countsByRede = $derived(
    markers.reduce((acc, f) => {
      const key = redeKey(f.properties?.dependencia_administrativa);
      acc[key] = (acc[key] ?? 0) + 1;
      return acc;
    }, {}),
  );

  const availableRedes = $derived(
    [...new Set(markers.map((f) => redeKey(f.properties?.dependencia_administrativa)))],
  );

  const orderedRedes = $derived(
    NETWORK_ORDER.filter((key) => availableRedes.includes(key)),
  );

  function redeKey(dependencia) {
    const label = String(dependencia ?? "").toLowerCase();
    const key = ({
      federal: "federal",
      estadual: "estadual",
      municipal: "municipal",
      privada: "privada",
    })[label];
    return key ?? "outra";
  }

  function redeColor(key) {
    return NETWORK_COLORS[key] ?? "#64748b";
  }

  function clearAll() {
    if (!mapRef) return;
    mapRef.eachLayer((layer) => {
      if (layer instanceof L.CircleMarker) layer.remove();
    });
    layersByRede = {};
  }

  function drawMarkers() {
    if (!mapRef) return;
    clearAll();

    const points = [];
    for (const feature of markers) {
      const [lng, lat] = feature.geometry?.coordinates ?? [null, null];
      if (lng == null || lat == null) continue;

      const key = redeKey(feature.properties?.dependencia_administrativa);
      const label = NETWORK_LABELS[key] ?? feature.properties?.dependencia_administrativa ?? "Outra";
      const circle = L.circleMarker(L.latLng(lat, lng), {
        radius: 7,
        color: "#ffffff",
        weight: 1.5,
        fillColor: redeColor(key),
        fillOpacity: 0.85,
      });
      circle.bindPopup(`<b>${feature.properties?.escola ?? "Escola"}</b><br/>${label}`);
      mapRef.addLayer(circle);

      layersByRede[key] = [...(layersByRede[key] ?? []), circle];
      points.push([lat, lng]);
    }

    // Filtrar redes com zero pontos para não criar toggle fantasma
    visible = Object.fromEntries(orderedRedes.map((key) => [key, true]));

    if (points.length > 0) {
      try {
        mapRef.fitBounds(L.latLngBounds(points), { padding: [40, 40] });
      } catch (e) {
        console.warn("Erro ao ajustar bounds das escolas:", e);
      }
    }
  }

  function toggleRede(key) {
    visible[key] = !visible[key];
    const isVisible = visible[key];
    for (const circle of layersByRede[key] ?? []) {
      if (isVisible) mapRef?.addLayer(circle);
      else mapRef?.removeLayer(circle);
    }
  }

  // Reage à chegada de markers (ou remontagem do mapa).
  // drawMarkers lê markers/mapRef (rastreados neste effect) mas só escreve
  // em `layersByRede` (plain) e `visible` ($state) — que este effect NÃO lê.
  $effect(() => {
    if (mapRef && markers.length > 0) {
      drawMarkers();
    }
  });
</script>

<div class="relative rounded-card overflow-hidden border border-gray-200" style:height>
  <LeafletMap
    center={[-15.5, -55.0]}
    zoom={4}
    {height}
    {className}
    onMapReady={(map) => {
      mapRef = map;
    }}
  />

  {#if orderedRedes.length > 0}
    <div class="absolute top-3 right-3 z-[1000] bg-white/95 rounded-md shadow-md p-3 text-sm space-y-1.5">
      <p class="font-semibold text-gray-700 text-xs uppercase tracking-wide">Redes</p>
      {#each orderedRedes as key}
        <label class="flex items-center gap-2 cursor-pointer select-none">
          <input type="checkbox" checked={visible[key]} onchange={() => toggleRede(key)} />
          <span class="w-3 h-3 rounded-full inline-block" style:background-color={redeColor(key)}></span>
          <span class="text-gray-700">{NETWORK_LABELS[key]}</span>
          <span class="text-xs text-gray-400">({countsByRede[key] ?? 0})</span>
        </label>
      {/each}
    </div>
  {/if}
</div>