<script>
  // src/features/gestor/components/OsmPoisMap.svelte
  //
  // Mapa dos equipamentos públicos (OSM) ao redor da escola: marcador da
  // escola, o buffer (raio) e um ponto no centroide de cada feição, colorido
  // por categoria (tag OSM). A visibilidade por categoria é controlada pelo
  // pai via `hidden` (a legenda é o resumo do painel).
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import L from "leaflet";
  import { categoryColor, categoryLabel } from "../constants/osm.js";

  let {
    escola = null,
    features = [],
    raio = null,
    hidden = {},
    height = "340px",
    class: className = "",
  } = $props();

  let mapRef = $state(null);
  // Camadas por categoria. É $state para o efeito de visibilidade reagir a cada
  // novo desenho; o efeito de desenho ESCREVE (nunca lê) esta variável — sem
  // isso, ler+escrever no mesmo efeito causaria effect_update_depth_exceeded.
  let layersByCategory = $state({});

  const SCHOOL_SVG =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="30" height="30">' +
    '<path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7z" ' +
    'fill="#1d4ed8" stroke="#ffffff" stroke-width="1.5"/>' +
    '<circle cx="12" cy="9" r="2.6" fill="#ffffff"/></svg>';

  function schoolIcon() {
    return L.divIcon({
      className: "osm-school-marker",
      html: SCHOOL_SVG,
      iconSize: [30, 30],
      iconAnchor: [15, 30],
      popupAnchor: [0, -30],
    });
  }

  function popupHtml(feature) {
    const nome = feature.properties?.nome;
    const cat = categoryLabel(feature.properties?.category);
    const dist = feature.properties?.distance_m;
    const distTxt = dist != null ? `<br/><span style="color:#6b7280">a ${Math.round(dist)} m</span>` : "";
    // com nome: nome em destaque + categoria; sem nome: só a categoria
    const title = nome ? `<b>${nome}</b><br/>${cat}` : `<b>${cat}</b>`;
    return `${title}${distTxt}`;
  }

  function removeDrawnLayers() {
    if (!mapRef) return;
    mapRef.eachLayer((layer) => {
      if (layer instanceof L.CircleMarker || layer instanceof L.Circle || layer instanceof L.Marker) {
        layer.remove();
      }
    });
  }

  function draw() {
    if (!mapRef) return;
    removeDrawnLayers();

    const next = {};
    const points = [];
    const lat = escola?.latitude;
    const lng = escola?.longitude;

    if (lat != null && lng != null) {
      const marker = L.marker([lat, lng], { icon: schoolIcon(), zIndexOffset: 1000 }).addTo(mapRef);
      marker.bindPopup(`<b>${escola?.nome ?? "Escola"}</b>`);
      points.push([lat, lng]);

      if (raio) {
        L.circle([lat, lng], {
          radius: Number(raio),
          color: "#1d4ed8",
          weight: 1,
          dashArray: "5 5",
          fillColor: "#1d4ed8",
          fillOpacity: 0.05,
        }).addTo(mapRef);
      }
    }

    for (const feature of features ?? []) {
      const coords = feature.geometry?.coordinates;
      if (!Array.isArray(coords) || coords.length < 2) continue;
      const [flng, flat] = coords;
      if (flng == null || flat == null) continue;

      const cat = feature.properties?.category ?? "outros";
      const circle = L.circleMarker([flat, flng], {
        radius: 6,
        color: "#ffffff",
        weight: 1,
        fillColor: categoryColor(cat),
        fillOpacity: 0.9,
      });
      circle.bindPopup(popupHtml(feature));
      circle.addTo(mapRef);

      next[cat] = [...(next[cat] ?? []), circle];
      points.push([flat, flng]);
    }

    // publica as camadas (dispara o efeito de visibilidade)
    layersByCategory = next;

    if (points.length > 0) {
      try {
        mapRef.fitBounds(L.latLngBounds(points), { padding: [30, 30], maxZoom: 16 });
      } catch (e) {
        console.warn("Erro ao ajustar o mapa dos POIs:", e);
      }
    }
  }

  // Redesenha quando chegam dados (mapa pronto, escola, feições ou raio).
  // NÃO lê `hidden` — deve apenas escrever `layersByCategory`.
  $effect(() => {
    if (mapRef && ((features?.length ?? 0) > 0 || escola?.latitude != null)) {
      draw();
    }
  });

  // Aplica o toggle de categorias sempre que as camadas ou `hidden` mudam.
  $effect(() => {
    for (const [cat, layers] of Object.entries(layersByCategory)) {
      const visible = !hidden?.[cat];
      for (const layer of layers) {
        if (visible) mapRef?.addLayer(layer);
        else mapRef?.removeLayer(layer);
      }
    }
  });
</script>

<div class="relative rounded-card overflow-hidden border border-gray-200" style:height>
  <LeafletMap
    center={[escola?.latitude ?? -15.5, escola?.longitude ?? -55.0]}
    zoom={14}
    {height}
    {className}
    onMapReady={(map) => {
      mapRef = map;
    }}
  />
</div>
