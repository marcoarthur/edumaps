<script>
  // src/features/gestor/components/SimilarMarkers.svelte
  //
  // Camada de marcadores sobre o LeafletMap: escola alvo (azul) + escolas
  // similares (laranja). Sem coordenadas válidas o marcador é ignorado.
  import { onDestroy } from "svelte";
  import L from "leaflet";
  import { useMapContext } from "@/features/map/context.js";
  import { ICONS } from "@/features/schools/components/icons/icon-data.js";

  /** @type {{ target?: object, schools?: Array }} */
  let { target = {}, schools = [] } = $props();

  const { map, ready } = useMapContext();
  const baseSvg = ICONS.edumaps.svg;
  let layer = null;

  function markerIcon(color) {
    const svg = baseSvg
      .replace(/fill="[^"]*"/g, `fill="${color}"`)
      .replace(/stroke="[^"]*"/g, `stroke="${color}"`);
    const html = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 80" width="34" height="34">${svg}</svg>`;
    return L.divIcon({
      className: "custom-marker similar-marker",
      html,
      iconSize: [34, 34],
      iconAnchor: [17, 34],
      popupAnchor: [0, -34],
    });
  }

  function hasCoords(point) {
    return (
      point?.latitude != null &&
      point?.longitude != null &&
      Number.isFinite(+point.latitude) &&
      Number.isFinite(+point.longitude)
    );
  }

  $effect(() => {
    if (!ready || !map) return;
    if (!layer) layer = L.layerGroup().addTo(map);
    layer.clearLayers();

    const points = [];
    if (hasCoords(target)) {
      const m = L.marker([+target.latitude, +target.longitude], { icon: markerIcon("#2563eb") });
      m.bindPopup(`<b>${target.nome || "Escola alvo"}</b>`);
      layer.addLayer(m);
      points.push(m);
    }

    for (const s of schools) {
      if (!hasCoords(s)) continue;
      const m = L.marker([+s.latitude, +s.longitude], { icon: markerIcon("#f97316") });
      m.bindPopup(`<b>${s.nome || "Escola"}</b>`);
      layer.addLayer(m);
      points.push(m);
    }

    if (points.length > 0) {
      map.fitBounds(points.map((m) => m.getLatLng()), { padding: [48, 48] });
    }
  });

  onDestroy(() => {
    layer?.remove();
    layer = null;
  });
</script>