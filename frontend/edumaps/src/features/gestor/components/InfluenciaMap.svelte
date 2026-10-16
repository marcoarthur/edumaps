<script>
  // src/features/gestor/components/InfluenciaMap.svelte
  //
  // Mapa da área de influência materializada (clean.escola_influencia): o
  // marcador da escola e um polígono por raio, vindos do backend como GeoJSON
  // (a geometria real, não um círculo recalculado no cliente). A visibilidade
  // por raio é controlada pelo pai via `hidden` (a legenda é o resumo).
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import { radiusColor, radiusLabel, radiusPurpose, formatAreaKm2 } from "../constants/influencia.js";
  import L from "leaflet";

  let {
    escola = null,
    features = [],
    hidden = {},
    height = "340px",
    class: className = "",
  } = $props();

  let mapRef = $state(null);
  // Camadas por raio. É $state para o efeito de visibilidade reagir a cada novo
  // desenho; o efeito de desenho ESCREVE (nunca lê) esta variável.
  let layersByRadius = $state({});

  const SCHOOL_SVG =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="30" height="30">' +
    '<path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7z" ' +
    'fill="#1d4ed8" stroke="#ffffff" stroke-width="1.5"/>' +
    '<circle cx="12" cy="9" r="2.6" fill="#ffffff"/></svg>';

  function schoolIcon() {
    return L.divIcon({
      className: "influencia-school-marker",
      html: SCHOOL_SVG,
      iconSize: [30, 30],
      iconAnchor: [15, 30],
      popupAnchor: [0, -30],
    });
  }

  function popupHtml(feature) {
    const p = feature.properties ?? {};
    return (
      `<b>${radiusLabel(p.raio_m)}</b><br>` +
      `${radiusPurpose(p.raio_m)}<br>` +
      `Área: ${formatAreaKm2(p.area_km2)}<br>` +
      `<span style="color:#6b7280">${p.versao ?? "influencia-v1"} · ${p.tier ?? "buffer"}</span>`
    );
  }

  function draw() {
    if (!mapRef) return;

    // Limpa o que este componente desenhou (marcador + camadas GeoJSON).
    mapRef.eachLayer((layer) => {
      if (layer instanceof L.GeoJSON || layer instanceof L.Marker) mapRef.removeLayer(layer);
    });

    let bounds = null;
    const extend = (b) => {
      if (!b) return;
      try {
        bounds = bounds ? bounds.extend(b) : b;
      } catch (e) {
        /* bounds vazio — ignora */
      }
    };

    if (escola?.latitude != null && escola?.longitude != null) {
      L.marker([escola.latitude, escola.longitude], { icon: schoolIcon() })
        .bindPopup(`<b>${escola.nome ?? "Escola"}</b>`)
        .addTo(mapRef);
      extend(L.latLngBounds([escola.latitude, escola.longitude], [escola.latitude, escola.longitude]));
    }

    const next = {};
    for (const feature of features ?? []) {
      const raio = Number(feature.properties?.raio_m ?? 0);
      const layer = L.geoJSON(feature, {
        style: {
          color: radiusColor(raio),
          weight: 2,
          fillColor: radiusColor(raio),
          fillOpacity: 0.08,
        },
      });
      layer.bindPopup(popupHtml(feature));
      layer.addTo(mapRef);
      next[raio] = layer;
      extend(layer.getBounds());
    }

    // Publica as camadas (dispara o efeito de visibilidade).
    layersByRadius = next;

    if (bounds?.isValid?.()) {
      mapRef.fitBounds(bounds, { padding: [30, 30], maxZoom: 16 });
    }
  }

  // Redesenha quando chegam dados (mapa pronto, escola ou feições).
  // NÃO lê `hidden` — deve apenas escrever `layersByRadius`.
  $effect(() => {
    if (mapRef && ((features?.length ?? 0) > 0 || escola?.latitude != null)) {
      draw();
    }
  });

  // Aplica o toggle de raios sempre que as camadas ou `hidden` mudam.
  $effect(() => {
    for (const [raio, layer] of Object.entries(layersByRadius)) {
      const visible = !hidden?.[raio];
      if (visible) mapRef?.addLayer(layer);
      else mapRef?.removeLayer(layer);
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
