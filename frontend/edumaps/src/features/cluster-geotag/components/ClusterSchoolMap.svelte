<script>
  // src/features/cluster-geotag/components/ClusterSchoolMap.svelte
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import { clusterColor, clusterLabel } from "../constants/cluster.js";
  import L from "leaflet";

  let { markers = [], height = "460px", class: className = "" } = $props();

  let mapRef = $state(null);

  // Clusters ocultos (on/off via clique na legenda). Usamos um Set
  // reatribuído a cada toggle para o Svelte reagir de forma simples.
  let hiddenIds = $state(new Set());

  // Contagens e paleta derivadas dos markers (reativos). clusterColor é
  // chamada com o id para manter a cor mesmo quando `markers` muda.
  const countsByCluster = $derived(
    markers.reduce((acc, f) => {
      const id = clusterKey(f.properties?.cluster_id);
      acc[id] = (acc[id] ?? 0) + 1;
      return acc;
    }, {}),
  );

  const clusterIds = $derived(
    [...new Set(markers.map((f) => clusterKey(f.properties?.cluster_id)))].sort(
      (a, b) => a - b,
    ),
  );

  const labelsByCluster = $derived(
    markers.reduce((acc, f) => {
      const id = clusterKey(f.properties?.cluster_id);
      if (acc[id] === undefined) {
        acc[id] = clusterLabel(f.properties?.cluster_label, id);
      }
      return acc;
    }, {}),
  );

  function clusterKey(id) {
    const n = Number(id ?? 0);
    return Number.isFinite(n) ? n : 0;
  }

  function toggleCluster(id) {
    const next = new Set(hiddenIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    hiddenIds = next;
  }

  function clearAll() {
    if (!mapRef) return;
    mapRef.eachLayer((layer) => {
      if (layer instanceof L.CircleMarker) layer.remove();
    });
  }

  function drawMarkers() {
    if (!mapRef) return;
    clearAll();

    const points = [];
    for (const feature of markers) {
      const clusterId = clusterKey(feature.properties?.cluster_id);
      if (hiddenIds.has(clusterId)) continue;

      const [lng, lat] = feature.geometry?.coordinates ?? [null, null];
      if (lng == null || lat == null) continue;

      const name =
        feature.properties?.no_entidade ?? feature.properties?.escola ?? "Escola";
      const label = clusterLabel(feature.properties?.cluster_label, clusterId);
      const circle = L.circleMarker(L.latLng(lat, lng), {
        radius: 7,
        color: "#ffffff",
        weight: 1.5,
        fillColor: clusterColor(clusterId),
        fillOpacity: 0.85,
      });
      circle.bindPopup(`<b>${name}</b><br/>${label}`);
      mapRef.addLayer(circle);
      points.push([lat, lng]);
    }

    if (points.length > 0) {
      try {
        mapRef.fitBounds(L.latLngBounds(points), { padding: [40, 40] });
      } catch (e) {
        console.warn("Erro ao ajustar bounds das escolas:", e);
      }
    }
  }

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

  {#if clusterIds.length > 0}
    <div class="absolute top-3 right-3 z-[1000] bg-white/95 rounded-md shadow-md p-3 text-sm space-y-1.5">
      <p class="font-semibold text-gray-700 text-xs uppercase tracking-wide">Clusters</p>
      {#each clusterIds as id}
        {@const hidden = hiddenIds.has(id)}
        <button
          type="button"
          onclick={() => toggleCluster(id)}
          class="flex items-center gap-2 w-full text-left rounded px-1 py-0.5 hover:bg-gray-100 transition-colors"
          aria-pressed={!hidden}
        >
          <span
            class="w-3 h-3 rounded-full inline-block shrink-0"
            class:opacity-30={hidden}
            style:background-color={clusterColor(id)}
          ></span>
          <span class="text-gray-700 grow" class:line-through={hidden} class:opacity-50={hidden}>
            {labelsByCluster[id] ?? `Cluster ${id}`}
          </span>
          <span class="text-xs text-gray-400">({countsByCluster[id] ?? 0})</span>
        </button>
      {/each}
    </div>
  {/if}
</div>